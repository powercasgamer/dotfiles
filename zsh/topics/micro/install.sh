#!/usr/bin/env bash
# Micro Editor Install Script
set -euo pipefail

# Constants
INSTALL_DIR="/usr/local/bin"
MICRO_URL="https://getmic.ro"
MICRO_BIN="micro"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run as root${NC}" >&2
    exit 1
fi

# Verify internet connectivity
check_network() {
    if ! curl -Is https://getmic.ro | head -n 1 | grep -q 200; then
        echo -e "${RED}Error: Failed to connect to download server${NC}" >&2
        return 1
    fi
}

# Check for existing installation
check_existing() {
    if command -v "$MICRO_BIN" >/dev/null 2>&1; then
        local version
        version=$("$MICRO_BIN" --version | cut -d' ' -f2)
        echo -e "${YELLOW}Micro $version is already installed at $(command -v "$MICRO_BIN")${NC}"
        return 0
    fi
    return 1
}

# Main installation
install_micro() {
    echo -e "${GREEN}Installing micro editor...${NC}"

    # Download and install
    if ! curl -fsSL "$MICRO_URL" | bash -s -- --bin "$INSTALL_DIR/$MICRO_BIN"; then
        echo -e "${RED}Error: Download or installation failed${NC}" >&2
        return 1
    fi

    # Verify installation
    # if [[ ! -x "$INSTALL_DIR/$MICRO_BIN" ]]; then
    #     echo -e "${RED}Error: Installation verification failed${NC}" >&2
    #     return 1
    # fi

    # Set permissions
    chmod 755 "$INSTALL_DIR/$MICRO_BIN"
    chown root:root "$INSTALL_DIR/$MICRO_BIN"

    # Verify version
    local installed_version
    installed_version=$("$INSTALL_DIR/$MICRO_BIN" --version | head -n1)
    echo -e "${GREEN}Successfully installed ${installed_version}${NC}"
}

# Cleanup on failure
cleanup() {
    rm -f "$INSTALL_DIR/$MICRO_BIN" 2>/dev/null
    echo -e "${RED}Installation was rolled back${NC}"
}

# Main execution
main() {
    trap cleanup ERR

    if check_existing; then
        read -rp "Reinstall anyway? [y/N] " answer
        [[ "$answer" != [Yy]* ]] && exit 0
    fi

    check_network || exit 1

    if install_micro; then
        echo -e "\n${GREEN}Micro editor is ready at $INSTALL_DIR/$MICRO_BIN${NC}"
        echo -e "Try it with: ${YELLOW}micro --version${NC}"
    else
        exit 1
    fi
}

main
