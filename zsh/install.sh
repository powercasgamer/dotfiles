#!/bin/bash
# Install zsh if missing
if ! command -v zsh &>/dev/null; then
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt install -y zsh
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install zsh
    fi
    chsh -s $(which zsh)
fi
