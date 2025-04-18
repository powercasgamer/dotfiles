#!/usr/bin/env bash

# Generic project initialization utilities
# Source this script to use its functions

DOTFILES_ROOT="/usr/local/share/dotfiles-system"
SCRIPTS_ROOT="${DOTFILES_ROOT}/system/scripts"

# Source logging utilities if not already sourced
if ! command -v info &>/dev/null; then
  source "${SCRIPTS_ROOT}/logging.sh"
fi

# Ask user a question with validation
# $1: Question text
# $2: Default value (optional)
# $3: Validation regex (optional)
# $4: Error message (optional)
# Returns: User's answer
function ask() {
  local question=$1
  local default=$2
  local pattern=$3
  local err_msg=$4

  while true; do
    if [ -n "$default" ]; then
      read -rp "$(info "$question [$default]: ")" answer
      answer=${answer:-$default}
    else
      read -rp "$(info "$question: ")" answer
    fi

    if [ -z "$answer" ]; then
      warning "Value cannot be empty"
      continue
    fi

    if [ -n "$pattern" ] && [[ ! "$answer" =~ $pattern ]]; then
      warning "${err_msg:-"Invalid format"}"
      continue
    fi

    echo "$answer"
    break
  done
}

# Present a select menu to user
# $1: Prompt text
# $2..$n: Options
# Returns: Selected value (lowercase)
function select_option() {
  local prompt=$1
  shift
  local options=("$@")
  local selected

  step "$prompt"
  PS3="$(info "Choose an option (1-${#options[@]}): ")"

  select opt in "${options[@]}"; do
    if [[ -n "$opt" ]]; then
      selected=$(echo "$opt" | tr '[:upper:]' '[:lower:]')
      break
    else
      warning "Invalid selection, please try again"
    fi
  done

  echo "$selected"
}

# Replace placeholders in files with optional backups
#
# Usage: replace_placeholders <target_dir> <sed_pattern1> [<sed_pattern2>...]
#
# Options:
#   -b|--backup  Enable backup files (default: disabled)
#   -s|--suffix  Backup suffix (default: .bak)
#
# Arguments:
#   target_dir    Directory to search for files
#   sed_patternN  sed substitution patterns
#
# Example:
#   replace_placeholders -b -s ".backup" "./project" "s/{{NAME}}/ProjectX/g"

function replace_placeholders() {
    # Default settings
    local enable_backup=false
    local backup_suffix=".bak"
    local is_dry_run=false
    local sed_in_place

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b|--backup)
                enable_backup=true
                shift
                ;;
            -s|--suffix)
                backup_suffix="$2"
                shift 2
                ;;
            *)
                break
                ;;
        esac
    done

    # Get remaining arguments
    local target_dir="$1"
    shift
    local replacements=("$@")

    # Validate inputs
    [[ -d "$target_dir" ]] || {
        error "Target directory does not exist: $target_dir"
        return 1
    }

    [[ ${#replacements[@]} -gt 0 ]] || {
        warning "No replacement patterns provided"
        return 0
    }

    # Configure sed command
    if $enable_backup; then
        sed_in_place="-i$backup_suffix"
    else
        case "$(uname -s)" in
            Darwin) sed_in_place="-i ''" ;;  # MacOS
            Linux)  sed_in_place="-i" ;;     # Linux
            *)      sed_in_place="-i" ;;     # Default
        esac
    fi

    # Process files
    while IFS= read -r -d '' file; do
        # Skip existing backup files
        [[ "$file" == *"$backup_suffix" ]] && continue

        # Verify text file
        if ! file -b --mime-encoding "$file" | grep -q 'us-ascii\|utf-8'; then
            warning "Skipping non-text file: $file"
            continue
        fi

        # Apply replacements
        for pattern in "${replacements[@]}"; do
            if $is_dry_run; then
                info "DRY RUN: Would process $file with: $pattern"
            else
                if ! sed $sed_in_place "$pattern" "$file"; then
                    error "Failed processing $file with: $pattern"
                    continue
                fi
            fi
        done

        success "Processed: $file"
    done < <(find "$target_dir" -type f ! -name "*$backup_suffix" -print0)
}