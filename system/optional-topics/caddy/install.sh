#!/usr/bin/env bash
# Latest Caddy 2 Installer with xcaddy
set -euo pipefail

# Configuration
INSTALL_DIR="/usr/local/bin"
XCADDY_DIR="/opt/xcaddy-build"

# Colorized output
function info() { echo -e "\033[34m[INFO]\033[0m $*"; }
function success() { echo -e "\033[32m[✓]\033[0m $*"; }
function warning() { echo -e "\033[33m[!]\033[0m $*"; }
function error() { echo -e "\033[31m[✗]\033[0m $*" >&2; exit 1; }

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

  # Add to PATH if not present
  setup_go_path

  success "Go ${GO_VERSION} installed"
}

function setup_go_path() {
  # Add to /etc/profile (Bash)
  if ! grep -q "/usr/local/go/bin" /etc/profile; then
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
  fi

  # Add to /etc/zsh/zprofile (Zsh)
  if [[ -f /etc/zsh/zprofile ]] && ! grep -q "/usr/local/go/bin" /etc/zsh/zprofile; then
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/zsh/zprofile
  fi

  # Apply to current session
  export PATH=$PATH:/usr/local/go/bin
}

# ==================== XCADDY BUILD ====================
function build_caddy() {
  local CADDY_VERSION=$(get_latest_caddy)
  info "Building latest Caddy (${CADDY_VERSION}) with xcaddy..."

  export GOPATH="$XCADDY_DIR/go"
  export GOBIN="$GOPATH/bin"
  mkdir -p "$GOPATH"

  # Install latest xcaddy
  go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

  # Build Caddy with common plugins
  local plugins=(
    "github.com/caddy-dns/cloudflare"
    "github.com/enum-gg/caddy-discord"
#    "github.com/caddyserver/forwardproxy@latest"
#    "github.com/greenpau/caddy-security@latest"
  )

  local build_cmd=("$GOBIN/xcaddy" build "v${CADDY_VERSION}")
  for plugin in "${plugins[@]}"; do
    build_cmd+=("--with" "$plugin")
  done

  if ! "${build_cmd[@]}"; then
    error "Failed to build Caddy"
  fi

  # Install to system
  mv caddy "$INSTALL_DIR"
  setcap 'cap_net_bind_service=+ep' "$INSTALL_DIR/caddy"

  success "Caddy ${CADDY_VERSION} built with plugins"
}

# ==================== SYSTEMD SERVICE ====================
function configure_service() {
  info "Configuring Caddy systemd service..."

  cat <<EOF | tee /etc/systemd/system/caddy.service >/dev/null
[Unit]
Description=Caddy 2
Documentation=https://caddyserver.com/docs/
After=network.target

[Service]
User=caddy
Group=caddy
ExecStart=$INSTALL_DIR/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=$INSTALL_DIR/caddy reload --config /etc/caddy/Caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

  # Create user and directories
  if ! id caddy &>/dev/null; then
    useradd --system --shell /usr/sbin/nologin --home-dir /etc/caddy caddy
  fi

  mkdir -p /etc/caddy
  chown -R caddy:caddy /etc/caddy

  systemctl daemon-reload
  systemctl enable --now caddy

  success "Caddy service configured"
}

# ==================== MAIN ====================
function main() {
  check_requirements
  install_go
  build_caddy
  configure_service

  success "Installation complete!"
  echo -e "\nVersions:"
  go version
  /usr/local/bin/caddy version

  echo -e "\nNext steps:"
  echo "1. Edit config: /etc/caddy/Caddyfile"
  echo "2. Check status: systemctl status caddy"
  echo "3. Test: curl -I http://localhost"
}

main "$@"