#!/usr/bin/env bash
# System-wide ZSH Installation Script
set -euo pipefail

DOTFILES_ROOT="/usr/local/share/dotfiles-system"
source "${DOTFILES_ROOT}/system/scripts/logging.sh"

function install_zsh() {
  info "Starting ZSH installation..."

  # Install ZSH package
  if ! command -v zsh >/dev/null; then
    info "Installing ZSH package..."
    sudo apt-get update -qq
    sudo apt-get install -y --no-install-recommends zsh
    success "ZSH installed successfully"
  else
    success "ZSH is already installed (version: $(zsh --version))"
  fi

  # Set as default shell system-wide
  info "Configuring ZSH as default shell..."

  # 1. For existing users
  if [[ "$SHELL" != "$(command -v zsh)" ]]; then
    if sudo chsh -s "$(command -v zsh)" "$(whoami)"; then
      success "Changed default shell for current user"
    else
      warning "Could not change shell for current user (may need to manually run 'chsh -s \$(which zsh)')"
    fi
  else
    success "ZSH is already the default shell for current user"
  fi

  # 2. For new users (system-wide default)
  if [[ -f /etc/adduser.conf ]]; then
    if grep -q '^DSHELL=.*zsh' /etc/adduser.conf; then
      success "ZSH is already system default for new users"
    else
      sudo sed -i 's/^DSHELL=.*/DSHELL=$(which zsh)/' /etc/adduser.conf
      success "Set ZSH as system default for new users"
    fi
  fi

  # 3. For root user (optional)
  read -rp "Set ZSH as default shell for root user? [y/N] " set_root
  if [[ "${set_root,,}" =~ ^(y|yes)$ ]]; then
    sudo chsh -s "$(command -v zsh)" root
    success "Changed default shell for root user"
  fi

  # Verify installation
  if [[ -x "$(command -v zsh)" ]]; then
    success "ZSH installation complete"
    info "Existing users may need to log out and back in for changes to take effect"
  else
    error "ZSH installation failed - binary not found"
  fi
}

install_zsh