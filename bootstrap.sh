#!/bin/bash

# Color and formatting functions
function info() {
  tput setaf 4 # Blue
  echo "$@"    # Removed -n to print newline
  tput sgr0    # Reset
}

function warning() {
  tput setaf 3 # Yellow
  tput bold    # Bold
  echo "$@"    # Removed -n
  tput sgr0    # Reset
  sleep 0.5
}

function success() {
  tput setaf 2 # Green
  echo "$@"    # Removed -n
  tput sgr0    # Reset
}

function code() {
  tput dim  # Dim text
  echo "$@" # Removed -n
  tput sgr0 # Reset
}

DOTFILES_DIR="$HOME/dotfiles"

# Package installation helper
function install() {
  local package=$1
  local install_cmd=$2

  if ! command -v "$package" &>/dev/null; then
    info "Installing $package..."
    if ! eval "$install_cmd"; then
      warning "Failed to install $package"
      return 1
    fi
    success "$package installed successfully"
  else
    success "$package is already installed"
  fi
}

# OS detection
function check_os() {
  local os_type=""
  local os_family=""
  local os_arch=""

  # Detect architecture
  os_arch=$(uname -m) # x86_64, arm64, etc.

  # Check for /etc/os-release (Linux)
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    case "$ID" in
    ubuntu | debian | pop | linuxmint | raspbian | kali | neon | elementary | zorin)
      os_family="debian"
      ;;
    fedora | centos | rhel | almalinux | rocky | ol)
      os_family="rhel"
      ;;
    arch | manjaro | endeavouros)
      os_family="arch"
      ;;
    *)
      os_family="unknown-linux"
      ;;
    esac
    os_type="${os_family}-${os_arch}"

  # Check for macOS
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    os_type="macos-${os_arch}"

  # Check for BSD
  elif [[ "$(uname -s)" =~ BSD ]]; then
    os_type="bsd-${os_arch}"

  # Check for Windows Subsystem for Linux (WSL)
  elif [[ -n "$WSL_DISTRO_NAME" ]]; then
    os_type="wsl-${os_arch}"
  fi

  info "${os_type}"

  # Validate detection
  if [[ -z "$os_type" ]]; then
    warning "Unsupported operating system: $(uname -s) (${os_arch})"
    return 1
  fi

  echo "$os_type"
  return 0
}

# System update function
function update_system() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    warning "Skipping system update - Linux only function"
    return 1
  fi

  apt_cleanup

  # Carefully remove orphans while protecting drivers
  if confirm "Remove orphaned packages (risky)?"; then
    if command -v deborphan &>/dev/null; then
      deborphan | grep -v -E 'amdgpu|intel-microcode|nvidia|libnvidia|glx|mesa|vulkan|wayland|xserver|firmware|systemd' |
        xargs --no-run-if-empty sudo apt purge -y
    else
      warning "deborphan not installed, skipping orphaned package cleanup"
    fi
  fi

  success "System update completed!"
  return 0
}

function install_required_dependencies() {
  local common_packages=("git" "curl" "wget" "zip" "unzip" "tar" "stow")
  local os_type=$(check_os)

  # Debug output to verify what check_os returns
  echo "DEBUG: Detected OS type: '$os_type'" >&2

  case "$os_type" in
  *debian* | *ubuntu* | *pop* | *linuxmint* | *raspbian*)
    info "Installing Linux dependencies..."

    # Update package lists first
    sudo apt update -qy

    # Install apt HTTPS support if missing
    if ! dpkg -s apt-transport-https &>/dev/null; then
      info "Installing apt HTTPS support..."
      sudo apt -o DPkg::Lock::Timeout=60 install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        software-properties-common \
        gnupg
    fi

    # Install base packages
    sudo apt -o DPkg::Lock::Timeout=60 install -y "${common_packages[@]}"

    remove_snap_if_installed
    ;;

  *macos*)
    info "Checking for macOS dependencies..."
    # [Previous macOS content here]
    ;;

  *)
    warning "Unsupported OS: $os_type. Skipping dependency installation."
    return 1
    ;;
  esac

  success "Dependencies installed successfully!"
  return 0
}

# Snap removal function
function remove_snap_if_installed() {
  if ! command -v snap &>/dev/null; then
    return 0
  fi

  info "Removing Snap..."

  # Uninstall all snap packages
  if [[ $(snap list | wc -l) -gt 1 ]]; then
    for pkg in $(snap list | awk 'NR>1 {print $1}'); do
      sudo snap remove --purge "$pkg"
    done
  fi

  # Remove snapd completely
  sudo apt purge -y snapd gnome-software-plugin-snap

  # Clean up
  sudo rm -rf /var/cache/snapd/
  rm -rf ~/snap
  sudo apt-mark hold snapd

  # Install flatpak alternative
  if ! command -v flatpak &>/dev/null; then
    sudo apt install -y flatpak
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi
}

