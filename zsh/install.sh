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

ZSH_PATH="$(command -v zsh)"

# Add Zsh to /etc/shells if it's not listed
if [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == "darwin"* ]]; then
    if ! grep -qx "$ZSH_PATH" /etc/shells; then
        echo "📄 Adding $ZSH_PATH to /etc/shells..."
        echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
    fi
fi

# Set Zsh as default shell if it's not already
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
    echo "⚙️ Changing default shell to Zsh..."
    chsh -s "$ZSH_PATH"
else
    echo "✅ Zsh is already the default shell."
fi
