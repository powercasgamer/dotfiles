#!/usr/bin/env bash
# Complete PHP Installer & Updater for Pterodactyl
set -euo pipefail

# Load logging utilities
DOTFILES_ROOT="/usr/local/share/dotfiles-system"
source "${DOTFILES_ROOT}/system/scripts/logging.sh"

# ==================== CONFIGURATION ====================
REQUIRED_EXTENSIONS=(
  "bcmath"
  "cli"
  "curl"
  "dom"
  "fpm"
  "gd"
  "intl"
  "mbstring"
  "mysql"
  "openssl"
  "pdo"
  "sqlite3"
  "tokenizer"
  "xml"
  "zip"
)

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

function get_current_php_version() {
  if command -v php &>/dev/null; then
    php -r 'echo "php" . PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;'
  else
    echo ""
  fi
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

# ==================== OLD VERSION CLEANUP ====================
function remove_old_php_version() {
  local old_version="$1"
  local new_version="$2"

  if [[ -z "$old_version" ]]; then
    info "No existing PHP version found to remove"
    return
  fi

  if [[ "$old_version" == "$new_version" ]]; then
    info "Current PHP version ($old_version) matches target version, skipping removal"
    return
  fi

  step "Removing old PHP version: $old_version"

  # Find all PHP packages for the old version
  local old_packages=($(apt list --installed 2>/dev/null | grep -oP "^${old_version}[^\s/]+" | tr '\n' ' '))

  if [[ ${#old_packages[@]} -eq 0 ]]; then
    info "No packages found for PHP $old_version"
    return
  fi

  info "Found packages to remove:"
  printf " - %s\n" "${old_packages[@]}"

  # Remove the packages
  apt remove -y --purge "${old_packages[@]}"
  apt autoremove -y

  # Clean up remaining configuration files
  local old_config_dir="/etc/php/${old_version#php}"
  if [[ -d "$old_config_dir" ]]; then
    rm -rf "$old_config_dir"
  fi

  success "Old PHP version $old_version removed"
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

# ==================== USER PROMPTS ====================
function prompt_for_update() {
  local current_version="$1"
  local latest_version="$2"

  if [[ "$current_version" == "$latest_version" ]]; then
    info "PHP $current_version is already the latest version"
    return 1
  fi

  echo -e "\n\033[1mCurrent PHP version: ${current_version:-None}\033[0m"
  echo -e "\033[1mLatest PHP version: $latest_version\033[0m"
  read -p "Do you want to update PHP to $latest_version? [y/N] " -n 1 -r
  echo

  [[ "$REPLY" =~ ^[Yy]$ ]]
}

function prompt_for_cleanup() {
  local old_version="$1"

  if [[ -z "$old_version" ]]; then
    return 1
  fi

  read -p "Do you want to remove PHP $old_version after installation? [y/N] " -n 1 -r
  echo

  [[ "$REPLY" =~ ^[Yy]$ ]]
}

# ==================== MAIN SCRIPT ====================
function main() {
  setup_ondrej_repo

  local current_version
  current_version=$(get_current_php_version)

  local php_version
  php_version=$(get_latest_php_version)

  if prompt_for_update "$current_version" "$php_version"; then
    install_php_stack "$php_version"
    optimize_for_pterodactyl "$php_version"

    if prompt_for_cleanup "$current_version"; then
      remove_old_php_version "$current_version" "$php_version"
    fi
  else
    info "Using existing PHP version: ${current_version:-None}"
    php_version="$current_version"
  fi

  install_composer

  success "Pelican-ready PHP installed!"
  echo -e "\n\033[1mValidation:\033[0m"
  echo "1. PHP: php -v"
  echo "2. Extensions: php -m | grep -E '$(IFS="|"; echo "${REQUIRED_EXTENSIONS[*]}")'"
  echo "3. FPM: systemctl status ${php_version}-fpm"
  echo "4. Composer: composer --version"
  echo -e "\n\033[1mRecommended:\033[0m"
  echo "Run 'php -m' to verify all extensions loaded"
}

main "$@"