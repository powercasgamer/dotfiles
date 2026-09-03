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

# base64-encoded sha256 digest of a file (e.g. for SRI hashes)
bsha256() {
  openssl dgst -sha256 -binary "$1" | base64
}

# base64-encoded sha512 digest of a file
bsha512() {
  openssl dgst -sha512 -binary "$1" | base64
}

# rsync copy with sane defaults: archive, verbose, compressed, progress, human-readable sizes
# e.g. rsync-copy ./local-dir/ user@host:/remote/dir/
rsync-copy() {
  rsync -avzPh "$@"
}

# download a URL, keeping the server's suggested filename and stripping any
# query string from it
dl() {
  local url="$1"
  wget --content-disposition "${url%%\?*}"
}