# APT maintenance
function apt_cleanup() {
  if ! grep -qi 'ubuntu\|debian' /etc/os-release; then
    warning "Skipping APT cleanup - Ubuntu/Debian only"
    return 1
  fi

  info "Starting APT maintenance..."

  # Update and upgrade
  sudo apt update -qy
  sudo apt upgrade -qy
  sudo apt full-upgrade -qy

  # Cleanup
  sudo apt autoremove -qy --purge
  sudo apt autoclean
  sudo apt clean

  # Remove old kernels (keep 2 latest)
  clean_old_kernels

  # Reconfigure any pending packages
  sudo dpkg --configure -a

  success "APT maintenance completed!"
  return 0
}

# Kernel cleanup
function clean_old_kernels() {
  local keep_kernels=2

  info "Cleaning old kernels (keeping $keep_kernels)..."

  # Remove old kernel packages
  sudo apt purge -y $(
    dpkg -l |
      awk '/^ii linux-(image|headers|modules)-[0-9]+\./{print $2}' |
      sort -V |
      grep -v "$(uname -r | cut -d- -f1-2)" |
      head -n -"$keep_kernels"
  )

  # Clean up /boot files
  ls /boot | grep -E 'vmlinuz-|initrd.img-' |
    sort -V |
    grep -v "$(uname -r | cut -d- -f1-2)" |
    head -n -"$keep_kernels" |
    while read -r file; do
      sudo rm -f "/boot/$file"
    done

  # Update GRUB if available
  if command -v update-grub &>/dev/null; then
    sudo update-grub
  fi
}

# Example Directory Structure:
# .
# ├── zsh/
# │   ├── install.sh
# │   ├── aliases.zsh
# │   └── path.zsh
# ├── git/
# │   ├── install.sh
# │   └── aliases.zsh
# └── python/
#     ├── install.sh
#     └── path.zsh

function main() {
  info "Starting system setup..."

  # Detect OS first
  local os_type
  os_type=$(check_os)
  if [[ $? -ne 0 ]]; then
    warning "Exiting due to unsupported OS"
    return 1
  fi

  # Install core dependencies
  install_required_dependencies
  if [[ $? -ne 0 ]]; then
    warning "Dependency installation failed"
    return 1
  fi

  # Linux-specific operations
  if [[ "$os_type" == "debian-*" ]]; then
    # Confirm before destructive actions
    if confirm "Run system update and cleanup? (recommended)"; then
      update_system
      clean_old_kernels
    fi

    if confirm "Remove Snap if present? (optional)"; then
      remove_snap_if_installed
    fi
  fi

  if [[ ! -d "$DOTFILES_DIR" ]]; then
    info "==> Cloning dotfiles repo..."
    git clone https://github.com/powercasgamer/dotfiles.git "$DOTFILES_DIR"
  else
    info "==> Updating dotfiles repo..."
    cd "$DOTFILES_DIR" && git fetch && git pull
  fi
  success "✓ Dotfiles repo ready."

  info "==> Symlinking dotfiles..."
  cd "$DOTFILES_DIR" || {
    warn "! Failed to enter $DOTFILES_DIR"
    exit 1
  }

  # Symlink all visible directories (excluding hidden dirs and those with .nostow)
  find . -maxdepth 1 -type d -not -name '.' -not -name '.*' -print0 | while IFS= read -r -d '' dir; do
    dir_name=$(basename "$dir")
    if [[ ! -f "$dir/.nostow" ]]; then
      if stow -v "$dir_name"; then
        success "✓ Linked $dir_name"
      else
        warn "! Failed to link $dir_name"
      fi
    else
      info "↷ Skipping $dir_name (.nostow marker present)"
    fi
  done

  load_topics

  success "All operations completed!"
  info "Recommended next steps:"
  code "  - Log out and back in for changes to take effect"
}

function load_topics() {
  info "Loading topic configurations...\n"

  # Find all topic directories in current working directory
  local topics=($(find . -maxdepth 1 -type d ! -name '.*' ! -name '.' | sed 's|^\./||'))

  for topic in "${topics[@]}"; do
    info "Processing topic: $topic\n"

    # 1. Run install.sh if present
    if [[ -f "$topic/install.sh" ]]; then
      info "Running installer...\n"
      (cd "$topic" && bash ./install.sh)
    fi

    # 2. Source all .zsh files (aliases, path, etc.)
    for zsh_file in "$topic"/*.zsh; do
      (source "$zsh_file") 2>/dev/null ||
        warning "Failed to load $zsh_file"
    done

    # 3. Special handling for completions
    if [[ -f "$topic/completions.zsh" ]]; then
      fpath=("$topic" $fpath)
      autoload -Uz "$topic/completions.zsh"
    fi
  done
}

# Helper function for user confirmation
function confirm() {
  local message="$1 (y/N) "
  tput setaf 3
  echo -n "$message"
  tput sgr0
  read -r response
  [[ "$response" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# Only execute main if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Ensure script exits on errors
  set -e

  # Check for sudo privileges early
  if [[ "$(id -u)" -ne 0 ]] && [[ "$(uname -s)" == "Linux" ]]; then
    info "Some operations require sudo. You may be prompted for your password."
  fi

  main "$@"
fi
