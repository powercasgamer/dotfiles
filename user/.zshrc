#!/usr/bin/env zsh
# ===== MAIN ZSH CONFIGURATION =====
# Optimized for speed, readability, and extensibility.

# --- Oh My Zsh Setup ---
# Set Oh My Zsh installation path
export ZSH="${HOME}/.oh-my-zsh"

# Theme (agnoster is popular but can be slow; alternatives: powerlevel10k, starship)
ZSH_THEME="agnoster"

# Disable magic functions if experiencing paste issues (uncomment if needed)
# DISABLE_MAGIC_FUNCTIONS="true"

# --- Plugins ---
# Note: Order matters! Syntax highlighting should be last.
plugins=(
  git               # Git aliases and shortcuts
  zsh-autosuggestions # Fish-like suggestions (install via OMZ or manual)
  zsh-syntax-highlighting  # Command syntax coloring (must be last!)
)

# Load Oh My Zsh
source "${ZSH}/oh-my-zsh.sh"

# ===== PERFORMANCE & CORE SETTINGS =====
# Speed up completions (disable if encountering issues)
zstyle ':completion:*' cache-path "${HOME}/.zsh_cache"
autoload -Uz compinit && compinit

# History settings (larger history, ignore duplicates)
HISTFILE="${HOME}/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt HIST_IGNORE_ALL_DUPS  # Skip duplicates
setopt HIST_SAVE_NO_DUPS     # Don't save duplicates
setopt INC_APPEND_HISTORY    # Append history immediately

# ===== TERMINAL ENHANCEMENTS =====
# --- Colors & Aliases ---
# Enable colors in terminal commands
if [[ -x "$(command -v dircolors)" ]]; then
  [[ -r "${HOME}/.dircolors" ]] \
    && eval "$(dircolors -b "${HOME}/.dircolors")" \
    || eval "$(dircolors -b)"
  # Colorize common commands
  alias ls='ls --color=auto'
  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
  alias diff='diff --color=auto'
fi

# Custom LS_COLORS (e.g., highlight other-writable dirs)
export LS_COLORS="${LS_COLORS}:ow=1;34;42"

# --- Key Bindings ---
# Better history navigation (requires zsh-history-substring-search plugin)
# bindkey '^[[A' history-substring-search-up
# bindkey '^[[B' history-substring-search-down
# bindkey '^[OA' history-substring-search-up
# bindkey '^[OB' history-substring-search-down

# Fix Home/End keys (for most terminals)
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

# ===== CUSTOM PATHS & TOOLS =====
# Add local bin to PATH (if it exists)
[[ -d "${HOME}/bin" ]] && export PATH="${HOME}/bin:${PATH}"

# Load local/non-versioned configs (prioritize .zshrc.local)
[[ -f "${HOME}/.zshrc.local" ]] && source "${HOME}/.zshrc.local"
[[ -f "${HOME}/.localrc" ]] && source "${HOME}/.localrc"

# ===== SUGGESTED IMPROVEMENTS =====
# Uncomment or add as needed:
# 1. Faster alternative to agnoster:
#    ZSH_THEME="powerlevel10k/powerlevel10k"  # Requires manual install
#
# 2. Python/conda support:
#    [[ -f "${HOME}/miniconda3/etc/profile.d/conda.sh" ]] && source "${HOME}/miniconda3/etc/profile.d/conda.sh"
#
# 3. Fuzzy finder (fzf) integration:
#    [[ -f "${HOME}/.fzf.zsh" ]] && source "${HOME}/.fzf.zsh"
#
# 4. Directory navigation (zoxide or autojump):
#    eval "$(zoxide init zsh)"  # `z` instead of `cd`
#
# 5. Git status in prompt (if not using agnoster):
#    autoload -Uz vcs_info && zstyle ':vcs_info:*' enable git