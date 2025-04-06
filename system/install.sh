#!/usr/bin/env bash

# Enable strict error handling
set -euo pipefail

# Colorized output functions
function info() {
  tput setaf 6 # Cyan
  printf "[INFO] %s\n" "$@"
  tput sgr0
}

function success() {
  tput setaf 2 # Green
  printf "[✓] %s\n" "$@"
  tput sgr0
}

function warning() {
  tput setaf 3 # Yellow
  printf "[!] %s\n" "$@"
  tput sgr0
}

function speedup_apt() {
  # Check if running as root
  if [[ $EUID -ne 0 ]]; then
    warning "This script requires root privileges. Restarting with sudo..."
    exec sudo "$0" "$@"
    exit $?
  fi

  # 1. Install netselect-apt for mirror optimization
  info "Installing mirror selection tool..."
  if ! command -v netselect-apt &>/dev/null; then
    apt install -y netselect-apt
    success "netselect-apt installed"
  else
    info "netselect-apt already installed"
  fi

  # 2. Find fastest mirrors (with backup)
  info "Finding fastest mirrors..."
  if netselect-apt -n -o /etc/apt/sources.list; then
    success "Mirrors optimized"
  else
    warning "Mirror optimization failed, using defaults"
    cp /etc/apt/sources.list.bak /etc/apt/sources.list 2>/dev/null || true
  fi

  # 3. Configure dpkg options
  info "Configuring dpkg options..."
  cat <<EOF | tee /etc/apt/apt.conf.d/local >/dev/null
DPkg::options {
   "--force-confdef";
   "--force-confold";
};
DPkg::Workers "4";
EOF
  success "dpkg configured for non-interactive upgrades"

  # 4. Parallel downloads configuration
  info "Enabling parallel downloads..."
  cat <<EOF | tee /etc/apt/apt.conf.d/00parallel >/dev/null
APT::Acquire {
  Queue-Mode "access";
  Retries "3";
  http {
    Pipeline-Depth "10";
    Dl-Limit "1000000";
    Timeout "30";
    No-cache "false";
  };
};
EOF
  success "Parallel downloads enabled"

  # 5. Disable IPv6 if needed (optional)
  # if ping -c 1 archive.ubuntu.com &> /dev/null; then
  #   info "IPv6 connectivity test passed"
  # else
  #   info "Disabling IPv6 for APT"
  #   echo 'Acquire::ForceIPv4 "true";' | tee /etc/apt/apt.conf.d/99force-ipv4 >/dev/null
  # fi

  # 6. Clean and update
  info "Cleaning and updating package lists..."
  apt clean
  apt update
  success "Package lists updated"

  # Final report
  success "APT optimization complete!"
  info "Recommended next step: Run 'apt full-upgrade'"
}

function hardening() {
  sudo dpkg-reconfigure -plow unattended-upgrades
  echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-swappiness.conf
  sudo sysctl -p
  echo "SystemMaxUse=1G" | sudo tee -a /etc/systemd/journald.conf
  sudo systemctl restart systemd-journald
}
