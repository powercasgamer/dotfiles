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
echo "📝 Found zsh at: $ZSH_PATH"

# Add Zsh to /etc/shells if it's not listed
if [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == "darwin"* ]]; then
    if ! grep -Fxq "$ZSH_PATH" /etc/shells; then
        echo "📄 Adding $ZSH_PATH to /etc/shells..."
        echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
    else
        echo "✅ $ZSH_PATH already listed in /etc/shells."
    fi
fi

# Check current shell in various ways
CURRENT_SHELL="$SHELL"
echo "📝 Current \$SHELL environment variable: $CURRENT_SHELL"

# This is more reliable than $SHELL
PASSWD_SHELL=$(getent passwd "$USER" | cut -d: -f7)
echo "📝 Current shell in passwd database: $PASSWD_SHELL"

# Change the shell more forcefully
echo "⚙️ Changing default shell to Zsh..."
if sudo chsh -s "$ZSH_PATH" "$USER"; then
    echo "✅ Default shell changed to Zsh with sudo."
else
    echo "⚠️ Sudo method failed, trying without sudo..."
    if chsh -s "$ZSH_PATH"; then
        echo "✅ Default shell changed to Zsh without sudo."
    else
        echo "❌ Failed to change shell with chsh. Trying direct passwd file modification..."

        # Very last resort - try usermod on Linux
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if sudo usermod --shell "$ZSH_PATH" "$USER"; then
                echo "✅ Shell changed using usermod."
            else
                echo "❌ All methods to change shell have failed."
                exit 1
            fi
        else
            echo "❌ All methods to change shell have failed."
            exit 1
        fi
    fi
fi

# Verify the change took effect in the password database
NEW_PASSWD_SHELL=$(getent passwd "$USER" | cut -d: -f7)
echo "📝 Updated shell in passwd database: $NEW_PASSWD_SHELL"

if [[ "$NEW_PASSWD_SHELL" == "$ZSH_PATH" ]]; then
    echo "✅ Shell successfully changed in system database."
    echo "🔄 You MUST log out completely and log back in for the change to take effect."
    echo "🔄 If using SSH, disconnect and reconnect."
    echo "🔄 If using a desktop environment, log out of your entire session."
else
    echo "❌ Shell change verification failed. Shell is still set to: $NEW_PASSWD_SHELL"
fi

# Create a test file to check after login
echo "#!/bin/sh
echo \"Shell after login: \$SHELL\"
echo \"Shell in passwd: \$(getent passwd \$USER | cut -d: -f7)\"
" >~/shell_test.sh
chmod +x ~/shell_test.sh
echo "📝 Created ~/shell_test.sh - run this after logging back in to verify your shell"
