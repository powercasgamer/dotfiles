#!/bin/bash

# === Visual functions ===
info() {
  tput setaf 4
  echo "[SYSTEM] $@"
  tput sgr0
}
warning() {
  tput setaf 3
  tput bold
  echo "[SYSTEM] $@"
  tput sgr0
  sleep 0.5
}
success() {
  tput setaf 2
  echo "[SYSTEM] $@"
  tput sgr0
}

# === Environment Setup ===
DOTFILES_REPO="https://github.com/powercasgamer/dotfiles.git"
DOTFILES_SYSTEM_DIR="/usr/local/share/dotfiles-system"
SYSTEM_CONFIG_DIR="$DOTFILES_SYSTEM_DIR/system"  # Where system configs will be stored
SYSTEM_BIN_SOURCE="$DOTFILES_SYSTEM_DIR/bin"
GLOBAL_BIN_TARGET="/usr/local/bin"  # System-wide binary location
TOPICS_DIR="$SYSTEM_CONFIG_DIR/topics"
OPTIONAL_TOPICS_DIR="$SYSTEM_CONFIG_DIR/optional-topics"

# === Runtime Options ===
VERBOSE=false
DRY_RUN=false
FORCE=false
PARALLEL=false

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
  else
    warning "Unsupported operating system: $(uname -s) ($os_arch)"
    return 1
  fi
}

# === Clone Dotfiles ===
clone_dotfiles() {
  info "Cloning dotfiles repository..."

  if [[ ! -d "$DOTFILES_SYSTEM_DIR" ]]; then
    sudo git clone "$DOTFILES_REPO" "$DOTFILES_SYSTEM_DIR"
    sudo chmod 755 "$DOTFILES_SYSTEM_DIR"
  else
    info "Updating existing dotfiles..."
    sudo git -C "$DOTFILES_SYSTEM_DIR" pull
  fi

  # Verify system folder exists
  if [[ ! -d "$DOTFILES_SYSTEM_DIR/system" ]]; then
    warning "No 'system' folder found in dotfiles repository!"
    return 1
  fi

  success "Dotfiles repository ready at $DOTFILES_SYSTEM_DIR"
}

