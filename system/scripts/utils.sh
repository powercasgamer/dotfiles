#!/usr/bin/env bash

DOTFILES_ROOT="/usr/local/share/dotfiles-system"
SCRIPTS_ROOT="${DOTFILES_ROOT}/system/scripts"

# Source logging utilities if not already sourced
if ! command -v info &>/dev/null; then
  source "${SCRIPTS_ROOT}/logging.sh"
fi

# Detect platform and distribution
detect_platform() {
    OS="$(uname -s)"
    case "${OS}" in
        Linux*)  platform="linux" ;;
        Darwin*) platform="macos" ;;
        CYGWIN*) platform="windows" ;;
        MINGW*)  platform="windows" ;;
        *)       platform="other" ;;
    esac

    # Detect Linux distribution
    if [ "${platform}" = "linux" ]; then
        if [ -f /etc/os-release ]; then
            # Freedesktop.org and systemd
            . /etc/os-release
            distro="${ID}"
            distro_version="${VERSION_ID}"
        elif type lsb_release >/dev/null 2>&1; then
            # linuxbase.org
            distro="$(lsb_release -si)"
            distro_version="$(lsb_release -sr)"
        elif [ -f /etc/lsb-release ]; then
            # For some versions of Debian/Ubuntu without lsb_release command
            . /etc/lsb-release
            distro="${DISTRIB_ID}"
            distro_version="${DISTRIB_RELEASE}"
        elif [ -f /etc/debian_version ]; then
            # Older Debian/Ubuntu/etc.
            distro="debian"
            distro_version="$(cat /etc/debian_version)"
        elif [ -f /etc/redhat-release ]; then
            # Older Red Hat, CentOS, etc.
            distro="redhat"
            distro_version="$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release)"
        elif [ -f /etc/arch-release ]; then
            # Arch Linux
            distro="arch"
            distro_version="" # Arch doesn't provide version numbers
        elif [ -f /etc/alpine-release ]; then
            # Alpine Linux
            distro="alpine"
            distro_version="$(cat /etc/alpine-release)"
        else
            distro="other"
            distro_version=""
        fi
    else
        distro="other"
        distro_version=""
    fi

    # Export platform info
    export PLATFORM="${platform}"
    export DISTRO="${distro}"
    export DISTRO_VERSION="${distro_version}"
    export OS="${OS}"
}

# Check if script is being run as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "This script must be run as root"
    fi
}

# Check dependencies with improved output
check_dependencies() {
    local missing=()
    for dep in "$@"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing dependencies:" "display_install_hint ${missing[*]}"
    fi
}

# Display installation hint for missing packages
display_install_hint() {
    warning "Missing dependencies:"
    for dep in "$@"; do
        warning " - ${dep}"
    done

    if [ "${PLATFORM}" = "linux" ]; then
        case "${DISTRO}" in
            debian|ubuntu)
                info "Try installing with: sudo apt install $*"
                ;;
            centos|redhat|fedora)
                info "Try installing with: sudo yum install $*"
                ;;
            arch|manjaro)
                info "Try installing with: sudo pacman -S $*"
                ;;
            alpine)
                info "Try installing with: sudo apk add $*"
                ;;
            *)
                info "Please install the missing dependencies manually"
                ;;
        esac
    elif [ "${PLATFORM}" = "macos" ]; then
        info "Try installing with: brew install $*"
    else
        info "Please install the missing dependencies manually"
    fi
}

# Check if a file exists and is readable
check_file() {
    if [ ! -f "$1" ] || [ ! -r "$1" ]; then
        error "File not found or not readable: $1"
    fi
}

# Check if a directory exists and is accessible
check_dir() {
    if [ ! -d "$1" ] || [ ! -x "$1" ]; then
        error "Directory not found or not accessible: $1"
    fi
}

# Safe version of rm -rf that prevents accidental deletion of /
safe_rm_rf() {
    for path in "$@"; do
        # Check if path is not empty and not root
        if [ -z "${path}" ] || [ "${path}" = "/" ]; then
            warning "Refusing to remove: ${path}"
            continue
        fi

        if [ -e "${path}" ]; then
            info "Removing: ${path}"
            rm -rf "${path}"
        fi
    done
}

# Initialize platform detection
detect_platform