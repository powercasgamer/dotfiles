#!/usr/bin/env bash
# phpMyAdmin Installer with PHP Version Support
set -euo pipefail

# Configuration (auto-detect with override)
DEFAULT_PHP_VERSION=$(php -v | head -n1 | cut -d' ' -f2 | cut -d'.' -f1-2)
PHP_VERSION="${PHP_VERSION:-$DEFAULT_PHP_VERSION}"
PMADIR="/usr/share/phpmyadmin"
CADDY_ROOT="/var/www/html"
CADDY_MAIN_CONFIG="/etc/caddy/Caddyfile"
CADDY_CONFIG_DIR="/etc/caddy/conf.d"
CADDY_PMA_CONFIG="${CADDY_CONFIG_DIR}/phpmyadmin.conf"
PMACONFIG="/etc/phpmyadmin/config.inc.php"

# Dotfiles paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CADDY_TEMPLATE="${SCRIPT_DIR}/phpmyadmin.caddy"

# Colorized output
function info() { echo -e "\033[34m[INFO]\033[0m $*"; }
function success() { echo -e "\033[32m[✓]\033[0m $*"; }
function warning() { echo -e "\033[33m[!]\033[0m $*"; }
function error() { echo -e "\033[31m[✗]\033[0m $*" >&2; exit 1; }

# ==================== REQUIREMENTS CHECK ====================
function check_requirements() {
  info "Checking PHP ${PHP_VERSION} requirements..."

  # Verify PHP version exists
  if [[ ! -d "/etc/php/${PHP_VERSION}" ]]; then
    error "PHP ${PHP_VERSION} is not installed"
  fi

  # Verify Caddy
  if ! command -v caddy &>/dev/null; then
    error "Caddy web server is required"
  fi

  # Verify template
  if [[ ! -f "$CADDY_TEMPLATE" ]]; then
    error "Caddy template not found at: $CADDY_TEMPLATE"
  fi

  success "All requirements met for PHP ${PHP_VERSION}"
}

# ==================== INSTALLATION ====================
function install_packages() {
  info "Installing packages for PHP ${PHP_VERSION}..."

  # Debian/Ubuntu
  if command -v apt &>/dev/null; then
    sudo apt update
    sudo apt install -y phpmyadmin \
      php${PHP_VERSION}-mbstring \
      php${PHP_VERSION}-zip \
      php${PHP_VERSION}-gd \
      php${PHP_VERSION}-json \
      php${PHP_VERSION}-curl

    sudo phpenmod -v $PHP_VERSION mbstring

  # RHEL/CentOS
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y phpmyadmin \
      php-${PHP_VERSION}-mbstring \
      php-${PHP_VERSION}-zip \
      php-${PHP_VERSION}-gd \
      php-${PHP_VERSION}-json \
      php-${PHP_VERSION}-curl

    sudo setsebool -P httpd_can_network_connect_db 1
  fi

  # Symlink phpMyAdmin
  if [[ ! -L "${CADDY_ROOT}/phpmyadmin" ]]; then
    sudo ln -s "$PMADIR" "${CADDY_ROOT}/phpmyadmin"
  fi
}

# ==================== CADDY CONFIGURATION ====================
function configure_caddy() {
  info "Configuring Caddy for PHP ${PHP_VERSION}..."

  # Generate credentials
  local admin_user="pma_$(openssl rand -hex 3)"
  local password=$(openssl rand -base64 16)
  local hashed_password=$(caddy hash-password --plaintext "$password")

  # Process template
  sudo mkdir -p "$CADDY_CONFIG_DIR"
  sed \
    -e "s/{{hostname}}/$(hostname)/g" \
    -e "s|{{webroot}}|${CADDY_ROOT}|g" \
    -e "s/{{admin_user}}/${admin_user}/g" \
    -e "s|{{hashed_password}}|${hashed_password}|g" \
    -e "s|{{PHP_VERSION}}|${PHP_VERSION}|g" \
    "$CADDY_TEMPLATE" | sudo tee "$CADDY_PMA_CONFIG" >/dev/null

  # Ensure import exists
  if ! grep -q "import conf.d/*.conf" "$CADDY_MAIN_CONFIG"; then
    echo -e "\nimport conf.d/*.conf" | sudo tee -a "$CADDY_MAIN_CONFIG" >/dev/null
  fi

  # Save credentials
  echo -e "phpMyAdmin Credentials:\nURL: https://phpmyadmin.$(hostname)\nUser: ${admin_user}\nPass: ${password}" \
    | sudo tee /root/phpmyadmin_credentials.txt >/dev/null

  # Validate and reload
  sudo caddy validate --config "$CADDY_MAIN_CONFIG" || error "Configuration invalid"
  sudo systemctl reload caddy
}

# ==================== SECURITY HARDENING ====================
function secure_installation() {
  info "Securing PHP ${PHP_VERSION} installation..."

  # Blowfish secret
  if [[ -f "$PMACONFIG" ]]; then
    local blowfish_secret=$(openssl rand -base64 32)
    sudo sed -i "s/\$cfg\['blowfish_secret'\] = '';/\$cfg\['blowfish_secret'\] = '${blowfish_secret}';/" "$PMACONFIG"
  fi

  # PHP restrictions
  echo "php_admin_value[open_basedir] = ${CADDY_ROOT}/phpmyadmin:/usr/share/php:/tmp" \
    | sudo tee -a /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf >/dev/null

  sudo systemctl restart php${PHP_VERSION}-fpm
}

# ==================== MAIN ====================
function main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --php-version)
        PHP_VERSION="$2"
        shift 2
        ;;
      --help|-h)
        echo "Usage: $0 [--php-version X.Y]"
        exit 0
        ;;
      *)
        error "Unknown option: $1"
        ;;
    esac
  done

  check_requirements
  install_packages
  configure_caddy
  secure_installation

  success "phpMyAdmin for PHP ${PHP_VERSION} installed successfully!"
  echo -e "\n\033[1mAccess Information:\033[0m"
  echo -e "  URL: \033[34mhttps://phpmyadmin.$(hostname)\033[0m"
  echo -e "  PHP Version: \033[33m${PHP_VERSION}\033[0m"
  echo -e "  Credentials: \033[33m/root/phpmyadmin_credentials.txt\033[0m"
}

main "$@"