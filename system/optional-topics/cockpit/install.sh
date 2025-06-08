#!/bin/bash

# Cockpit Installation Script for Ubuntu/Debian

DOTFILES_ROOT="/usr/local/share/dotfiles-system"
source "${DOTFILES_ROOT}/system/scripts/scripts.sh" 2>/dev/null || {
    echo -e "\033[1;31m[✗] Error: Failed to load script utilities\033[0m" >&2
    exit 1
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root. Use sudo or login as root."
fi

# Verify Ubuntu/Debian
if ! grep -qiE 'ubuntu|debian' /etc/os-release; then
    error "This script only supports Ubuntu/Debian systems"
fi

# Core packages to install
COCKPIT_PACKAGES=(
    cockpit
    cockpit-networkmanager
    cockpit-storaged
    cockpit-packagekit
)

# Installation function
install_cockpit() {
    step "Updating package lists"
    apt-get update || error "Failed to update package lists"

    step "Installing Cockpit and components"
    apt-get install -y --no-install-recommends "${COCKPIT_PACKAGES[@]}" || {
        error "Failed to install Cockpit packages"
    }

    success "Cockpit installed successfully"
}

# Firewall configuration
configure_firewall() {
    if ! command -v ufw >/dev/null; then
        warn "UFW not installed - skipping firewall configuration"
        return
    fi

    if confirm "Configure UFW to allow Cockpit access (port 9090)?"; then
        step "Configuring UFW firewall"
        ufw allow 9090/tcp || warn "Failed to add UFW rule"
        ufw reload || warn "Failed to reload UFW"
    fi
}

# Service management
enable_services() {
    step "Enabling Cockpit service"
    systemctl enable --now cockpit.socket || error "Failed to enable Cockpit service"
}

# Main installation flow
{
    install_cockpit
    configure_firewall
    enable_services

    IP_ADDRESS=$(hostname -I | awk '{print $1}')

    success "\nCockpit installation complete!"
    echo -e "\n${BLUE}Access Information:${NC}"
    echo -e "  URL: ${BOLD}https://${IP_ADDRESS}:9090${NC}"
    echo -e "  Login: Your system credentials\n"

    echo -e "${BLUE}Installed Components:${NC}"
    printf "  - %s\n" "${COCKPIT_PACKAGES[@]}"

    success "You can now manage your server through the web interface"
}