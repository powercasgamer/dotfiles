#!/bin/bash

# === Visual functions ===
info() {
  tput setaf 4
  echo "$@"
  tput sgr0
}
warning() {
  tput setaf 3
  tput bold
  echo "$@"
  tput sgr0
  sleep 0.5
}
success() {
  tput setaf 2
  echo "$@"
  tput sgr0
}
code() {
  tput dim
  echo "$@"
  tput sgr0
}

# === Environment Setup ===
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
ACTUAL_USER=$(logname 2>/dev/null || echo "$SUDO_USER" || whoami)
ACTUAL_HOME=$(eval echo "~$ACTUAL_USER")
source "${DOTFILES_ROOT}/system/scripts/logging.sh"

if [ "$(id -u)" -eq 0 ]; then
  DOTFILES_DIR="$ACTUAL_HOME/dotfiles"
  export HOME="$ACTUAL_HOME"
fi

info "Dotfiles will be installed to: $DOTFILES_DIR"

# === OS Detection ===
check_os() {
  local os_arch=$(uname -m)
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    case "$ID" in
    ubuntu | debian | pop | linuxmint | raspbian | kali | neon | elementary | zorin) echo "debian-$os_arch" ;;
    fedora | centos | rhel | almalinux | rocky | ol) echo "rhel-$os_arch" ;;
    arch | manjaro | endeavouros) echo "arch-$os_arch" ;;
    *) echo "unknown-linux-$os_arch" ;;
    esac
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    echo "macos-$os_arch"
  elif [[ "$(uname -s)" =~ BSD ]]; then
    echo "bsd-$os_arch"
  elif [[ -n "$WSL_DISTRO_NAME" ]]; then
    echo "wsl-$os_arch"
  else
    warning "Unsupported operating system: $(uname -s) ($os_arch)"
    return 1
  fi
}

# === Dependency Installer ===
install_required_dependencies() {
  local common_packages=("git" "curl" "wget" "zip" "unzip" "tar" "zsh")
  local os_type=$(check_os)
  echo "DEBUG: Detected OS type: '$os_type'" >&2

  case "$os_type" in
  debian-* | ubuntu-* | pop-* | linuxmint-*)
    info "Installing Linux dependencies..."
    sudo apt update -qy
    sudo apt install -y "${common_packages[@]}"
    ;;
  *macos*)
    info "Checking for macOS dependencies..."
    ;;
  *)
    warning "Unsupported OS: $os_type. Skipping dependency installation."
    return 1
    ;;
  esac

  success "Dependencies installed successfully!"
  return 0
}

# === Git Sync ===
sync_dotfiles_repo() {
  if [[ ! -d "$DOTFILES_DIR" ]]; then
    info "==> Cloning dotfiles repo..."
    git clone https://github.com/powercasgamer/dotfiles.git "$DOTFILES_DIR"
  else
    info "==> Updating dotfiles repo..."
    cd "$DOTFILES_DIR" && git pull --ff-only
  fi
  success "✓ Dotfiles repo ready."
}

# === Symlink Everything (excluding special files) ===
symlink_all_dotfiles() {
  cd "$DOTFILES_DIR" || {
    warning "! Failed to enter $DOTFILES_DIR"
    exit 1
  }

  info "🔗 Symlinking dotfiles to $HOME..."

  local excludes=(
    ".git" ".github" ".idea" ".vscode"
    "README*" "LICENSE*" "*.md" "*.txt"
    "*.bak" "*.old" "*.tmp"
    "bootstrap.sh" "backup" "examples"
  )

  for item in * .*; do
    [[ "$item" == "." || "$item" == ".." ]] && continue
    for pattern in "${excludes[@]}"; do
      [[ "$item" == $pattern ]] && continue 2
    done

    local src="$DOTFILES_DIR/$item"
    local dest="$HOME/$item"

    if [[ -e "$dest" && ! -L "$dest" ]]; then
      warning "‼ Conflict: $dest exists"
      if confirm "Backup and replace?"; then
        mv "$dest" "${dest}.bak"
        info "Backed up to ${dest}.bak"
      else
        info "↷ Skipping $item"
        continue
      fi
    fi

    ln -snf "$src" "$dest" && success "✓ Linked: $item → $dest"
  done
}

set_zsh_as_default() {
  # Verify Zsh is installed
  if ! command -v zsh >/dev/null; then
    echo "Error: zsh is not installed." >&2
    [[ "$OSTYPE" == "linux-gnu"* ]] && echo "Install with: sudo apt install zsh" >&2
    [[ "$OSTYPE" == "darwin"* ]] && echo "Install with: brew install zsh" >&2
    return 1
  fi

  # Get Zsh path (different locations on different systems)
  local zsh_path
  zsh_path=$(command -v zsh)

  # Linux (Ubuntu/Debian)
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if ! grep -q "$zsh_path" /etc/shells; then
      echo "Adding zsh to /etc/shells..."
      echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    fi
    chsh -s "$zsh_path"

  # macOS
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    if ! grep -q "$zsh_path" /etc/shells; then
      echo "Adding zsh to /etc/shells..."
      sudo sh -c "echo '$zsh_path' >> /etc/shells"
    fi
    chsh -s "$zsh_path"

  else
    echo "Unsupported OS: $OSTYPE" >&2
    return 1
  fi

  echo "Success! Default shell set to: $zsh_path"
  echo "Note: This change will take effect in new terminal sessions."
}

# === Main ===
main() {
  info "Starting dotfiles setup..."
  check_os || {
    warning "Unsupported OS"
    return 1
  }

  install_required_dependencies || return 1
  sync_dotfiles_repo
  symlink_all_dotfiles
  load_topics

  set_zsh_as_default

  success "All operations completed!"
  info "Recommended: log out and back in for changes to take effect."
}

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -e
  [[ "$(id -u)" -ne 0 ]] && info "Some steps may require sudo access"
  main "$@"
fi
