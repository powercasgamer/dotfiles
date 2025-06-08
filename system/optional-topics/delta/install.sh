#!/usr/bin/env bash
# Delta Installer - https://github.com/dandavison/delta
set -euo pipefail

DOTFILES_ROOT="/usr/local/share/dotfiles-system"
source "${DOTFILES_ROOT}/system/scripts/scripts.sh" 2>/dev/null || {
  echo "Error: Failed to load script utilities" >&2
  exit 1
}

# Configuration
DELTA_VERSION="0.16.5"  # Set to "latest" to get newest version
INSTALL_METHOD=""       # auto|deb|rpm|static|cargo|brew (auto detects if empty)
PREFIX="/usr/local"     # Installation prefix for static/cargo methods

fatal() { error "$1"; exit 1; }

# Detect platform
detect_platform() {
    case "$(uname -s)" in
        Linux*)  platform="linux" ;;
        Darwin*) platform="macos" ;;
        *)       platform="other" ;;
    esac

    if [ "$platform" = "linux" ]; then
        if [ -f /etc/debian_version ]; then
            distro="debian"
        elif [ -f /etc/redhat-release ]; then
            distro="redhat"
        elif [ -f /etc/arch-release ]; then
            distro="arch"
        elif [ -f /etc/alpine-release ]; then
            distro="alpine"
        else
            distro="other"
        fi
    else
        distro="other"
    fi
}

# Check dependencies
check_deps() {
    local missing=()
    for dep in "$@"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        fatal "Missing dependencies: ${missing[*]}"
    fi
}

# Get latest GitHub release tag
get_latest_version() {
    curl -s https://api.github.com/repos/dandavison/delta/releases/latest | \
    grep '"tag_name":' | \
    sed -E 's/.*"([^"]+)".*/\1/'
}

# Install via cargo
install_cargo() {
    info "Installing via cargo (Rust package manager)"
    check_deps "cargo"
    if [ "$DELTA_VERSION" = "latest" ]; then
        cargo install git-delta
    else
        cargo install git-delta --version "$DELTA_VERSION"
    fi
    info "Cargo installation complete"
}

# Install from static binary
install_static() {
    local version="$1"
    info "Installing static binary version $version"

    local url="https://github.com/dandavison/delta/releases/download/${version}/delta-${version}-x86_64-unknown-linux-gnu.tar.gz"

    if [ ! -d "$PREFIX/bin" ]; then
        mkdir -p "$PREFIX/bin"
    fi

    temp_dir=$(mktemp -d)
    curl -L "$url" | tar xz -C "$temp_dir" --strip-components=1
    mv "$temp_dir/delta" "$PREFIX/bin/"
    rm -rf "$temp_dir"

    info "Static binary installed to $PREFIX/bin/delta"
}

# Install via package manager
install_package() {
    case "$1" in
        deb)
            info "Installing .deb package"
            check_deps "curl" "dpkg"
            local deb_url="https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_amd64.deb"
            curl -LO "$deb_url"
            sudo dpkg -i "git-delta_${DELTA_VERSION}_amd64.deb"
            rm "git-delta_${DELTA_VERSION}_amd64.deb"
            ;;
        rpm)
            info "Installing .rpm package"
            check_deps "curl" "rpm"
            local rpm_url="https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta-${DELTA_VERSION}-1.x86_64.rpm"
            curl -LO "$rpm_url"
            sudo rpm -i "git-delta-${DELTA_VERSION}-1.x86_64.rpm"
            rm "git-delta-${DELTA_VERSION}-1.x86_64.rpm"
            ;;
        brew)
            info "Installing via Homebrew"
            check_deps "brew"
            brew install git-delta
            ;;
        *)
            fatal "Unknown package type: $1"
            ;;
    esac
}

# Configure git to use delta
configure_git() {
    if ! git config --global --get core.pager &> /dev/null; then
        info "Configuring git to use delta"
        git config --global core.pager "delta"
        git config --global interactive.diffFilter "delta --color-only"
        git config --global add.interactive.useBuiltin false
    else
        warn "Git pager already configured. Manual setup may be needed:"
        warn "  git config --global core.pager delta"
    fi

    info "Consider adding these to your ~/.gitconfig:"
    cat <<EOF

[delta]
    features = decorations
    side-by-side = true
    line-numbers = true

[interactive]
    diffFilter = delta --color-only
EOF
}

# Main installation function
install_delta() {
    detect_platform

    # Set version if latest
    if [ "$DELTA_VERSION" = "latest" ]; then
        DELTA_VERSION=$(get_latest_version)
        info "Latest version is $DELTA_VERSION"
    fi

    # Determine install method if not specified
    if [ -z "$INSTALL_METHOD" ]; then
        if command -v brew &> /dev/null; then
            INSTALL_METHOD="brew"
        elif command -v cargo &> /dev/null; then
            INSTALL_METHOD="cargo"
        elif [ "$distro" = "debian" ]; then
            INSTALL_METHOD="deb"
        elif [ "$distro" = "redhat" ]; then
            INSTALL_METHOD="rpm"
        else
            INSTALL_METHOD="static"
        fi
        info "Auto-selected installation method: $INSTALL_METHOD"
    fi

    # Execute installation
    case "$INSTALL_METHOD" in
        cargo) install_cargo ;;
        deb|rpm|brew) install_package "$INSTALL_METHOD" ;;
        static) install_static "$DELTA_VERSION" ;;
        *) fatal "Unknown installation method: $INSTALL_METHOD" ;;
    esac

    # Verify installation
    if command -v delta &> /dev/null; then
        info "Installation successful: $(delta --version)"
        configure_git
    else
        fatal "Installation failed - delta not found in PATH"
    fi
}

# Run main function
install_delta