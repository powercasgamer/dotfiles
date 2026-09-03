# bun (https://bun.sh) -- fast JS/TS runtime, bundler, test runner, and
# package manager. Installed by bun/setup.sh, which strips its auto-appended
# ~/.zshrc snippet post-install; sourced here instead.
export BUN_INSTALL="$HOME/.bun"
[ -d "$BUN_INSTALL/bin" ] && export PATH="$BUN_INSTALL/bin:$PATH"
