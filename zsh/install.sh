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

# Check if Zsh is already the default shell in the password database
CURRENT_SHELL=$(getent passwd $USER | cut -d: -f7)
if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
    echo "⚙️ Changing default shell to Zsh..."
    # Make sure the user has permission to change the shell
    if chsh -s "$ZSH_PATH"; then
        echo "✅ Default shell changed to Zsh in system database."
        echo "🔄 You'll need to log out and log back in for the change to take effect."
    else
        echo "❌ Failed to change default shell. Please check if chsh is working correctly on your system."
        exit 1
    fi
else
    echo "✅ Zsh is already set as your default shell in the system database."
fi

# Debug: Show current shell and what it will be after relogging
echo "📝 Current shell session is using: $SHELL"
echo "📝 Default shell in system database is: $CURRENT_SHELL"
echo "📝 After logging out and back in, your shell will be: $ZSH_PATH"
