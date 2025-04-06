#!/usr/bin/env bash

# Install zsh if it's not installed
if ! command -v zsh &>/dev/null; then
    echo "🔧 Installing Zsh..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt install -y zsh
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if ! command -v brew &>/dev/null; then
            echo "❌ Homebrew not found. Please install Homebrew first."
            exit 1
        fi
        brew install zsh
    fi
fi

# Set zsh as default shell if it's not already
if [[ "$SHELL" != "$(command -v zsh)" ]]; then
    echo "⚙️ Changing default shell to Zsh..."
    chsh -s "$(command -v zsh)"
else
    echo "✅ Zsh is already the default shell."
fi
