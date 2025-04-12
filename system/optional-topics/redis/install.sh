#!/usr/bin/env bash
# Redis Installer (Package-based)
set -euo pipefail

# Configuration
BIND_ALL_INTERFACES=true
DISABLE_PROTECTED_MODE=true
REDIS_PASSWORD=""

# Colorized output
function info() { echo -e "\033[34m[INFO]\033[0m $*"; }
function success() { echo -e "\033[32m[✓]\033[0m $*"; }
function warning() { echo -e "\033[33m[!]\033[0m $*"; }
function error() { echo -e "\033[31m[✗]\033[0m $*" >&2; exit 1; }

# ==================== INSTALL FROM PACKAGE ====================
function install_redis() {
  info "Installing Redis from official package..."

  # Ubuntu/Debian
  if command -v apt &>/dev/null; then
    apt update
    apt install -y redis-server

  # RHEL/CentOS
  elif command -v yum &>/dev/null; then
    yum install -y epel-release
    yum install -y redis

  else
    error "Unsupported package manager"
  fi

  success "Redis installed via package manager"
}

# ==================== CONFIGURATION ====================
function configure_redis() {
  info "Configuring Redis..."

  local CONFIG_FILE="/etc/redis/redis.conf"
  cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

  # Bind to all interfaces if requested
  if [[ "$BIND_ALL_INTERFACES" == true ]]; then
    sed -i 's/^bind 127.0.0.1 -::1/bind * -::*/' "$CONFIG_FILE"
    success "Redis configured to listen on all interfaces"
  fi

  # Disable protected mode if requested
  if [[ "$DISABLE_PROTECTED_MODE" == true ]]; then
    sed -i 's/^protected-mode yes/protected-mode no/' "$CONFIG_FILE"
    success "Disabled Redis protected mode"
  fi

  # Set password if provided
  if [[ -n "$REDIS_PASSWORD" ]]; then
    sed -i "s/^# requirepass .*/requirepass $REDIS_PASSWORD/" "$CONFIG_FILE"
    success "Redis password configured"
  fi

  # Modern optimizations
  echo -e "\n# Performance optimizations" >> "$CONFIG_FILE"
  echo "maxmemory-policy allkeys-lru" >> "$CONFIG_FILE"
  echo 'save ""' >> "$CONFIG_FILE"
}

# ==================== SERVICE MANAGEMENT ====================
function manage_service() {
  info "Restarting Redis..."

  if command -v systemctl &>/dev/null; then
    systemctl restart redis
    systemctl enable --now redis
  else
    service redis restart
  fi

  success "Redis service restarted"
}

# ==================== USAGE ====================
function show_usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --bind-local        Bind to local network interfaces (default: false)
  --enable-protected  Enable protected mode (default: false)
  --password PWD      Set Redis password (default: none)
  --help              Show this help

Example:
  $0 --bind-local --password mysecurepass
EOF
  exit 0
}

# ==================== PARSE ARGUMENTS ====================
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bind-local)
      BIND_ALL_INTERFACES=false
      shift
      ;;
    --enable-protected)
      DISABLE_PROTECTED_MODE=false
      shift
      ;;
    --password)
      REDIS_PASSWORD="$2"
      shift 2
      ;;
    --help|-h)
      show_usage
      ;;
    *)
      error "Unknown option: $1"
      ;;
  esac
done

# ==================== MAIN ====================
function main() {
  install_redis
  configure_redis
  manage_service

  success "Redis installation complete!"
  echo -e "\nConnect using:"
  echo "  redis-cli"
  [[ -n "$REDIS_PASSWORD" ]] && echo "  redis-cli -a $REDIS_PASSWORD"
  echo -e "\nConfiguration:"
  echo "  Config file: /etc/redis/redis.conf"
  echo "  Data directory: /var/lib/redis"
}

main "$@"