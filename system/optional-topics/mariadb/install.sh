#!/usr/bin/env bash
# MariaDB Installer (Always installs latest version, Default: Binds to All Interfaces)
set -euo pipefail

# Configuration
ENABLE_AUTH=true
BIND_LOCAL=false # Default to binding to all interfaces
ROOT_PASSWORD=""
CREATE_SAMPLE_DB=false
SAMPLE_DB_NAME="testdb"
SAMPLE_DB_USER="testuser"
SAMPLE_DB_PASS="testpass123"

# Colorized output
function info() { echo -e "\033[34m[INFO]\033[0m $*"; }
function success() { echo -e "\033[32m[✓]\033[0m $*"; }
function warning() { echo -e "\033[33m[!]\033[0m $*"; }
function error() {
  echo -e "\033[31m[✗]\033[0m $*" >&2
  exit 1
}

# ==================== INSTALL MARIA DB ====================
function install_mariadb() {
  info "Installing latest MariaDB version..."

  # Ubuntu/Debian
  if command -v apt &>/dev/null; then
    info "Setting up MariaDB repository for Ubuntu/Debian..."
    apt install -y software-properties-common
    apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
    # Use the official MariaDB repository that always points to latest stable
    add-apt-repository -y 'deb [arch=amd64,arm64,ppc64el] https://mirrors.xtom.nl/mariadb/repo/latest/ubuntu $(lsb_release -cs) main'
    apt update
    apt install -y mariadb-server mariadb-client

  # RHEL/CentOS/Rocky/AlmaLinux
  elif command -v yum &>/dev/null; then
    info "Setting up MariaDB repository for RHEL/CentOS..."
    # Create repo file that points to latest stable
    cat <<EOF | tee /etc/yum.repos.d/mariadb.repo
[mariadb]
name = MariaDB
baseurl = https://mirrors.xtom.nl/mariadb/yum/latest/rhel\$releasever-amd64
gpgkey = https://mariadb.org/mariadb_release_signing_key.asc
gpgcheck = 1
module_hotfixes = 1
EOF
    yum install -y MariaDB-server MariaDB-client

  # Fedora
  elif command -v dnf &>/dev/null; then
    info "Setting up MariaDB repository for Fedora..."
    # Create repo file that points to latest stable
    cat <<EOF | tee /etc/yum.repos.d/mariadb.repo
[mariadb]
name = MariaDB
baseurl = https://mirrors.xtom.nl/mariadb/yum/latest/fedora/\$releasever/\$basearch
gpgkey = https://mariadb.org/mariadb_release_signing_key.asc
gpgcheck = 1
module_hotfixes = 1
EOF
    dnf install -y MariaDB-server MariaDB-client

  else
    error "Unsupported package manager"
  fi

  # Enable and start the service
  if systemctl is-active mariadb &>/dev/null; then
    info "MariaDB service is already running"
  else
    systemctl enable --now mariadb
  fi

  success "Latest MariaDB version installed"
}

# ==================== SECURE INSTALLATION ====================
function secure_installation() {
  info "Securing MariaDB installation..."

  if [[ -z "$ROOT_PASSWORD" ]]; then
    ROOT_PASSWORD=$(openssl rand -base64 24)
    warning "Generated random root password: $ROOT_PASSWORD"
  fi

  mysql -uroot <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PASSWORD';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

  success "MariaDB secured with root password"
}

# ==================== CONFIGURATION ====================
function configure_mariadb() {
  info "Configuring MariaDB..."

  # Find the appropriate config file location
  local config_file
  if [[ -f /etc/mysql/mariadb.conf.d/50-server.cnf ]]; then
    config_file="/etc/mysql/mariadb.conf.d/50-server.cnf"
  elif [[ -f /etc/mysql/my.cnf ]]; then
    config_file="/etc/mysql/my.cnf"
  elif [[ -f /etc/my.cnf ]]; then
    config_file="/etc/my.cnf"
  else
    config_file="/etc/mysql/mariadb.cnf"
  fi

  [[ -f "$config_file" ]] || error "MariaDB configuration file not found"

  cp "$config_file" "${config_file}.bak"

  # Binding configuration (default: 0.0.0.0)
  if [[ "$BIND_LOCAL" == true ]]; then
    sed -i '/^\[mysqld\]/a bind-address = 127.0.0.1' "$config_file"
    success "Bound to localhost only"
  else
    sed -i '/^\[mysqld\]/a bind-address = 0.0.0.0' "$config_file"
    warning "Bound to ALL interfaces (0.0.0.0)"
  fi

  # Performance tuning
  cat <<EOF >>"$config_file"

# Performance tuning
[mysqld]
innodb_buffer_pool_size = 1G
innodb_log_file_size = 256M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
EOF

  systemctl restart mariadb
}

# ==================== CREATE SAMPLE DB ====================
function create_sample_db() {
  [[ "$CREATE_SAMPLE_DB" != true ]] && return

  info "Creating sample database: $SAMPLE_DB_NAME"
  mysql -uroot -p"$ROOT_PASSWORD" <<EOF
CREATE DATABASE IF NOT EXISTS $SAMPLE_DB_NAME;
CREATE USER IF NOT EXISTS '$SAMPLE_DB_USER'@'%' IDENTIFIED BY '$SAMPLE_DB_PASS';
GRANT ALL PRIVILEGES ON $SAMPLE_DB_NAME.* TO '$SAMPLE_DB_USER'@'%';
FLUSH PRIVILEGES;
EOF

  success "Sample database created (accessible from any host)"
  echo "  Database: $SAMPLE_DB_NAME"
  echo "  Username: $SAMPLE_DB_USER"
  echo "  Password: $SAMPLE_DB_PASS"
}

# ==================== USAGE ====================
function show_usage() {
  cat <<EOF
MariaDB Installer (Always installs latest version, Default: Binds to ALL interfaces)

Usage: $0 [options]

Options:
  --bind-local        Bind to localhost only (default: all interfaces)
  --no-auth           Disable authentication (not recommended)
  --root-pass PASS    Set custom root password (default: random)
  --create-sample-db  Create a sample database
  --help              Show this help

Security Notes:
  - Default binding: 0.0.0.0 (all interfaces)
  - Authentication enabled by default
  - Random root password if not specified
  - Always installs the latest stable MariaDB version

Example:
  $0 --root-pass mysecurepass --bind-local
EOF
  exit 0
}

# ==================== MAIN ====================
function main() {
  install_mariadb

  [[ "$ENABLE_AUTH" == true ]] && secure_installation || warning "Authentication disabled!"

  configure_mariadb
  [[ "$CREATE_SAMPLE_DB" == true ]] && create_sample_db

  success "MariaDB installation complete!"
  echo -e "\nConnection info:"
  [[ "$ENABLE_AUTH" == true ]] && echo "  mysql -uroot -p'$ROOT_PASSWORD'" || echo "  mysql -uroot"
  [[ "$BIND_LOCAL" == false ]] && warning "!! MariaDB is accessible from ALL interfaces !!"
  [[ "$BIND_LOCAL" == true ]] && info "Bound to localhost only"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
  --bind-local)
    BIND_LOCAL=true
    shift
    ;;
  --no-auth)
    ENABLE_AUTH=false
    shift
    ;;
  --root-pass)
    ROOT_PASSWORD="$2"
    shift 2
    ;;
  --create-sample-db)
    CREATE_SAMPLE_DB=true
    shift
    ;;
  --help | -h)
    show_usage
    ;;
  *)
    error "Unknown option: $1"
    ;;
  esac
done

main "$@"
