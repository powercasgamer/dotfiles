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
    if ! grep -Fxq "$ZSH_PATH" /etc/shells; then
        echo "📄 Adding $ZSH_PATH to /etc/shells..."
        echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
    else
        echo "✅ $ZSH_PATH already listed in /etc/shells."
    fi
fi

# Set Zsh as default shell if it's not already
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
    echo "⚙️ Changing default shell to Zsh..."
    # Make sure the user has permission to change the shell
    if chsh -s "$ZSH_PATH"; then
        echo "✅ Default shell successfully changed to Zsh."
    else
        echo "❌ Failed to change default shell. Please check if chsh is working correctly on your system."
        exit 1
    fi
else
    echo "✅ Zsh is already the default shell."
fi

# Debug: Show current shell
echo "📝 Current shell is: $SHELL"
