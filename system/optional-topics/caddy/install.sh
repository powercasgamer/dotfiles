#!/usr/bin/env bash
# Latest Caddy 2 Installer with xcaddy and config template support
set -euo pipefail

# Configuration
INSTALL_DIR="/usr/local/bin"
XCADDY_DIR="/opt/xcaddy-build"
CADDY_CONFIG_DIR="/etc/caddy"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CADDY_TEMPLATE="${SCRIPT_DIR}/Caddyfile"

# Colorized output
function info() { echo -e "\033[34m[INFO]\033[0m $*"; }
function success() { echo -e "\033[32m[✓]\033[0m $*"; }
function warning() { echo -e "\033[33m[!]\033[0m $*"; }
function error() { echo -e "\033[31m[✗]\033[0m $*" >&2; exit 1; }

# ==================== CONFIG TEMPLATE ====================
function setup_config() {
  info "Setting up Caddy configuration..."

  if [[ ! -f "$CADDY_TEMPLATE" ]]; then
    error "Caddyfile template not found at $CADDY_TEMPLATE"
  fi

  mkdir -p "$CADDY_CONFIG_DIR"
  cp "$CADDY_TEMPLATE" "$CADDY_CONFIG_DIR/Caddyfile"
  chown -R caddy:caddy "$CADDY_CONFIG_DIR"
  chmod 644 "$CADDY_CONFIG_DIR/Caddyfile"

  success "Caddyfile configured at $CADDY_CONFIG_DIR/Caddyfile"
}

# ==================== LATEST VERSION DETECTION ====================
function get_latest_go() {
  curl -s https://go.dev/VERSION?m=text | head -1 | sed 's/go//'
}

function get_latest_caddy() {
  curl -s https://api.github.com/repos/caddyserver/caddy/releases/latest |
    grep '"tag_name":' |
    sed -E 's/.*"v([^"]+)".*/\1/'
}

# ==================== REQUIREMENTS CHECK ====================
function check_requirements() {
  local reqs=("git" "curl" "tar" "jq")
  local missing=()

  for cmd in "${reqs[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    warning "Missing dependencies: ${missing[*]}"
    apt update
    apt install -y "${missing[@]}"
    success "Dependencies installed"
  fi
}

# ==================== GO INSTALLATION ====================
function install_go() {
  local GO_VERSION=$(get_latest_go)
  info "Installing latest Go (${GO_VERSION})..."

  if command -v go &>/dev/null; then
    local installed_ver=$(go version | awk '{print $3}' | sed 's/go//')
    if [[ "$installed_ver" == "$GO_VERSION" ]]; then
      info "Go ${GO_VERSION} already installed"
      return 0
    fi
  fi

  local go_tar="go${GO_VERSION}.linux-amd64.tar.gz"
  mkdir -p "$XCADDY_DIR"
  cd "$XCADDY_DIR"

  curl -OL "https://golang.org/dl/${go_tar}"
  rm -rf /usr/local/go
  tar -C /usr/local -xzf "$go_tar"

  setup_go_path
  success "Go ${GO_VERSION} installed"
}

function setup_go_path() {
  if ! grep -q "/usr/local/go/bin" /etc/profile; then
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
  fi

  if [[ -f /etc/zsh/zprofile ]] && ! grep -q "/usr/local/go/bin" /etc/zsh/zprofile; then
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/zsh/zprofile
  fi

  export PATH=$PATH:/usr/local/go/bin
}

# ==================== XCADDY BUILD ====================
function build_caddy() {
  local CADDY_VERSION=$(get_latest_caddy)
  info "Building latest Caddy (${CADDY_VERSION}) with xcaddy..."

  export GOPATH="$XCADDY_DIR/go"
  export GOBIN="$GOPATH/bin"
  mkdir -p "$GOPATH"

  go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

  local plugins=(
    "github.com/caddy-dns/cloudflare"
    "github.com/enum-gg/caddy-discord"
  )

  local build_cmd=("$GOBIN/xcaddy" build "v${CADDY_VERSION}")
  for plugin in "${plugins[@]}"; do
    build_cmd+=("--with" "$plugin")
  done

  if ! "${build_cmd[@]}"; then
    error "Failed to build Caddy"
  fi

  mv caddy "$INSTALL_DIR"
  setcap 'cap_net_bind_service=+ep' "$INSTALL_DIR/caddy"
  success "Caddy ${CADDY_VERSION} built with plugins"
}

# ==================== SYSTEMD SERVICE ====================
function configure_service() {
  info "Configuring Caddy systemd service..."

  if ! id caddy &>/dev/null; then
    useradd --system --shell /usr/sbin/nologin --home-dir /etc/caddy caddy
  fi

  cat > /etc/systemd/system/caddy.service << 'EOL'
[Unit]
Description=Caddy 2
Documentation=https://caddyserver.com/docs/
After=network.target

[Service]
User=caddy
Group=caddy
ExecStart=/usr/local/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/caddy/Caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOL

  systemctl daemon-reload
  systemctl enable --now caddy
  success "Caddy service configured"
}

# ==================== MAIN ====================
function main() {
  check_requirements
  install_go
  build_caddy
  setup_config
  configure_service

  success "Installation complete!"
  echo -e "\nVersions:"
  go version
  /usr/local/bin/caddy version

  echo -e "\nNext steps:"
  echo "1. Verify config: $CADDY_CONFIG_DIR/Caddyfile"
  echo "2. Check status: systemctl status caddy"
  echo "3. Test: curl -I http://localhost"
}

main "$@"