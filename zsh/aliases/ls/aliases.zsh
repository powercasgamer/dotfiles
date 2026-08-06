if command -v eza >/dev/null 2>&1; then
  alias ls="eza --group-directories-first"
  alias ll="eza -alh --group-directories-first"
  alias lt="eza -alh --tree --level=2"
else
  alias ls="ls --color=auto"
  alias ll="ls -alhF"
  alias la="ls -A"
fi

alias grep="grep --color=auto"
alias egrep="egrep --color=auto"
