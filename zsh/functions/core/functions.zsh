# make a directory and cd into it
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# (archive extraction is handled by the omz `extract` plugin: `x <archive>`)

# quick backup of a file: cp file file.bak
bak() {
  cp "$1" "$1.bak"
}

# find a process by name
psgrep() {
  ps aux | grep -i "$1" | grep -v grep
}