# === Requirement Checking ===
check_requirements() {
  local requirement_file="$1"
  while read -r req; do
    # Skip comments and empty lines
    [[ "$req" =~ ^#.*$ || -z "$req" ]] && continue

    # Check command availability
    if ! command -v "$req" &>/dev/null; then
      warning "Missing requirement: $req"
      return 1
    fi
  done < "$requirement_file"
  return 0
}

# === Install Global Zsh Config ===
install_global_zsh() {
  local system_zshrc="$DOTFILES_SYSTEM_DIR/system/zshrc.global"
  local global_zshrc="/etc/zsh/zshrc"

  info "Installing global Zsh configuration..."

  # Check if global config exists in dotfiles
  if [[ ! -f "$system_zshrc" ]]; then
    warning "No global zshrc found at $system_zshrc"
    return 1
  fi

  # Backup existing config if it exists
  if [[ -f "$global_zshrc" ]]; then
    sudo mv "$global_zshrc" "${global_zshrc}.bak"
    info "Backed up existing config to ${global_zshrc}.bak"
  fi

  # Install new config
  sudo cp "$system_zshrc" "$global_zshrc"
  sudo chmod 644 "$global_zshrc"

  success "Global Zsh configuration installed at $global_zshrc"
}

# === Run Installation Hook ===
run_hook() {
  local hook_type="$1"  # "install.sh" or "post-install.sh"
  local topic_dir="$2"
  local topic_name="$3"

  local hook_file="$topic_dir/$hook_type.sh"

  [[ ! -f "$hook_file" ]] && return 0  # No hook exists

  info "   🪝 Running $hook_type hook for: $topic_name"

  (
    cd "$topic_dir"
    if [[ "$VERBOSE" == true ]]; then
      if ! bash -x "$hook_file"; then
        warning "   ⚠ $hook_type hook failed for: $topic_name"
        exit 1
      fi
    else
      if ! bash "$hook_file"; then
        warning "   ⚠ $hook_type hook failed for: $topic_name"
        exit 1
      fi
    fi
    exit 0
  )

  return $?
}

# === Install System Binaries ===
install_system_binaries() {
  info "Deploying system binaries..."

  # Verify source directory exists
  if [[ ! -d "$SYSTEM_BIN_SOURCE" ]]; then
    warning "No system/bin directory found in dotfiles!"
    return 1
  fi

  # Ensure target directory exists
  sudo mkdir -p "$GLOBAL_BIN_TARGET"

  # Symlink each executable
  for script in "$SYSTEM_BIN_SOURCE"/*; do
    local script_name=$(basename "$script")
    local target="$GLOBAL_BIN_TARGET/$script_name"

    # Skip directories and non-executable files
    [[ ! -f "$script" || ! -x "$script" ]] && continue

    # Backup existing binaries
    if [[ -e "$target" ]]; then
      sudo mv "$target" "${target}.bak"
      info "Backed up existing: $script_name → ${target}.bak"
    fi

    # Create symlink
    sudo ln -sf "$script" "$target"
    sudo chmod +x "$target"
    success "Linked: $script_name → $target"
  done

  # Refresh PATH (for current session)
  hash -r
}

# === Topic Installer ===
install_topics() {
  info "🔍 Discovering system topics..."

  [[ ! -d "$TOPICS_DIR" ]] && { warning "No topics directory found"; return 1; }

  # Define explicit installation order (modify as needed)
  local priority_order=("system" "essential" "zsh")
  local installed=0 skipped=0 failed=0
  local -a topic_queue=() remaining_topics=()

  # Build processing queues
  while IFS= read -r -d '' installer; do
    local topic_dir=$(dirname "$installer")
    local topic_name=$(basename "$topic_dir")

    # Check if topic is in priority list
    local is_priority=false
    for prio_topic in "${priority_order[@]}"; do
      if [[ "$topic_name" == "$prio_topic" ]]; then
        is_priority=true
        break
      fi
    done

    if $is_priority; then
      # Add to priority queue (will be sorted later)
      topic_queue+=("$installer")
    else
      # Add to regular queue
      remaining_topics+=("$installer")
    fi
  done < <(find "$TOPICS_DIR" -maxdepth 2 -name 'install.sh' -print0)

  # Sort priority topics according to defined order
  local -a sorted_queue=()
  for prio_topic in "${priority_order[@]}"; do
    for installer in "${topic_queue[@]}"; do
      if [[ "$(basename "$(dirname "$installer")")" == "$prio_topic" ]]; then
        sorted_queue+=("$installer")
      fi
    done
  done

  # Combine queues (priority topics first)
  topic_queue=("${sorted_queue[@]}" "${remaining_topics[@]}")

  info "📦 Found ${#topic_queue[@]} topics to process (${#sorted_queue[@]} priority topics)"

  for installer in "${topic_queue[@]}"; do
    local topic_dir=$(dirname "$installer")
    local topic_name=$(basename "$topic_dir")

    # Check requirements
    if [[ -f "$topic_dir/.requires" ]]; then
      if ! check_requirements "$topic_dir/.requires"; then
        warning "⏩ Skipping $topic_name (missing requirements)"
        ((skipped++))
        continue
      fi
    fi

    info "🏷️  Processing: $topic_name"

    if [[ "$DRY_RUN" == true ]]; then
      echo "   [DRY RUN] Would execute: $installer"
      [[ -f "$topic_dir/post-install.sh" ]] && \
        echo "   [DRY RUN] Would run post-install hook"
      ((skipped++))
      continue
    fi

    # Run install.sh hook
    if ! run_hook "install" "$topic_dir" "$topic_name"; then
      [[ "$FORCE" == true ]] && ((skipped++)) || ((failed++))
      continue
    fi

    # Run post-install.sh hook if exists
    if ! run_hook "post-install" "$topic_dir" "$topic_name"; then
      [[ "$FORCE" == true ]] && ((skipped++)) || ((failed++))
      continue
    fi

    success "   ✅ Successfully processed: $topic_name"
    ((installed++))
  done

  # Print summary
  echo ""
  success "📊 Processing Summary:"
  echo "   - ✅ $installed succeeded"
  echo "   - ⏩ $skipped skipped"
  [[ $failed -gt 0 ]] && warning "   - ❌ $failed failed"
  echo "   - Priority order: ${priority_order[*]}"

  [[ $failed -gt 0 && "$FORCE" != true ]] && return 1
  return 0
}

# === Optional Topic Installer ===
install_optional_topics() {
  info "🔍 Discovering optional system topics..."

  [[ ! -d "$OPTIONAL_TOPICS" ]] && { warning "No optional topics directory found"; return 1; }

  local installed=0 skipped=0 failed=0
  local -a topic_queue=()

  # Build processing queue
  while IFS= read -r -d '' installer; do
    topic_queue+=("$installer")
  done < <(find "$OPTIONAL_TOPICS" -maxdepth 2 -name 'install.sh' -print0)

  info "📦 Found ${#topic_queue[@]} topics to process"

  for installer in "${topic_queue[@]}"; do
    local topic_dir=$(dirname "$installer")
    local topic_name=$(basename "$topic_dir")

    # Check requirements
    if [[ -f "$topic_dir/.requires" ]]; then
      if ! check_requirements "$topic_dir/.requires"; then
        warning "⏩ Skipping $topic_name (missing requirements)"
        ((skipped++))
        continue
      fi
    fi

    info "🏷️  Processing: $topic_name"

    if [[ "$DRY_RUN" == true ]]; then
      echo "   [DRY RUN] Would execute: $installer"
      [[ -f "$topic_dir/post-install.sh" ]] && \
        echo "   [DRY RUN] Would run post-install hook"
      ((skipped++))
      continue
    fi

    # Run install.sh hook
    if ! run_hook "install" "$topic_dir" "$topic_name"; then
      [[ "$FORCE" == true ]] && ((skipped++)) || ((failed++))
      continue
    fi

    # Run post-install.sh hook if exists
    if ! run_hook "post-install" "$topic_dir" "$topic_name"; then
      [[ "$FORCE" == true ]] && ((skipped++)) || ((failed++))
      continue
    fi

    success "   ✅ Successfully processed: $topic_name"
    ((installed++))
  done

  # Print summary
  echo ""
  success "📊 Processing Summary:"
  echo "   - ✅ $installed succeeded"
  echo "   - ⏩ $skipped skipped"
  [[ $failed -gt 0 ]] && warning "   - ❌ $failed failed"

  [[ $failed -gt 0 && "$FORCE" != true ]] && return 1
  return 0
}

# === Main ===
main() {
  # Parse arguments
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -v|--verbose) VERBOSE=true ;;
        -d|--dry-run) DRY_RUN=true ;;
        -f|--force) FORCE=true ;;
        -p|--parallel) PARALLEL=true ;;
        *) warning "Unknown option: $1"; exit 1 ;;
      esac
      shift
    done

  # Verify root
  if [[ "$(id -u)" -ne 0 ]]; then
    warning "This script requires root privileges. Restarting with sudo..."
    exec sudo "$0" "$@"
  fi

  info "Starting system-wide dotfiles installation..."

  clone_dotfiles || {
    warning "Failed to setup dotfiles repository"
    exit 1
  }

  install_topics || {
      [[ "$FORCE" != true ]] && exit 1
  }

#  install_optional_topics || {
#    [[ "$FORCE" != true ]] && exit 1
#  }

  install_global_zsh || {
    warning "Failed to install global Zsh config"
    exit 1
  }

  # Install system binaries
  install_system_binaries || {
    warning "System binary deployment had issues"
    # Continue anyway as this isn't critical
  }

  success "System setup complete!"
  echo "Global Zsh config is now active for all users"
  echo "Users can still override with their own ~/.zshrc"
}

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -eo pipefail
  main "$@"
fi