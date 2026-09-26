#!/usr/bin/env bash
# Sets up WakaTime (https://wakatime.com) time tracking:
#   1. wakatime-cli, installed where every official editor plugin looks for
#      it (~/.wakatime/wakatime-cli-<os>-<arch> + a ~/.wakatime/wakatime-cli
#      symlink), so JetBrains/VS Code plugins reuse it instead of fetching
#      their own copy
#   2. ~/.wakatime.cfg with your API key -- prompted for once (interactive
#      only) and written chmod 600; never stored in this repo
#   3. the wakatime zsh plugin (sobolevn/wakatime-zsh-plugin) for terminal
#      tracking -- zsh/zshrc only enables it once the CLI and plugin exist
#   4. the WakaTime Claude Code plugin, if claude is installed (its hooks
#      run on node, so it needs nvm's node on PATH to report anything)
#
# Unprivileged (everything lands under $HOME), so this runs automatically
# from install.sh -- no root required. Needs curl and unzip.
#
# Safe to re-run: every step skips if already done, and an existing
# api_key in ~/.wakatime.cfg is never overwritten. The CLI isn't upgraded
# here; editor plugins and the Claude Code plugin keep it up to date.
set -euo pipefail

WAKATIME_DIR="$HOME/.wakatime"
WAKATIME_CFG="$HOME/.wakatime.cfg"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
export PATH="$HOME/.local/bin:$PATH"

for cmd in curl unzip; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing '$cmd'. Install it first, e.g.: sudo apt install -y $cmd"
    exit 1
  fi
done

echo "==> wakatime-cli"
if [ -x "$WAKATIME_DIR/wakatime-cli" ]; then
  echo "    already installed, skipping"
else
  case "$(uname -m)" in
    x86_64 | amd64) arch="amd64" ;;
    aarch64 | arm64) arch="arm64" ;;
    *) echo "Unsupported architecture: $(uname -m)"; exit 1 ;;
  esac
  binary="wakatime-cli-linux-$arch"
  mkdir -p "$WAKATIME_DIR"
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  curl -fsSL -o "$tmpdir/cli.zip" \
    "https://github.com/wakatime/wakatime-cli/releases/latest/download/$binary.zip"
  unzip -q -o "$tmpdir/cli.zip" -d "$WAKATIME_DIR"
  chmod 755 "$WAKATIME_DIR/$binary"
  ln -sf "$WAKATIME_DIR/$binary" "$WAKATIME_DIR/wakatime-cli"
  echo "    installed $("$WAKATIME_DIR/wakatime-cli" --version)"
fi

echo "==> ~/.wakatime.cfg"
if grep -qE '^[[:space:]]*api_key[[:space:]]*=' "$WAKATIME_CFG" 2>/dev/null; then
  echo "    api_key already set, leaving it as-is"
elif [ -e "$WAKATIME_CFG" ]; then
  echo "    exists but has no api_key -- add one under [settings] yourself:"
  echo "    api_key = <from https://wakatime.com/api-key>"
elif [ -t 0 ]; then
  echo "    get your key from https://wakatime.com/api-key"
  api_key=""
  while [ -z "$api_key" ]; do
    if command -v gum >/dev/null 2>&1; then
      api_key="$(gum input --password --header "WakaTime API key")"
    else
      read -rsp "WakaTime API key: " api_key
      echo
    fi
  done
  (umask 077; printf '[settings]\napi_key = %s\n' "$api_key" > "$WAKATIME_CFG")
  echo "    written (chmod 600)"
else
  echo "    no api_key and not running interactively -- skipping. Re-run"
  echo "    ~/dotfiles/wakatime/setup.sh from a terminal to enter it."
fi

echo "==> wakatime zsh plugin"
if [ -d "$ZSH_CUSTOM/plugins/wakatime" ]; then
  echo "    already present, skipping"
elif [ -d "$ZSH_CUSTOM" ]; then
  git clone --depth=1 https://github.com/sobolevn/wakatime-zsh-plugin "$ZSH_CUSTOM/plugins/wakatime"
else
  echo "    Oh My Zsh not installed ($ZSH_CUSTOM missing) -- skipping"
fi

echo "==> WakaTime Claude Code plugin"
if ! command -v claude >/dev/null 2>&1; then
  echo "    claude not installed -- skipping (run claude/setup.sh, then re-run this)"
elif claude plugin list 2>/dev/null | grep -q 'claude-code-wakatime@wakatime'; then
  echo "    already installed, skipping"
else
  claude plugin marketplace list 2>/dev/null | grep -q '❯ wakatime$' ||
    claude plugin marketplace add https://github.com/wakatime/claude-code-wakatime.git
  claude plugin install claude-code-wakatime@wakatime
fi

echo "==> Done"
