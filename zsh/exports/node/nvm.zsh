# nvm (https://github.com/nvm-sh/nvm) -- version manager for Node.js.
# Installed by nvm/setup.sh with PROFILE=/dev/null so its installer never
# touches this tracked zshrc; sourced here instead.
export NVM_DIR="$HOME/.nvm"

# Lazy-loaded: sourcing nvm.sh eagerly runs `nvm use` on every shell startup
# (nvm_auto in nvm.sh, on by default), which is ~half of total shell startup
# time by itself and has no payoff here since nothing uses its .nvmrc
# auto-switch. Instead, stub out the commands that need it; the first call
# to any of them sources the real nvm.sh (paying that cost once, not on
# every shell) and replaces these stubs with nvm's real functions.
if [ -s "$NVM_DIR/nvm.sh" ]; then
  _nvm_lazy_load() {
    unset -f nvm node npm npx corepack _nvm_lazy_load
    \. "$NVM_DIR/nvm.sh"
  }
  nvm() { _nvm_lazy_load; nvm "$@"; }
  node() { _nvm_lazy_load; node "$@"; }
  npm() { _nvm_lazy_load; npm "$@"; }
  npx() { _nvm_lazy_load; npx "$@"; }
  corepack() { _nvm_lazy_load; corepack "$@"; }
fi
