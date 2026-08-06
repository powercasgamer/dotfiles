# --- navigation ---
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias -- -="cd -"

# --- ls / eza ---
if command -v eza >/dev/null 2>&1; then
  alias ls="eza --group-directories-first"
  alias ll="eza -alh --group-directories-first"
  alias lt="eza -alh --tree --level=2"
else
  alias ls="ls --color=auto"
  alias ll="ls -alhF"
  alias la="ls -A"
fi

# --- grep ---
alias grep="grep --color=auto"
alias egrep="egrep --color=auto"

# --- safety nets ---
alias rm="rm -i"
alias cp="cp -i"
alias mv="mv -i"

# --- git ---
alias g="git"
alias gs="git status"
alias ga="git add"
alias gaa="git add -A"
alias gc="git commit -m"
alias gca="git commit -am"
alias gp="git push"
alias gpl="git pull"
alias gco="git checkout"
alias gcb="git checkout -b"
alias gb="git branch"
alias gd="git diff"
alias gl="git log --oneline --graph --decorate -20"
alias glog="git log --oneline --graph --decorate --all"

# --- system (Ubuntu/apt) ---
alias update="sudo apt update && sudo apt upgrade -y"
alias install="sudo apt install"
alias autoremove="sudo apt autoremove -y"

# --- misc quality of life ---
alias c="clear"
alias h="history"
alias path='echo -e ${PATH//:/\\n}'
alias reload="source ~/.zshrc"
alias zshconfig="${EDITOR:-nano} ~/dotfiles/zsh/zshrc"
alias aliasconfig="${EDITOR:-nano} ~/dotfiles/zsh/aliases.zsh"
alias ports="sudo ss -tulpn"
alias myip="curl -s ifconfig.me"
