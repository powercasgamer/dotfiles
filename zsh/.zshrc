#!/usr/bin/env zsh

# Load zinit
if [[ ! -f $HOME/.zinit/bin/zinit.zsh ]]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"
fi

source "$HOME/.zinit/bin/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Your zinit plugins would go here
# Example:
# zinit light zsh-users/zsh-autosuggestions
# zinit light zdharma-continuum/fast-syntax-highlighting

[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local