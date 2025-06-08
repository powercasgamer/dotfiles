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

setup_backports() {
    step "Configuring backports repository"

    . /etc/os-release
    local backports_repo="${VERSION_CODENAME}-backports"
    local backports_file="/etc/apt/sources.list.d/backports.list"

    # Check if backports are already configured
    if grep -rq "${backports_repo}" /etc/apt/sources.list*; then
        warn "Backports repository already exists - skipping addition"
        return 0
    fi

    # Add backports with proper format for Ubuntu/Debian
    if [[ "$ID" == "ubuntu" ]]; then
        echo "deb http://archive.ubuntu.com/ubuntu ${backports_repo} main restricted universe multiverse" > "$backports_file"
    else  # Debian
        echo "deb http://deb.debian.org/debian ${backports_repo} main contrib non-free" > "$backports_file"
    fi

    # Add the backports priority configuration
    echo "Package: *
Pin: release a=${backports_repo}
Pin-Priority: 100" > /etc/apt/preferences.d/backports

    apt-get update || error "Failed to update package lists after adding backports"
}

# Installation function
install_cockpit() {
    step "Installing Cockpit from backports"

    . /etc/os-release
    local backports_repo="${VERSION_CODENAME}-backports"

    apt-get update || error "Failed to update package lists"

    # Install cockpit from backports
    if ! apt-get install -y -t "${backports_repo}" cockpit; then
        warn "Failed to install from backports, trying main repository"
        apt-get install -y cockpit || error "Failed to install Cockpit"
    fi

    # Install remaining packages
    step "Installing additional components"
    apt-get install -y --no-install-recommends \
        "${COCKPIT_PACKAGES[@]}" || {
        warn "Some packages failed to install"
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
    step "Configuring Cockpit services"

    systemctl enable --now cockpit.socket || error "Failed to enable Cockpit service"
    systemctl restart cockpit || warn "Failed to restart Cockpit (service may not be running)"

    # Verify service status
    if ! systemctl is-active --quiet cockpit.socket; then
        warn "Cockpit service not running. Attempting to start..."
        systemctl start cockpit.socket || error "Failed to start Cockpit"
    fi
}


# Main installation flow
main() {
    info "Starting Cockpit installation on $(lsb_release -ds)"

    setup_backports
    install_cockpit
    configure_firewall
    enable_services

    # Get server IP (prioritize non-local addresses)
    IP_ADDRESS=$(ip route get 1 | awk '{print $7}' | head -1)
    [ -z "$IP_ADDRESS" ] && IP_ADDRESS=$(hostname -I | awk '{print $1}')

    # Display summary
    success "\nCockpit installation complete!\n"
    echo -e "${BOLD}Access Information:${NC}"
    echo -e "  ${BLUE}URL:${NC} ${GREEN}https://${IP_ADDRESS}:9090${NC}"
    echo -e "  ${BLUE}Login:${NC} Your system credentials\n"

    echo -e "${BOLD}Installed Components:${NC}"
    printf "  - %s\n" "${COCKPIT_PACKAGES[@]}"
    printf "  - %s\n" "${RECOMMENDED_PACKAGES[@]}"

    echo -e "\n${BOLD}Next Steps:${NC}"
    echo "  1. Open the Cockpit URL in your web browser"
    echo "  2. Review firewall settings if needed"
    echo "  3. Check system updates in Cockpit's 'Software Updates' section"

    echo -e "\n${GREEN}✔ Server management console ready${NC}"
}

# Execute main function
main