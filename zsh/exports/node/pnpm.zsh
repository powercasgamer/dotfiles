# pnpm (https://pnpm.io) -- fast, disk-space-efficient package manager for
# Node.js. Installed by pnpm/setup.sh, which strips its auto-appended
# ~/.zshrc snippet post-install; sourced here instead.
export PNPM_HOME="$HOME/.local/share/pnpm"
[ -d "$PNPM_HOME" ] && export PATH="$PNPM_HOME:$PATH"
