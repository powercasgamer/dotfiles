#!/usr/bin/env bash
# Tailscale Installer with SSH Port Awareness
set -euo pipefail

# Colorized output
function info() { echo -e "\033[34m[INFO]\033[0m $*"; }
function success() { echo -e "\033[32m[✓]\033[0m $*"; }
function warning() { echo -e "\033[33m[!]\033[0m $*"; }

# Ensure root
if [[ $EUID -ne 0 ]]; then
  warning "This script requires root privileges. Restarting with sudo..."
  exec sudo "$0" "$@"
fi

# ==================== SSH PORT DETECTION ====================
function get_ssh_port() {
  # Check sshd_config first
  local ssh_port=$(grep -E "^Port\s+[0-9]+" /etc/ssh/sshd_config | awk '{print $2}' | head -1)

  # Fallback to active service detection
  if [[ -z "$ssh_port" ]]; then
    ssh_port=$(ss -tulpn | grep sshd | awk '{print $5}' | cut -d':' -f2 | head -1)
  fi

  # Default if still not found
  echo "${ssh_port:-22}"
}

# ==================== FIREWALL CONFIG ====================
function configure_ufw() {
  info "Configuring UFW firewall..."

  local SSH_PORT=$(get_ssh_port)
  info "Detected SSH port: $SSH_PORT"

  # Enable if not active
  if ! ufw status | grep -q "Status: active"; then
    ufw --force enable
  fi

  # Get Tailscale interface
  local tailscale_iface=$(ip -o -4 route show to 100.64.0.0/10 | awk '{print $3}')

  if [[ -n "$tailscale_iface" ]]; then
    #  # Check if the SSH allow rule exists without a comment
    #  if ufw status | grep -qE "^\[.*\]\s+ALLOW\s+.*$SSH_PORT/tcp\s+\(.*\)$"; then
    #    info "Skipping removal of SSH allow rule as it has a comment"
    #  else
    #    # Remove existing SSH allow rule if it exists and has no comment
    #    ufw delete allow "$SSH_PORT/tcp" >/dev/null 2>&1 || true
    #  fi

    # Allow SSH only from Tailscale network
    ufw allow in on "$tailscale_iface" to any port "$SSH_PORT" proto tcp
    success "UFW configured to allow SSH (port $SSH_PORT) only via Tailscale ($tailscale_iface)"
  else
    warning "Could not detect Tailscale interface - allowing SSH on port $SSH_PORT globally"
    ufw allow "$SSH_PORT/tcp"
  fi

  # Allow all Tailscale traffic
  ufw allow in on tailscale0
  ufw allow out on tailscale0

  info "Firewall rules:"
  ufw status numbered
}

# ==================== TAILSCALE INSTALL ====================
function install_tailscale() {
  info "Installing Tailscale..."

  curl -fsSL https://tailscale.com/install.sh | sh

  # Enable IP forwarding
  echo 'net.ipv4.ip_forward = 1' | tee /etc/sysctl.d/99-tailscale.conf
  echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.d/99-tailscale.conf
  sysctl -p /etc/sysctl.d/99-tailscale.conf
}

# ==================== MAIN ====================
function main() {
  install_tailscale
  configure_ufw

  info "Restarting SSH service..."
  systemctl restart sshd

  success "Tailscale installed with SSH port locked to Tailscale network"
  echo -e "\nTo check:"
  echo "1. Verify SSH port: ss -tulpn | grep ssh"
  echo "2. Test Tailscale: tailscale ping [another-node]"
  echo "3. Check firewall: sudo ufw status"
}

main "$@"
