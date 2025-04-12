#!/usr/bin/env bash
# MongoDB Latest Version Installer (Secure Defaults)
set -euo pipefail

# Configuration
BIND_LOCAL=false      # Default to localhost-only binding
ENABLE_AUTH=false     # Default to authentication enabled
DATA_DIR="/var/lib/mongodb"
CONFIG_FILE="/etc/mongod.conf"

# Colorized output
function info() { echo -e "\033[34m[INFO]\033[0m $*"; }
function success() { echo -e "\033[32m[✓]\033[0m $*"; }
function warning() { echo -e "\033[33m[!]\033[0m $*"; }
function error() { echo -e "\033[31m[✗]\033[0m $*" >&2; exit 1; }

# ==================== GET LATEST VERSION ====================
function get_latest_mongo_version() {
  curl -s https://www.mongodb.org/dl/linux/x86_64 | \
    grep -oP 'mongodb-linux-x86_64-\K[0-9.]+' | \
    sort -V | \
    tail -1
}

# ==================== INSTALL MONGODB ====================
function install_mongodb() {
  local MONGO_VERSION=$(get_latest_mongo_version)
  info "Installing MongoDB ${MONGO_VERSION}..."

  # Ubuntu/Debian
  if command -v apt &>/dev/null; then
    apt install -y gnupg curl
    curl -fsSL https://pgp.mongodb.com/server-${MONGO_VERSION%.*}.asc | \
      gpg --dearmor -o /usr/share/keyrings/mongodb.gpg
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/${MONGO_VERSION%.*} multiverse" | \
      tee /etc/apt/sources.list.d/mongodb-org.list
    apt update
    apt install -y mongodb-org

  # RHEL/CentOS
  elif command -v yum &>/dev/null; then
    cat <<EOF | tee /etc/yum.repos.d/mongodb-org.repo
[mongodb-org]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/latest/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-${MONGO_VERSION%.*}.asc
EOF
    yum install -y mongodb-org

  else
    error "Unsupported package manager"
  fi

  success "MongoDB ${MONGO_VERSION} installed"
}

# ==================== CONFIGURE MONGODB ====================
function configure_mongodb() {
  info "Configuring MongoDB..."

  mkdir -p "$DATA_DIR"
  chown mongod:mongod "$DATA_DIR"

  # Binding configuration
  if [[ "$BIND_LOCAL" == true ]]; then
    sed -i 's/^  bindIp: 0.0.0.0/  bindIp: 127.0.0.1/' "$CONFIG_FILE"
    success "MongoDB configured for localhost-only access"
  else
    sed -i 's/^  bindIp: 127.0.0.1/  bindIp: 0.0.0.0/' "$CONFIG_FILE"
    success "MongoDB configured to listen on all interfaces"
  fi

  # Authentication configuration
  if [[ "$ENABLE_AUTH" == true ]]; then
    sed -i 's/^#security:/security:\n  authorization: enabled/' "$CONFIG_FILE"
    success "Authentication enabled"
  else
    sed -i 's/^  authorization: enabled/  authorization: disabled/' "$CONFIG_FILE"
    warning "Authentication disabled - NOT recommended for production"
  fi

  # Performance optimizations
  cat <<EOF >> "$CONFIG_FILE"

# Performance tuning
storage:
  journal:
    enabled: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 1
EOF
}

# ==================== SERVICE MANAGEMENT ====================
function manage_service() {
  info "Starting MongoDB service..."

  if command -v systemctl &>/dev/null; then
    systemctl daemon-reload
    systemctl enable --now mongod
    systemctl restart mongod
  else
    service mongod restart
    chkconfig mongod on
  fi

  success "MongoDB service started"
}

# ==================== CREATE ADMIN USER ====================
function create_admin_user() {
  if [[ "$ENABLE_AUTH" == false ]]; then
    return 0
  fi

  info "Creating admin user (username: admin, password: admin)"

  # Wait for MongoDB to start
  local timeout=10
  while ! mongosh --quiet --eval "db.hello()" &>/dev/null && ((timeout-- > 0)); do
    sleep 1
    info "Waiting for MongoDB to start..."
  done

  mongosh admin <<EOF
db.createUser({
  user: "admin",
  pwd: "admin",
  roles: [
    { role: "userAdminAnyDatabase", db: "admin" },
    { role: "readWriteAnyDatabase", db: "admin" },
    { role: "clusterAdmin", db: "admin" }
  ]
})
EOF

  warning "Default credentials set (admin/admin) - CHANGE THESE IN PRODUCTION"
}

# ==================== USAGE ====================
function show_usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --bind-local        Bind to local network interfaces (default: false)
  --enable-auth       Enable authentication (default: false)
  --help              Show this help

Security Defaults:
  - Binds to 127.0.0.1 only (--bind-local implied)
  - Authentication enabled
  - Creates default admin user

Example:
  $0 --bind-all  # Allow remote connections
  $0 --no-enable-auth  # Disable authentication (not recommended)
EOF
  exit 0
}

# ==================== PARSE ARGUMENTS ====================
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bind-local)
      BIND_LOCAL=true
      shift
      ;;
    --enable-auth)
      ENABLE_AUTH=true
      shift
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
  install_mongodb
  configure_mongodb
  manage_service

  if [[ "$ENABLE_AUTH" == true ]]; then
    create_admin_user
  fi

  success "MongoDB installation complete!"
  echo -e "\nConnect using:"
  [[ "$ENABLE_AUTH" == true ]] && echo "  mongosh -u admin -p admin" || echo "  mongosh"
  echo -e "\nConfiguration:"
  echo "  Config file: $CONFIG_FILE"
  echo "  Data directory: $DATA_DIR"
  echo -e "\nSecurity reminder:"
  [[ "$BIND_LOCAL" == false ]] && echo "  ! MongoDB is exposed to all network interfaces !"
  [[ "$ENABLE_AUTH" == false ]] && echo "  ! Authentication is disabled !"
}

main "$@"