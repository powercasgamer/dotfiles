#!/usr/bin/env zsh

# Enable Powerlevel10k instant prompt (must be at the top of ~/.zshrc)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Initialize Zinit plugin manager
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Fix history settings (MUST come before plugins)
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt EXTENDED_HISTORY    # Save timestamps
setopt SHARE_HISTORY      # Share history across sessions
setopt HIST_IGNORE_SPACE  # Don't save commands starting with space

# Load history-substring-search with GUARANTEED key bindings
zinit ice atload"
    bindkey '^[[A' history-substring-search-up;
    bindkey '^[[B' history-substring-search-down;
    bindkey '^[OA' history-substring-search-up;
    bindkey '^[OB' history-substring-search-down
"
zinit light zsh-users/zsh-history-substring-search

# Load Plugins
zinit light zsh-users/zsh-autosuggestions

zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions

# Initialize completions
autoload -Uz compinit && compinit

# Load Snippets
zinit snippet OMZL::clipboard.zsh     # Clipboard integration
zinit snippet OMZL::termsupport.zsh   # Terminal window/tab title support

# Load Powerlevel10k theme
zinit ice depth"1"  # Shallow clone for faster install
zinit light romkatv/powerlevel10k

# Configure LS_COLORS (better `ls` colors)
zinit ice as"program" \
    atclone"dircolors -b LS_COLORS >! clrs.zsh" \
    atpull"%atclone" \
    pick"clrs.zsh" \
    nocompile'!' \
    atload'zstyle ":completion:*" list-colors "${(s.:.)LS_COLORS}"'
zinit light trapd00r/LS_COLORS

# Load Powerlevel10k config (run `p10k configure` to customize)
if [[ -f ~/.p10k.zsh ]]; then
  source ~/.p10k.zsh
fi

# ===== ZSH Topic Loader =====
load_zsh_topics() {
  local zsh_topics_dir="$DOTFILES_DIR/zsh/topics"
  
  # Initialize base fpath
  fpath=(
    ~/.zsh/completions
    ${ZDOTDIR:-~}/.zinit/completions(N/)
    ${fpath}
  )

  [[ -d "$zsh_topics_dir" ]] || return

  echo "📦 Loading ZSH topics..."
  for topic_dir in "$zsh_topics_dir"/*(N/); do
    [[ -f "$topic_dir/.disabled" ]] && continue

    # 1. First: Source completions.zsh if exists
    [[ -f "$topic_dir/completions.zsh" ]] && {
      echo "⌙ [Completions] ${topic_dir##*/}"
      source "$topic_dir/completions.zsh"
    }

    # 2. Then: Load other .zsh files
    for zsh_file in "$topic_dir"/*.zsh(N); do
      [[ "$zsh_file" == */completions.zsh ]] && continue
      source "$zsh_file"
    done
  done

  # Initialize completions once
  autoload -Uz compinit
  compinit -i -d "${ZSH_COMPDUMP:-${ZDOTDIR:-$HOME}/.zcompdump}"
}

# Run on new shells
[[ -z "$ZSH_FAST_LOAD" ]] && load_zsh_topics

# Aliases etc
# Source all .zsh files in directory
if [[ -d ~/zsh/includes ]]; then
    for file in ~/zsh/includes/*.zsh; do
        [[ -f $file ]] && source $file
    done
fi
export LS_COLORS="$LS_COLORS:ow=1;34;42"


[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
