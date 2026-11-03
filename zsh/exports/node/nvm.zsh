# nvm (https://github.com/nvm-sh/nvm) -- version manager for Node.js.
# Installed by nvm/setup.sh with PROFILE=/dev/null so its installer never
# touches this tracked zshrc; sourced here instead.
export NVM_DIR="$HOME/.nvm"

# Lazy-loaded: sourcing nvm.sh eagerly runs `nvm use` on every shell startup
# (nvm_auto in nvm.sh, on by default), which is ~half of total shell startup
# time by itself and has no payoff here since nothing uses its .nvmrc
# auto-switch. Instead, the default version's bin dir is put on PATH directly
# (just reading nvm's alias files), so node/npm/npx/corepack are real
# binaries visible to child processes and `#!/usr/bin/env node` scripts. Only
# `nvm` itself is stubbed; its first call sources the real nvm.sh.
#
# The stub is deliberately self-contained (no helper function): tools that
# snapshot shell functions, like Claude Code, skip `_`-prefixed ones, and a
# stub calling a missing helper recursed until FUNCNEST.
if [ -s "$NVM_DIR/nvm.sh" ]; then
  # Keep a node version chosen by a parent shell (`nvm use` then a subshell).
  if [[ ":$PATH:" != *":$NVM_DIR/versions/node/"*"/bin:"* ]]; then
    () {
      local v=default hops=0 pat
      local -a dirs
      # Follow alias chains, e.g. default -> lts/* -> lts/lithium -> v26.13.0.
      while [[ -f "$NVM_DIR/alias/$v" ]] && (( hops++ < 10 )); do
        v=$(<"$NVM_DIR/alias/$v")
      done
      v=${v#v}
      # "20" means the highest installed v20.x; node/stable mean highest overall.
      if [[ $v == (node|stable|) ]]; then pat='v*'; else pat="v${v}(|.*)"; fi
      dirs=( "$NVM_DIR"/versions/node/${~pat}(N/nOn) )
      (( $#dirs )) && path=("$dirs[1]/bin" $path)
    }
  fi

  nvm() {
    unset -f nvm
    \. "$NVM_DIR/nvm.sh" --no-use
    nvm "$@"
  }
fi
