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
  local common_packages=("git" "curl" "wget" "zip" "unzip" "tar")
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

# === Optional: Load per-topic logic ===
load_topics() {
  local zsh_base="$DOTFILES_DIR/zsh"
  local topics_dir="$zsh_base/topics"

  info "⚙️ Setting up ZSH..."

  # Run top-level install.sh
  if [[ -f "$zsh_base/install.sh" ]]; then
    info "→ Running base zsh/install.sh"
    (cd "$zsh_base" && bash ./install.sh)
  else
    warning "⚠ No install.sh found in zsh/"
  fi

  if [[ ! -d "$topics_dir" ]]; then
    warning "⚠ No topics directory found at $topics_dir"
    return
  fi

  info "📦 Loading ZSH topics from $topics_dir..."

  for topic in "$topics_dir"/*; do
    [[ -d "$topic" ]] || continue
    local topic_name
    topic_name=$(basename "$topic")

    # Skip if .disabled is present
    if [[ -f "$topic/.disabled" ]]; then
      info "↷ Skipping disabled topic: $topic_name"
      continue
    fi

    info "→ Installing topic: $topic_name"

    # Run install.sh if present
    if [[ -f "$topic/install.sh" ]]; then
      (cd "$topic" && bash ./install.sh)
    else
      info "   No install.sh found for $topic_name, continuing..."
    fi

    # Copy .zsh files into a common autoloadable directory (optional)
    # For now, just info — you'll source them in your .zshrc
    for zsh_file in "$topic"/*.zsh; do
      if [[ -f "$zsh_file" ]]; then
        info "   Found ZSH config: $(basename "$zsh_file")"
        # You can collect paths or source them here if you want to
      fi
    done
  done
}

# === Prompt Helper ===
confirm() {
  tput setaf 3
  echo -n "$1 (y/N): "
  tput sgr0
  read -r ans
  [[ "$ans" =~ ^[Yy]([Ee][Ss])?$ ]]
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

  success "All operations completed!"
  info "Recommended: log out and back in for changes to take effect."
}

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -e
  [[ "$(id -u)" -ne 0 ]] && info "Some steps may require sudo access"
  main "$@"
fi
