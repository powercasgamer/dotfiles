alias tm="tmux"
alias tma="tmux attach -t"
alias tml="tmux list-sessions"
alias tmk="tmux kill-session -t"
alias tmn="tmux new -s"

# Attach to the "claude" session if it's already running (e.g. from another
# terminal or after a disconnect), otherwise create it with `claude` running
# inside. Detach with the usual prefix+d and it keeps running in the
# background; re-run this to pick it back up.
alias claude-tmux="tmux new-session -A -s claude claude"
