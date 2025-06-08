#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="/usr/local/share/dotfiles-system"
source "${DOTFILES_ROOT}/system/scripts/scripts.sh" 2>/dev/null || {
  echo "Error: Failed to load script utilities" >&2
  exit 1
}

# Constants
LOG_FILE="docker-install-$(date +%Y%m%d-%H%M%S).log"

# Initialize logging
log_init "$LOG_FILE"
log_header "Docker Installation Script (Latest Versions)"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

# Function to get latest stable Docker version
get_latest_docker_version() {
    curl -fsSL https://download.docker.com/linux/static/stable/x86_64/ | \
    grep -oP 'docker-\K\d+\.\d+\.\d+(?=\.tgz)' | \
    sort -V | \
    tail -1
}

# Function to get latest Docker Compose version
get_latest_compose_version() {
    curl -fsSL https://api.github.com/repos/docker/compose/releases/latest | \
    grep -oP '"tag_name": "\Kv\d+\.\d+\.\d+'
}

# Detect OS and distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
else
    OS=$(uname -s)
    VER=$(uname -r)
fi

log_info "Detected OS: $OS $VER"

adjust_repo_for_ubuntu_noble() {
    if [[ "$OS" == "Ubuntu" && "$VER" == "24.04" ]]; then
        if ! curl -s --head https://download.docker.com/linux/ubuntu/dists/noble/ >/dev/null; then
            warning "Ubuntu 24.04 (Noble) not yet in Docker repo - falling back to Jammy (22.04)"
            sed -i 's/noble/jammy/g' /etc/apt/sources.list.d/docker.list
        fi
    fi
}

# Installation functions
install_docker_debian() {
    log_info "Installing Docker on Debian-based system"

    # Install dependencies
    apt-get update && apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release || {
        log_error "Failed to install dependencies"
        return 1
    }

    # Add Docker GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || {
        log_error "Failed to add Docker GPG key"
        return 1
    }

    # Set up repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list >/dev/null || {
        log_error "Failed to set up Docker repository"
        return 1
    }

    # Adjust for Ubuntu Noble if needed
    adjust_repo_for_ubuntu_noble

    # Install Docker
    apt-get update && apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin || {
        log_error "Failed to install Docker packages"
        return 1
    }

    return 0
}

install_docker_rhel() {
    log_info "Installing Docker on RHEL-based system"

    # Remove old versions
    log_step "Removing old Docker versions..."
    yum remove -y docker \
        docker-client \
        docker-client-latest \
        docker-common \
        docker-latest \
        docker-latest-logrotate \
        docker-logrotate \
        docker-engine || {
        log_error "Failed to remove old Docker packages"
        return 1
    }

    # Install dependencies
    log_step "Installing dependencies..."
    yum install -y yum-utils || {
        log_error "Failed to install dependencies"
        return 1
    }

    # Set up repository (always use stable channel)
    log_step "Setting up Docker repository..."
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || {
        log_error "Failed to set up Docker repository"
        return 1
    }

    # Install Docker (will get latest from repo)
    log_step "Installing Docker Engine..."
    yum install -y docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin || {
        log_error "Failed to install Docker packages"
        return 1
    }

    return 0
}

install_latest_docker_compose() {
    log_info "Installing latest Docker Compose standalone"

    # Get latest version
    COMPOSE_VERSION=$(get_latest_compose_version)
    if [ -z "$COMPOSE_VERSION" ]; then
        log_error "Failed to get latest Docker Compose version"
        return 1
    fi

    log_info "Latest Docker Compose version: $COMPOSE_VERSION"

    # Remove old version if exists
    if [ -f /usr/local/bin/docker-compose ]; then
        log_step "Removing old Docker Compose version..."
        rm -f /usr/local/bin/docker-compose || {
            log_warning "Failed to remove old Docker Compose"
        }
    fi

    # Download binary
    log_step "Downloading Docker Compose $COMPOSE_VERSION..."
    curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose || {
        log_error "Failed to download Docker Compose"
        return 1
    }

    # Make executable
    chmod +x /usr/local/bin/docker-compose || {
        log_error "Failed to make Docker Compose executable"
        return 1
    }

    # Create symlink
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose || {
        log_warning "Failed to create symlink for Docker Compose"
    }

    # Verify installation
    docker-compose --version || {
        log_error "Docker Compose installation verification failed"
        return 1
    }

    return 0
}

post_install() {
    log_info "Running post-installation steps"

    # Start and enable Docker
    log_step "Starting Docker service..."
    systemctl start docker || {
        log_error "Failed to start Docker service"
        return 1
    }

    log_step "Enabling Docker service..."
    systemctl enable docker || {
        log_error "Failed to enable Docker service"
        return 1
    }

    # Test Docker installation
    log_step "Testing Docker installation..."
    docker run --rm hello-world && {
        log_success "Docker installed successfully"
    } || {
        log_error "Docker test failed"
        return 1
    }

# Add current user to docker group
DOCKER_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "${USER}")}"
if [ -n "$DOCKER_USER" ] && [ "$DOCKER_USER" != "root" ]; then
    step "Adding $DOCKER_USER to docker group..."
    if id "$DOCKER_USER" >/dev/null 2>&1; then
        usermod -aG docker "$DOCKER_USER" || {
            warning "Failed to add user to docker group"
        }
        info "You'll need to log out and back in for group changes to take effect"
    else
        warningrning "User $DOCKER_USER does not exist - cannot add to docker group"
    fi
fi

    # Show versions
    step "Installed versions:"
    docker --version
    docker compose version
    if [ -f /usr/local/bin/docker-compose ]; then
        docker-compose --version
    fi

    return 0
}

# Main installation routine
main() {
    case $OS in
        *Debian*|*Ubuntu*|*Pop!_OS*|*Linux\ Mint*)
            install_docker_debian || exit 1
            ;;
        *CentOS*|*Red\ Hat*|*Fedora*|*Rocky*|*AlmaLinux*)
            install_docker_rhel || exit 1
            ;;
        *)
            log_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac

    # Install standalone Docker Compose (in addition to the plugin)
    install_latest_docker_compose || {
        log_warning "Standalone Docker Compose installation failed, but Docker Compose plugin may still work"
    }

    post_install || exit 1

    log_success "Installation completed successfully"
    log_info "Installation log saved to $LOG_FILE"
}

main