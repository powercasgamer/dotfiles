# LS colors
alias ls='ls --color=auto -h'
alias ll='ls --color=auto -lh'
alias la='ls --color=auto -lha'

# Grep colors
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Confirm before overwriting
alias cp='cp -i'
alias mv='mv -i'

# Tree with colors and ignore .git/node_modules
alias tree='tree -C --dirsfirst -I "node_modules|.git|.cache|.gradle"'

# Colored diff
alias diff='diff --color=auto'

# Colored make
alias make='make --no-print-directory -j$(nproc) COLOR=1'

# Colored man pages
export LESS_TERMCAP_mb=$'\E[1;31m'     # begin blink
export LESS_TERMCAP_md=$'\E[1;36m'     # begin bold
export LESS_TERMCAP_me=$'\E[0m'        # reset bold/blink
export LESS_TERMCAP_so=$'\E[01;44;33m' # begin search highlight
export LESS_TERMCAP_se=$'\E[0m'        # reset search highlight
export LESS_TERMCAP_us=$'\E[1;32m'     # begin underline
export LESS_TERMCAP_ue=$'\E[0m'        # reset underline

# Upload file to pastes.dev
paste() {
  local file="$1"
  local lang="${2:-plaintext}"  # Default to plaintext if no language given

  if [[ ! -f "$file" ]]; then
    echo "Error: File not found: $file" >&2
    return 1
  fi

  curl -sS -T "$file" -H "Content-Type: text/$lang" https://api.pastes.dev/post
}