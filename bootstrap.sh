#!/bin/bash

# Color and formatting functions
function info() {
  tput setaf 4
  echo -n "$@"
  tput sgr0
}

function warning() {
  tput setaf 3
  tput bold
  echo -n "$@"
  tput sgr0
  sleep 0.5
}

function success() {
  tput setaf 2
  echo -n "$@"
  tput sgr0
}

function code() {
  tput dim
  echo -n "$@"
  tput sgr0
}

# Package installation helper
function install() {
  local package=$1
  local install_cmd=$2
  
  if ! command -v "$package" &>/dev/null; then
    info "Installing $package...\n"
    if ! eval "$install_cmd"; then
      warning "Failed to install $package\n"
      return 1
    fi
    success "$package installed successfully\n"
  else
    success "$package is already installed\n"
  fi
}

# OS detection
function check_os() {
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    case "$ID" in
      ubuntu|debian)
        echo "ubuntu/debian"
        return 0
        ;;
    esac
  fi

  if [[ "$(uname -s)" == "Darwin" ]]; then
    if [[ "$(uname -m)" == "arm64" ]]; then
      echo "macos-arm64"
      return 0
    fi
  fi

  warning "Unsupported operating system\n"
  return 1
}

# System update function
function update_system() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    warning "Skipping system update - Linux only function\n"
    return 1
  fi

  apt_cleanup

  # Carefully remove orphans while protecting drivers
  info "Cleaning orphaned packages (carefully)...\n"
  if command -v deborphan &>/dev/null; then
    deborphan | grep -v -E 'amdgpu|intel-microcode|nvidia|libnvidia|glx|mesa|vulkan|wayland|xserver|firmware|systemd' |
      xargs --no-run-if-empty sudo apt purge -y
  else
    warning "deborphan not installed, skipping orphaned package cleanup\n"
  fi

  success "System update completed!\n"
  return 0
}

# Dependency installation
function install_required_dependencies() {
  local common_packages=("git", "curl", "wget", "zip", "unzip", "tar")
  local os_type=$(check_os)

  case "$os_type" in
    "ubuntu/debian")
      info "Installing Linux dependencies...\n"
      
      # Update package lists first
      sudo apt update -qy
      
      # Install base packages
      sudo apt install -y "${common_packages[@]}"

      # Install apt HTTPS support if missing
      if ! dpkg -s apt-transport-https &>/dev/null; then
        info "Installing apt HTTPS support...\n"
        sudo apt install -y --no-install-recommends \
          apt-transport-https \
          ca-certificates \
          software-properties-common \
          gnupg
      fi

      remove_snap_if_installed
      ;;

    "macos-arm64")
      info "Checking for macOS dependencies...\n"
      
      # Install Homebrew if missing
      if ! command -v brew &>/dev/null; then
        warning "Homebrew not found. Installing...\n"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add to PATH for Apple Silicon
        if [[ "$(uname -m)" == "arm64" ]]; then
          echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
          eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
      fi

      brew install "${common_packages[@]}" cmake python
      ;;
      
    *)
      warning "Unsupported OS. Skipping dependency installation.\n"
      return 1
      ;;
  esac

  success "Dependencies installed successfully!\n"
  return 0
}

# Snap removal function
function remove_snap_if_installed() {
  if ! command -v snap &>/dev/null; then
    return 0
  fi

  info "Removing Snap...\n"
  
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
    warning "Skipping APT cleanup - Ubuntu/Debian only\n"
    return 1
  fi

  info "Starting APT maintenance...\n"
  
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

  success "APT maintenance completed!\n"
  return 0
}

# Kernel cleanup
function clean_old_kernels() {
  local keep_kernels=2

  info "Cleaning old kernels (keeping $keep_kernels)...\n"
  
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

function main() {
    info "Starting system setup...\n"
    
    # Detect OS first
    local os_type
    os_type=$(check_os)
    if [[ $? -ne 0 ]]; then
        warning "Exiting due to unsupported OS\n"
        return 1
    fi

    # Install core dependencies
    install_required_dependencies
    if [[ $? -ne 0 ]]; then
        warning "Dependency installation failed\n"
        return 1
    fi

    # Linux-specific operations
    if [[ "$os_type" == "ubuntu/debian" ]]; then
        # Confirm before destructive actions
        if confirm "Run system update and cleanup? (recommended)"; then
            update_system
            clean_old_kernels
        fi

        if confirm "Remove Snap if present? (optional)"; then
            remove_snap_if_installed
        fi
    fi

    success "\nAll operations completed!\n"
    info "Recommended next steps:\n"
    code "  - Log out and back in for changes to take effect\n"
}

# Helper function for user confirmation
function confirm() {
    local message="$1 (y/N) "
    tput setaf 3
    echo -n "$message"
    tput sgr0
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Only execute main if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Ensure script exits on errors
    set -e
    
    # Check for sudo privileges early
    if [[ "$(id -u)" -ne 0 ]] && [[ "$(uname -s)" == "Linux" ]]; then
        info "Some operations require sudo. You may be prompted for your password.\n"
    fi

    main "$@"
fi