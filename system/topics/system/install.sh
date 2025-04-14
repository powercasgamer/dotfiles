#!/usr/bin/env bash
# Ultimate System Optimization & Hardening Script
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

# ==================== ORIGINAL APT OPTIMIZATION ====================
function speedup_apt() {
  info "Starting APT optimization..."

  info "Installing core APT dependencies..."
  apt update
  packages=(
    "apt-transport-https"
    "software-properties-common"
    "ca-certificates"
    "gnupg"
    "curl"
    "wget"
    "git"
  )

  apt install -y "${packages[@]}"

  # 1. Smart IPv6 handling
  info "Testing network connectivity..."
  if ! ping -c 1 -4 archive.ubuntu.com &>/dev/null &&
    ping -c 1 -6 archive.ubuntu.com &>/dev/null; then
    info "Forcing APT to use IPv4 (no IPv4 connectivity detected)"
    echo 'Acquire::ForceIPv4 "true";' | tee /etc/apt/apt.conf.d/99force-ipv4 >/dev/null
  else
    info "No APT network configuration needed"
    rm -f /etc/apt/apt.conf.d/99force-ipv4
  fi

  # 2. Install netselect-apt
  #  if ! command -v netselect-apt &>/dev/null; then
  #    apt update
  #    apt install.sh.sh -y netselect-apt
  #    success "netselect-apt installed"
  #  fi
  #
  #  # 3. Find fastest mirrors
  #  info "Finding fastest mirrors..."
  #  if netselect-apt -n -o /etc/apt/sources.list; then
  #    success "Mirrors optimized"
  #  else
  #    warning "Mirror optimization failed, using defaults"
  #    cp /etc/apt/sources.list.bak /etc/apt/sources.list 2>/dev/null || true
  #  fi

  # 4. Configure dpkg options
  cat <<EOF | tee /etc/apt/apt.conf.d/local >/dev/null
DPkg::options {
   "--force-confdef";
   "--force-confold";
};
DPkg::Workers "4";
EOF

  # 5. Parallel downloads
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

  # 6. Clean and update
  apt clean
  apt update
  success "APT optimization complete!"
}

# ==================== ENHANCED HARDENING ====================
function secure_apt() {
  info "Securing package management..."
  cat <<EOF | tee /etc/apt/apt.conf.d/99-security >/dev/null
APT::Install-Recommends "false";
APT::Install-Suggests "false";
APT::Get::AllowUnauthenticated "false";
APT::Autoremove::SuggestsImportant "false";
EOF
}

function harden_kernel() {
  info "Applying kernel hardening..."
  cat <<EOF | tee /etc/sysctl.d/99-hardening.conf >/dev/null
# IP Spoofing protection
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0

# SYN Flood protection
net.ipv4.tcp_syncookies=1

# Memory optimization
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=5
EOF
  sysctl -p /etc/sysctl.d/99-hardening.conf
}

function setup_fail2ban() {
  info "Configuring Fail2Ban..."
  apt install -y fail2ban

  # SSH Jail
  cat <<EOF | tee /etc/fail2ban/jail.d/ssh.local >/dev/null
[sshd]
enabled = true
maxretry = 3
bantime = 1h
findtime = 1h
EOF

  # phpMyAdmin Jail
  if [[ -d /usr/share/phpmyadmin ]]; then
    cat <<EOF | tee /etc/fail2ban/jail.d/phpmyadmin.local >/dev/null
[phpmyadmin-syslog]
enabled = true
filter = phpmyadmin
logpath = /var/log/syslog
maxretry = 3
bantime = 1h
findtime = 1h
EOF

    cat <<EOF | tee /etc/fail2ban/filter.d/phpmyadmin.conf >/dev/null
[Definition]
failregex = ^.*user denied: .* from <HOST>$
ignoreregex =
EOF
  fi

  # Caddy Jail
  if command -v caddy &>/dev/null; then
    cat <<EOF | tee /etc/fail2ban/jail.d/caddy.local >/dev/null
[caddy]
enabled = true
filter = caddy
logpath = /var/log/caddy/access.log
maxretry = 5
bantime = 1h
findtime = 1h
EOF

    cat <<EOF | tee /etc/fail2ban/filter.d/caddy.conf >/dev/null
[Definition]
failregex = ^<HOST> .* "(GET|POST|HEAD).*" (401|403|404|429|503) .*$
ignoreregex =
EOF
  fi

  systemctl restart fail2ban
}

function optimize_systemd() {
  info "Optimizing systemd..."
  mkdir -p /etc/systemd/journald.conf.d
  cat <<EOF | tee /etc/systemd/journald.conf.d/99-size.conf >/dev/null
SystemMaxUse=100M
RuntimeMaxUse=50M
EOF

  systemctl disable NetworkManager-wait-online.service 2>/dev/null || true
  systemctl mask lvm2-monitor.service 2>/dev/null || true
  systemctl restart systemd-journald
}

function enable_autoupdates() {
  info "Configuring automatic security updates..."
  apt install -y unattended-upgrades needrestart
  cat <<EOF | tee /etc/apt/apt.conf.d/50unattended-upgrades >/dev/null
Unattended-Upgrade::Allowed-Origins {
  "\${distro_id}:\${distro_codename}";
  "\${distro_id}:\${distro_codename}-security";
  "\${distro_id}ESM:\${distro_codename}";
};
Unattended-Upgrade::Package-Blacklist {
  // "docker-ce";
};
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF
}

# ==================== MAIN EXECUTION ====================
function main() {
  # APT Optimization
  speedup_apt

  # System Hardening
  secure_apt
  #  harden_kernel
  setup_fail2ban
  optimize_systemd
  #  enable_autoupdates

  success "All optimizations complete!"
  echo "Recommended checks:"
  echo "1. fail2ban-client status"
  echo "2. grep -i error /var/log/unattended-upgrades/unattended-upgrades.log"
  echo "3. journalctl --disk-usage"
}

main "$@"
