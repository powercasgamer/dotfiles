# No sudo prefix as root: it's redundant, and containers often don't ship sudo.
if (( EUID == 0 )); then _sudo=""; else _sudo="sudo "; fi
alias update="${_sudo}apt update && ${_sudo}apt upgrade -y"
alias install="${_sudo}apt install"
alias autoremove="${_sudo}apt autoremove -y"
alias ports="${_sudo}ss -tulpn"
unset _sudo
alias myip="curl -s ifconfig.me"
alias nukejetbrains="pkill -9 -f 'jetbrains|ide-backend|remote-dev-server|fsnotifier'"
