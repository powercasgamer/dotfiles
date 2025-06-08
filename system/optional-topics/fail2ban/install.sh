#!/bin/bash

DOTFILES_ROOT="/usr/local/share/dotfiles-system"
source "${DOTFILES_ROOT}/system/scripts/scripts.sh" 2>/dev/null || {
  echo "Error: Failed to load script utilities" >&2
  exit 1
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root or with sudo"
    exit 1
fi

# Get script directory and jail files path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
JAIL_FILES_DIR="${SCRIPT_DIR}/jail_files"
JAIL_DIR="/etc/fail2ban/jail.d"

# Configuration parameters
MAX_RETRY=3
BAN_TIME="1h"
FIND_TIME="10m"
IGNORE_IP="127.0.0.1\/8 ::1"

# Verify jail files directory exists
if [ ! -d "$JAIL_FILES_DIR" ]; then
    warn "❌ Error: jail_files directory not found at $JAIL_FILES_DIR"
    exit 1
fi

# Create jail.d directory if it doesn't exist
mkdir -p "$JAIL_DIR" || {
    warn "❌ Failed to create $JAIL_DIR"
    exit 1
}

# Install Fail2Ban if not installed
if ! command -v fail2ban-server &> /dev/null; then
    step "🔧 Installing Fail2Ban..."
    if command -v apt &> /dev/null; then
        apt update && apt install -y fail2ban
    elif command -v yum &> /dev/null; then
        yum install -y epel-release && yum install -y fail2ban
    elif command -v dnf &> /dev/null; then
        dnf install -y fail2ban
    else
        warn "❌ Unsupported package manager. Install Fail2Ban manually first."
        exit 1
    fi
fi

# Process all .local files in jail_files directory
step "📂 Installing jail configurations from $JAIL_FILES_DIR"
for jail_file in "${JAIL_FILES_DIR}"/*.local; do
    [ -e "$jail_file" ] || continue  # Handle case with no .local files

    filename=$(basename "$jail_file")
    step "🛡️  Installing ${filename}"

    # Copy file and replace placeholders
    sed -e "s|{{MAX_RETRY}}|$MAX_RETRY|g" \
        -e "s|{{BAN_TIME}}|$BAN_TIME|g" \
        -e "s|{{FIND_TIME}}|$FIND_TIME|g" \
        -e "s|{{IGNORE_IP}}|$IGNORE_IP|g" \
        "$jail_file" > "${JAIL_DIR}/${filename}" || {
        echo "❌ Failed to process ${filename}"
        continue
    }

    echo "✅ Installed ${filename}"
done

# Restart Fail2Ban
step "🔄 Restarting Fail2Ban..."
systemctl restart fail2ban || {
    warn "⚠️ Failed to restart Fail2Ban (is it running?)"
}

# Verify installation
echo ""
info "📋 Installed jails:"
ls -1 "$JAIL_DIR"/*.local 2>/dev/null || echo "No jail files installed"
echo ""
success "✅ Done!"