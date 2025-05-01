#!/usr/bin/env bash
# Complete PHP Installer for Pterodactyl
set -euo pipefail

# Load logging utilities
DOTFILES_ROOT="/usr/local/share/dotfiles-system"
source "${DOTFILES_ROOT}/system/scripts/logging.sh"

# ==================== CONFIGURATION ====================
# Your explicitly requested extensions
REQUIRED_EXTENSIONS=(
  "cli"
  "openssl"
  "gd"
  "mysql"
  "pdo"
  "mbstring"
  "tokenizer"
  "bcmath"
  "xml"
  "dom"
  "curl"
  "zip"
  "fpm"
)

# Additional recommended extensions (from previous version)
RECOMMENDED_EXTENSIONS=(
  "opcache"
  "fileinfo"
  "ctype"
  "session"
  "simplexml"
  "json"
)

# ==================== REPOSITORY SETUP ====================
function setup_ondrej_repo() {
  step "Configuring PHP repository"
  apt update
  apt install -y software-properties-common
  add-apt-repository -y ppa:ondrej/php
  apt update
  success "PHP repository ready"
}

# ==================== VERSION MANAGEMENT ====================
function get_latest_php_version() {
  apt-cache policy php* | \
    grep -oP 'php[0-9]+\.[0-9]+' | \
    sort -V | uniq | grep -v 'php[0-9]\.[0-9]\+-' | \
    tail -1
}

# ==================== PACKAGE INSTALLATION ====================
function install_php_stack() {
  local version="$1"

  step "Installing PHP ${version} with complete extension set"

  # Combine all extensions
  local all_extensions=("${REQUIRED_EXTENSIONS[@]}" "${RECOMMENDED_EXTENSIONS[@]}")
  local unique_extensions=($(printf "%s\n" "${all_extensions[@]}" | sort -u))

  # Build package list
  local packages=("${version}" "${version}-common")
  for ext in "${unique_extensions[@]}"; do
    packages+=("${version}-${ext}")
  done

  apt install -y "${packages[@]}"

  # Verification
  success "Installed:"
  php -m | grep -E "$(IFS="|"; echo "${unique_extensions[*]}")" | sort | xargs -n1 echo " - "
}

# ==================== PTERODACTYL OPTIMIZATION ====================
function optimize_for_pterodactyl() {
  local version="$1"

  step "Optimizing for Pterodactyl"

  # PHP.ini settings
  local php_ini="/etc/php/${version#php}/fpm/php.ini"
  sed -i \
    -e 's/^;*\(max_input_vars = \).*/\110000/' \
    -e 's/^;*\(upload_max_filesize = \).*/\1100M/' \
    -e 's/^;*\(post_max_size = \).*/\1100M/' \
    -e 's/^;*\(memory_limit = \).*/\1512M/' \
    -e 's/^;*\(opcache.enable = \).*/\11/' \
    -e 's/^;*\(opcache.enable_cli = \).*/\11/' \
    "$php_ini"

  # FPM pool config
  local fpm_pool="/etc/php/${version#php}/fpm/pool.d/www.conf"
  sed -i \
    -e 's/^;*\(pm.max_children = \).*/\125/' \
    -e 's/^;*\(pm.start_servers = \).*/\15/' \
    -e 's/^;*\(pm.min_spare_servers = \).*/\13/' \
    -e 's/^;*\(pm.max_spare_servers = \).*/\110/' \
    "$fpm_pool"

  systemctl restart "${version}-fpm"
  success "Optimizations applied"
}

# ==================== COMPOSER INSTALLATION ====================
function install_composer() {
  if ! command -v composer &>/dev/null; then
    step "Installing Composer"
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    success "Composer ready"
  fi
}

# ==================== MAIN SCRIPT ====================
function main() {
  setup_ondrej_repo

  local php_version
  php_version=$(get_latest_php_version)

  info "Target PHP version: ${php_version}"

  install_php_stack "$php_version"
  optimize_for_pterodactyl "$php_version"
  install_composer

  success "Pterodactyl-ready PHP installed!"
  echo -e "\n\033[1mValidation:\033[0m"
  echo "1. PHP: php -v"
  echo "2. Extensions: php -m | grep -E '$(IFS="|"; echo "${REQUIRED_EXTENSIONS[*]}")'"
  echo "3. FPM: systemctl status ${php_version}-fpm"
  echo "4. Composer: composer --version"
  echo -e "\n\033[1mRecommended:\033[0m"
  echo "Run 'php -m' to verify all extensions loaded"
}

main "$@"