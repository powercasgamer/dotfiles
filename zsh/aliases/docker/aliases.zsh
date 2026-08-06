alias d="docker"
alias dps="docker ps"
alias dpsa="docker ps -a"
alias di="docker images"
alias dexec="docker exec -it"
alias dlogs="docker logs -f"
alias dprune="docker system prune -f"

alias dc="docker compose"
alias dcup="docker compose up -d"
alias dcdown="docker compose down"
alias dcb="docker compose build"
alias dcr="docker compose restart"
alias dcps="docker compose ps"
alias dcl="docker compose logs -f"

# muscle-memory compat: the compose plugin only provides `docker compose`,
# not a standalone `docker-compose` binary
alias docker-compose="docker compose"
