alias bsha256='function _bsha256(){ sha256sum "$1" | awk "{print \$1}" | xxd -r -p | base64; };_bsha256'
alias bsha512='function _bsha512(){ sha512sum "$1" | awk "{print \$1}" | xxd -r -p | base64; };_bsha512'

alias rsync-copy="rsync -avzPh"

function gsfp() {
    if [ -z "$1" ]; then
        echo "Error: branch is required."
        return 1
    fi

    git switch "$1"
    git fetch
    git pull --rebase
}

function gca() {
    # Check for staged or unstaged changes
    if ! git diff --cached --quiet || ! git diff --quiet; then
        git add . && git commit -m "$*"
    else
        echo "No changes detected (staged or unstaged) - nothing to commit."
        return 1
    fi
}

