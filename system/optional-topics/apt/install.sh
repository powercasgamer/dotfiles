#!/usr/bin/env bash
# apt-wrapper-symlinker.sh - System-wide completions
set -euo pipefail

DOTFILES_ROOT="/usr/local/share/dotfiles-system"
source "${DOTFILES_ROOT}/system/scripts/scripts.sh" 2>/dev/null || {
  echo "Error: Failed to load script utilities" >&2
  exit 1
}

# Configuration
SYSTEM_BIN_SOURCE="$DOTFILES_ROOT/bin"
GLOBAL_BIN_TARGET="/usr/local/bin"
WRAPPER_NAME="apt-secure"

# Standard completion locations
BASH_COMPLETION_DIR="/etc/bash_completion.d"
ZSH_COMPLETION_DIR="/usr/share/zsh/site-functions"

function create_apt_wrappers() {
    # Verify wrapper exists
    if [[ ! -x "$SYSTEM_BIN_SOURCE/$WRAPPER_NAME" ]]; then
        echo >&2 "❌ Error: $WRAPPER_NAME not found in $SYSTEM_BIN_SOURCE or not executable"
        return 1
    fi

    # Create symlinks for binaries
    echo "🔗 Creating symlinks in $GLOBAL_BIN_TARGET:"
    for cmd in apt apt-get apt-cache; do
        sudo ln -vsf "$SYSTEM_BIN_SOURCE/$WRAPPER_NAME" "$GLOBAL_BIN_TARGET/$cmd" || {
            echo >&2 "⚠️ Failed to create symlink for $cmd"
            return 1
        }
    done

    # Install bash completions
    echo "📝 Installing bash completions..."
    sudo tee "$BASH_COMPLETION_DIR/$WRAPPER_NAME" >/dev/null <<'EOF'
_complete_apt_secure() {
    local bin="${COMP_WORDS[0]}"
    case "$bin" in
        apt) COMPREPLY=($(compgen -W "$(apt help 2>/dev/null | awk '/^  [a-z]/ {print $1}')" -- "${COMP_WORDS[COMP_CWORD]}")) ;;
        apt-get) COMPREPLY=($(compgen -W "$(apt-get help 2>/dev/null | awk '/^  [a-z]/ {print $1}')" -- "${COMP_WORDS[COMP_CWORD]}")) ;;
        apt-cache) COMPREPLY=($(compgen -W "$(apt-cache help 2>/dev/null | awk '/^  [a-z]/ {print $1}')" -- "${COMP_WORDS[COMP_CWORD]}")) ;;
    esac
}
complete -F _complete_apt_secure apt apt-get apt-cache
EOF

    # Install zsh completions
    echo "📝 Installing zsh completions..."
    sudo tee "$ZSH_COMPLETION_DIR/_$WRAPPER_NAME" >/dev/null <<'EOF'
#compdef apt apt-get apt-cache
_apt_secure() {
    local curcontext="$curcontext" state line
    case "$service" in
        apt) _apt ;;
        apt-get) _apt_get ;;
        apt-cache) _apt_cache ;;
    esac
}
EOF
    sudo zcompile "$ZSH_COMPLETION_DIR/_$WRAPPER_NAME"

    # Output summary
    echo -e "\n✅ Installation complete:"
    echo -e "📌 Wrapper: \t$SYSTEM_BIN_SOURCE/$WRAPPER_NAME"
    echo -e "🔗 Symlinks: \t$(ls -1 $GLOBAL_BIN_TARGET/{apt,apt-get,apt-cache} | paste -sd ' ' -)"
    echo -e "📂 Completions installed to system directories:"
    echo -e "  - Bash: $BASH_COMPLETION_DIR/$WRAPPER_NAME"
    echo -e "  - Zsh:  $ZSH_COMPLETION_DIR/_$WRAPPER_NAME"
    echo -e "\n💡 Completions will load automatically in new shells"
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    create_apt_wrappers
fi