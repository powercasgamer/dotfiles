# dotfiles

Portable zsh setup: Oh My Zsh + autosuggestions + syntax highlighting + a small
set of aliases/exports/functions. Copy this folder to any machine and run one
script to reproduce the whole setup.

## Layout

```
dotfiles/
├── install.sh        # installs Oh My Zsh + plugins, symlinks ~/.zshrc
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
