#!/usr/bin/env bash
# Python Installer (APT-based)
set -euo pipefail

# Load logging utilities
DOTFILES_ROOT="/usr/local/share/dotfiles-system"
source "${DOTFILES_ROOT}/system/scripts/logging.sh"

# ==================== VERSION MANAGEMENT ====================
function get_available_python_versions() {
  apt-cache policy python3.* | \
    grep -oP 'python3\.[0-9]+' | \
    sort -V | uniq | grep -v 'python3\.[0-9]\+-config$'
}

function get_latest_apt_python_version() {
  get_available_python_versions | tail -1
}

function get_installed_python_versions() {
  dpkg -l python3.* | \
    grep '^ii' | \
    awk '{print $2}' | \
    grep -oP 'python3\.[0-9]+' | \
    sort -V | uniq
}

# ==================== INSTALLATION ====================
function install_with_apt() {
  local version="$1"

  step "Installing Python ${version} via APT"
  apt update
  apt install -y \
    "${version}" \
    "${version}-venv" \
    "${version}-dev" \
    "${version}-pip"

  # Ensure pip is updated
  "${version}" -m pip install --upgrade pip

  success "Python ${version} installed via APT"
}

# ==================== VERSION CLEANUP ====================
function remove_old_version() {
  local old_version="$1"

  if confirm "Remove Python ${old_version} and its packages?"; then
    step "Removing Python ${old_version}"

    # Find all related packages
    local related_pkgs=$(apt list --installed 2>/dev/null | \
      grep -oP "^${old_version}\S*" | \
      tr '\n' ' ')

    if [[ -n "$related_pkgs" ]]; then
      apt remove -y --purge $related_pkgs
      apt autoremove -y
      success "Removed: $related_pkgs"
    else
      info "No packages found for ${old_version}"
    fi
  else
    info "Keeping Python ${old_version}"
  fi
}

# ==================== MAIN LOGIC ====================
function main() {
  local latest_version
  latest_version=$(get_latest_apt_python_version)
  local installed_versions
  installed_versions=$(get_installed_python_versions)

  info "Latest available Python version: ${latest_version}"
  info "Installed versions: ${installed_versions:-None}"

  # Check if latest is already installed
  if [[ " ${installed_versions[*]} " =~ " ${latest_version} " ]]; then
    success "Latest Python (${latest_version}) is already installed"
    exit 0
  fi

  install_with_apt "${latest_version}"

  # Optionally remove older versions
  for ver in ${installed_versions}; do
    if [[ "${ver}" != "${latest_version}" ]]; then
      if [[ $(echo -e "${ver}\n${latest_version}" | sort -V | head -n1) == "${ver}" ]]; then
        remove_old_version "${ver}"
      fi
    fi
  done

  # Set default python3 symlink (non-destructive)
  if [[ ! -f "/usr/bin/python3" ]]; then
    sudo ln -s "/usr/bin/${latest_version}" /usr/bin/python3
  fi

  success "Python installation complete!"
  info "Usage:"
  echo -e "  ${latest_version} -V"
  echo -e "  ${latest_version} -m pip --version"
}

main "$@"