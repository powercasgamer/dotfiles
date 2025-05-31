#!/usr/bin/env bash

# Docker Tailscale Exposer Script with Enhanced Logging
# Configures Docker to listen securely on Tailscale interface with TLS encryption

set -euo pipefail

DOTFILES_ROOT="/usr/local/share/dotfiles-system"
source "${DOTFILES_ROOT}/system/scripts/logging.sh" 2>/dev/null || {
  echo "Error: Failed to load logging utilities" >&2
  exit 1
}

# Configuration
CERT_DAYS=36500  # 100 years
DOCKER_TLS_PORT=2376

# Check for root
if [ "$(id -u)" -ne 0 ]; then
  error "This script must be run as root"
fi

# Stop docker.socket if running
if systemctl is-active --quiet docker.socket; then
  step "Stopping docker.socket..."
  systemctl stop docker.socket || warning "Failed to stop docker.socket"
fi

# Get Tailscale IP (only the first one)
step "Detecting Tailscale IP..."
TAILSCALE_IP=$(tailscale ip -4 | head -n 1)
if [ -z "$TAILSCALE_IP" ]; then
  error "Could not get Tailscale IP. Is Tailscale running?"
fi
success "Detected Tailscale IP: $TAILSCALE_IP"

# Prompt for CA password (handle unset vars)
step "Setting up TLS certificates..."
set +u
read -sp "Enter password for CA certificate: " CA_PASSWORD
echo
read -sp "Confirm password: " CA_PASSWORD_CONFIRM
echo
set -u

if [ "$CA_PASSWORD" != "$CA_PASSWORD_CONFIRM" ]; then
  error "Passwords do not match!"
fi

# Install dependencies
if ! command -v openssl &> /dev/null; then
  info "Installing openssl..."
  if command -v apt-get &> /dev/null; then
    apt-get update && apt-get install -y openssl
  elif command -v yum &> /dev/null; then
    yum install -y openssl
  else
    error "Unsupported package manager. Please install OpenSSL manually."
  fi
fi

# Create docker certs directory
mkdir -p /etc/docker/certs
cd /etc/docker/certs

# Generate CA
info "Generating CA certificate..."
openssl genrsa -aes256 -passout pass:"$CA_PASSWORD" -out ca-key.pem 4096 || {
  error "Failed to generate CA key"
}
openssl req -new -x509 -days "$CERT_DAYS" -key ca-key.pem -passin pass:"$CA_PASSWORD" \
  -sha256 -out ca.pem -subj "/CN=docker-ca" || {
  error "Failed to generate CA certificate"
}

# Generate server key & cert
info "Generating server certificate..."
openssl genrsa -out server-key.pem 4096 || error "Failed to generate server key"
openssl req -subj "/CN=$TAILSCALE_IP" -sha256 -new -key server-key.pem -out server.csr || {
  error "Failed to generate server CSR"
}
echo "subjectAltName = IP:$TAILSCALE_IP,IP:127.0.0.1" > extfile.cnf
openssl x509 -req -days "$CERT_DAYS" -sha256 -in server.csr -CA ca.pem -CAkey ca-key.pem \
  -passin pass:"$CA_PASSWORD" -CAcreateserial -out server-cert.pem -extfile extfile.cnf || {
  error "Failed to sign server certificate"
}

# Generate client key & cert
info "Generating client certificate..."
openssl genrsa -out key.pem 4096 || error "Failed to generate client key"
openssl req -subj '/CN=client' -new -key key.pem -out client.csr || {
  error "Failed to generate client CSR"
}
echo "extendedKeyUsage = clientAuth" > extfile-client.cnf
openssl x509 -req -days "$CERT_DAYS" -sha256 -in client.csr -CA ca.pem -CAkey ca-key.pem \
  -passin pass:"$CA_PASSWORD" -CAcreateserial -out cert.pem -extfile extfile-client.cnf || {
  error "Failed to sign client certificate"
}

# Set permissions
chmod 0400 ca-key.pem key.pem server-key.pem || warning "Failed to set restrictive permissions"
chmod 0444 ca.pem server-cert.pem cert.pem || warning "Failed to set read permissions"

# Cleanup
rm -f client.csr server.csr extfile.cnf extfile-client.cnf ca.srl || warning "Cleanup skipped or partial"

# Configure Docker
step "Configuring Docker daemon..."
cat > /etc/docker/daemon.json <<EOF
{
  "hosts": ["unix:///var/run/docker.sock", "tcp://$TAILSCALE_IP:$DOCKER_TLS_PORT"],
  "tlsverify": true,
  "tlscacert": "/etc/docker/certs/ca.pem",
  "tlscert": "/etc/docker/certs/server-cert.pem",
  "tlskey": "/etc/docker/certs/server-key.pem"
}
EOF

# Systemd override
step "Configuring systemd overrides..."
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd
EOF

# Reload & restart Docker
step "Restarting Docker..."
systemctl daemon-reload || error "Failed to reload systemd"
systemctl restart docker || error "Failed to restart Docker"

# Configure firewall
if command -v ufw &> /dev/null; then
  info "Configuring UFW firewall..."
  ufw allow in on tailscale0 to any port "$DOCKER_TLS_PORT" || warning "Failed to configure UFW"
fi

# Final message
success "Configuration complete!"
echo
info "To connect from another Tailscale node:"
echo "1. Copy these files to the client machine:"
echo "   - /etc/docker/certs/ca.pem"
echo "   - /etc/docker/certs/cert.pem"
echo "   - /etc/docker/certs/key.pem"
echo "2. Set these environment variables:"
echo "   export DOCKER_HOST=tcp://$TAILSCALE_IP:$DOCKER_TLS_PORT"
echo "   export DOCKER_TLS_VERIFY=1"
echo "   export DOCKER_CERT_PATH=/path/to/copied/certs"
echo "3. Test with: docker ps"
echo
warning "Remember to keep your CA password and certificate files secure!"
