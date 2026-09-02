# Start (or reuse) a single ssh-agent per machine, shared across every shell
# and tmux pane, instead of spawning a fresh agent -- and losing loaded keys
# -- every time a new terminal opens. This is what makes `AddKeysToAgent yes`
# (ssh/ssh_config) and passphrase-free git commit signing (git/setup.sh,
# gpg.format=ssh) actually work without re-prompting constantly.
SSH_AGENT_ENV="$HOME/.ssh/agent.env"

if [ -f "$SSH_AGENT_ENV" ]; then
  source "$SSH_AGENT_ENV" >/dev/null
fi

ssh-add -l >/dev/null 2>&1
# exit code 2 = can't reach an agent (not running / stale socket); 0 or 1
# both mean a live agent answered, just with or without keys loaded
if [ $? -eq 2 ]; then
  mkdir -p "$HOME/.ssh"
  (umask 077; ssh-agent -s > "$SSH_AGENT_ENV")
  source "$SSH_AGENT_ENV" >/dev/null
fi

# load the git signing key once per boot (interactive shells only, so this
# never hangs a script waiting on a passphrase prompt)
if [[ -o interactive ]] && [ -f "$HOME/.ssh/id_ed25519" ]; then
  ssh-add -l 2>/dev/null | grep -q "id_ed25519" || ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null
fi
