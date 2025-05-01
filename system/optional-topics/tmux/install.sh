#!/usr/bin/env bash
# TMUX Installation and Configuration Script
# Features:
# - Installs latest tmux via package manager
# - Configures tmux with essential settings
# - Installs TPM plugin manager
# - Preserves existing config with backups

# Load logging utilities
DOTFILES_ROOT="/usr/local/share/dotfiles-system"
source "${DOTFILES_ROOT}/system/scripts/logging.sh" 2>/dev/null || {
  echo "Error: Failed to load logging utilities" >&2
  exit 1
}

# TMUX configuration
TMUX_CONFIG_DIR="$HOME/.config/tmux"
TMUX_PLUGIN_DIR="$TMUX_CONFIG_DIR/plugins"
TMUX_CONF="$TMUX_CONFIG_DIR/tmux.conf"
TMUX_BACKUP_DIR="$HOME/.tmux-backup-$(date +%Y%m%d)"

# Install tmux via package manager
function install_tmux() {
  step "Installing tmux..."

  if command -v tmux &>/dev/null; then
    local current_version
    current_version=$(tmux -V | awk '{print $2}')
    info "tmux $current_version is already installed"
    return 0
  fi

  if ! sudo apt-get install -y tmux; then
    error "Failed to install tmux"
  fi

  success "tmux $(tmux -V | awk '{print $2}') installed"
}

# Backup existing config
function backup_config() {
  if [[ -f "$HOME/.tmux.conf" || -d "$TMUX_CONFIG_DIR" ]]; then
    step "Backing up existing tmux configuration..."
    mkdir -p "$TMUX_BACKUP_DIR"

    [[ -f "$HOME/.tmux.conf" ]] && mv "$HOME/.tmux.conf" "$TMUX_BACKUP_DIR/"
    [[ -d "$TMUX_CONFIG_DIR" ]] && mv "$TMUX_CONFIG_DIR" "$TMUX_BACKUP_DIR/"

    success "Backup created at $TMUX_BACKUP_DIR"
  fi
}

# Configure tmux
function configure_tmux() {
  step "Creating tmux configuration..."

  mkdir -p "$TMUX_CONFIG_DIR" "$TMUX_PLUGIN_DIR"

  info "Creating minimal configuration..."
  cat > "$TMUX_CONF" << 'EOL'
# General settings
set -g default-terminal "tmux-256color"
set -g base-index 1
set -g pane-base-index 1
set -g renumber-windows on
set -g history-limit 10000
set -g mouse on

# Key bindings
unbind C-b
set -g prefix C-a
bind C-a send-prefix
bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"

# Plugin manager (TPM)
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'

# Initialize TMUX plugin manager (keep this line at the very bottom)
run '~/.config/tmux/plugins/tpm/tpm'
EOL

  success "Configuration created at $TMUX_CONF"

  # Create symlink for legacy support
  ln -sf "$TMUX_CONF" "$HOME/.tmux.conf"
}

# Install plugins
function install_plugins() {
  step "Installing tmux plugins..."

  info "Cloning TPM..."
  git clone https://github.com/tmux-plugins/tpm "$TMUX_PLUGIN_DIR/tpm" || {
    error "Failed to clone TPM"
  }

  success "Plugins installed"
  info "Remember to install plugins with: Prefix + I (Ctrl-a I)"
}

# Main installation flow
function main() {
  step "Starting tmux installation"

  if ! confirm "Proceed with tmux installation?"; then
    info "Installation cancelled"
    exit 0
  fi

  install_tmux
  backup_config
  configure_tmux
  install_plugins

  success "tmux installation complete!"
  info "To start using tmux:"
  echo -e "  ${GREEN}1.${NC} Start a new session: ${BLUE}tmux${NC}"
  echo -e "  ${GREEN}2.${NC} Reload config: ${BLUE}Ctrl-a + r${NC}"
  echo -e "  ${GREEN}3.${NC} Install plugins: ${BLUE}Ctrl-a + I${NC}"
}

main