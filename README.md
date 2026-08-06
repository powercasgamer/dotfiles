# dotfiles

Portable zsh setup: Oh My Zsh + autosuggestions + syntax highlighting + a small
set of aliases/exports/functions. Copy this folder to any machine and run one
script to reproduce the whole setup.

## Layout

```
dotfiles/
├── install.sh        # installs Oh My Zsh + plugins, symlinks ~/.zshrc, runs git/setup.sh
├── new-user.sh        # creates a Linux user and bootstraps this whole setup for them
├── git/
│   ├── setup.sh                # git identity/defaults, git-lfs, SSH commit+tag signing
│   ├── gitignore_global        # applied to every repo via core.excludesfile
│   └── gitattributes_global    # applied to every repo via core.attributesfile
└── zsh/
    ├── zshrc                       # main config (becomes ~/.zshrc via symlink)
    ├── aliases/
    │   ├── git/aliases.zsh         # g, gs, ga, gc, gp, gco, gl...
    │   ├── ls/aliases.zsh          # ls/ll/lt, grep colors
    │   ├── nav/aliases.zsh         # .., ..., -
    │   ├── safety/aliases.zsh      # rm/cp/mv -i
    │   ├── system/aliases.zsh      # apt update/install, ports, myip
    │   └── misc/aliases.zsh        # reload, zshconfig, dotfiles
    ├── exports/
    │   └── core/exports.zsh        # EDITOR, history size, PATH, less colors
    └── functions/
        └── core/functions.zsh      # mkcd, bak, psgrep
```

`zshrc` sources every `*.zsh` file found anywhere under `aliases/`,
`exports/`, and `functions/`, no matter how deeply nested — so adding a new
category is just making a new folder and dropping a `.zsh` file in it, e.g.
`aliases/docker/aliases.zsh` or `aliases/work/aliases.zsh`. No need to touch
`zshrc` itself.

## Set up on a new machine

```bash
sudo apt update && sudo apt install -y zsh git curl   # if not already present
git clone <this-repo-url> ~/dotfiles    # or scp/rsync the folder over
~/dotfiles/install.sh
exec zsh
```

`install.sh` is idempotent — re-run it any time (e.g. after pulling updates)
and it will skip anything already installed.

To make zsh your login shell: `chsh -s $(command -v zsh)` (needs a real
terminal for the password prompt).

## Creating a new user with this setup already applied

```bash
sudo ~/dotfiles/new-user.sh <username>              # prompts for a password and git identity
sudo ~/dotfiles/new-user.sh <username> --no-password # creates the account locked instead
sudo ~/dotfiles/new-user.sh <username> \
  --git-name "Their Name" --git-email "them@example.com"  # skip the git identity prompt too
```

Must be run as root (it calls `useradd`/`apt-get`/`passwd`), so it needs a
real terminal — same reason `sudo` itself needs one. What it does:

1. Installs `zsh`/`git`/`curl` system-wide via `apt-get` if missing (no
   nested `sudo` needed — the script is already root).
2. Creates the user with zsh as their login shell, if they don't already
   exist. Existing users are left alone and just get the steps below re-run.
3. Copies this `dotfiles` folder into their home directory — but only if
   they don't already have one there, so re-running never clobbers a user's
   own edits to their copy.
4. Runs `install.sh` as that user (Oh My Zsh, plugins, `~/.zshrc` symlink,
   `git/setup.sh`).

Each new user gets their own copy of the repo, so they can diverge from
yours independently, and their own git identity (see below) — nothing here
is tied to your name/email. Their SSH signing key won't exist yet (private
keys are never copied by this repo) — `git/setup.sh` detects that and just
skips signing setup with instructions, same as on a fresh machine.

## Making changes

Edit files under `zsh/` directly — `~/.zshrc` is a symlink into this repo, so
changes are picked up immediately with `reload` (an alias for
`source ~/.zshrc`, defined in `aliases/misc/aliases.zsh`).

Anything machine-specific (secrets, host-only PATH tweaks) goes in
`~/.zshrc.local`, which is sourced last and NOT tracked by this repo.

## Suggestions plugin

`zsh-autosuggestions` shows a greyed-out suggestion from your history as you
type — press `→` (right arrow) to accept it. `zsh-syntax-highlighting` colors
commands green (valid) or red (invalid/unknown) as you type them.

## Git setup (`git/setup.sh`)

Run automatically by `install.sh`, or standalone any time. Nothing in this
script is tied to a specific person — sets:

- **Identity**: `user.name` / `user.email`. Never hardcoded. Resolved in
  order: `$GIT_NAME`/`$GIT_EMAIL` env vars (for scripted use, e.g.
  `new-user.sh --git-name/--git-email`) → whatever's already configured
  globally (so re-running this script never re-prompts or overwrites your
  choice) → an interactive prompt, if stdin is a TTY. If none of those apply
  (non-interactive, nothing set, no env vars) identity and signing setup are
  skipped with an explanation instead of guessing.
- **Defaults**: `init.defaultBranch=main`, `pull.rebase=false` (merge on
  divergent pull), `push.autoSetupRemote=true`, `core.editor=nano`,
  `rerere.enabled=true`.
- **git-lfs**: downloaded straight from the GitHub release (no `sudo`
  needed) into `~/.local/bin`, then `git lfs install`.
- **Global ignore/attributes**: points `core.excludesfile` /
  `core.attributesfile` at `gitignore_global` / `gitattributes_global` in
  this repo. Only OS/editor cruft (`.DS_Store`, `*.swp`, `.idea/`, ...) and
  universal normalization (`* text=auto eol=lf`, common binary types) live
  here — project-specific rules still belong in each repo's own
  `.gitignore` / `.gitattributes`.
- **SSH commit/tag signing**: if `~/.ssh/id_ed25519.pub` exists, configures
  `gpg.format=ssh`, points `user.signingkey` at it, turns on
  `commit.gpgsign` / `tag.gpgsign`, and writes `~/.ssh/allowed_signers` so
  `git log --show-signature` / `git verify-commit` work locally.

**The private half of that keypair is never stored in this repo** — it has
to already exist on the machine (generate fresh with `ssh-keygen -t ed25519`,
or copy the keypair over out-of-band, e.g. `scp`, not through this repo)
before `git/setup.sh` will wire up signing. If it's missing, the script
prints instructions and skips that step without failing.

To actually get the "Verified" badge on GitHub, add the public key there
separately as a **Signing Key** (Settings → SSH and GPG keys → New SSH key →
Key type: Signing Key) — a key already added as an Authentication key still
needs to be added a second time as a Signing key.
