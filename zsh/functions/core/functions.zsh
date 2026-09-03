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
# query string from it. Timeout + retries so a stalled connection doesn't
# hang the shell indefinitely.
dl() {
  if [ -z "$1" ]; then
    echo "Error: URL is required." >&2
    return 1
  fi
  local url="$1"
  wget --content-disposition --timeout=30 --tries=3 "${url%%\?*}"
}

# upload a file to pastes.dev and print the resulting URL. Timeout so a
# stalled connection doesn't hang the shell indefinitely.
# e.g. paste ./script.sh sh
paste() {
  if [ -z "$1" ]; then
    echo "Error: file is required." >&2
    return 1
  fi
  local file="$1"
  local lang="$2"

  if [[ -n "$lang" ]]; then
    curl --connect-timeout 10 --max-time 60 -T "$file" -H "Content-Type: text/$lang" https://api.pastes.dev/post
  else
    curl --connect-timeout 10 --max-time 60 -T "$file" https://api.pastes.dev/post
  fi
}
