# dotfiles

Portable zsh setup: Oh My Zsh + autosuggestions + syntax highlighting + a small
set of aliases/exports/functions. Copy this folder to any machine and run one
script to reproduce the whole setup.

## Layout

```
dotfiles/
├── install.sh        # installs Oh My Zsh + plugins, symlinks ~/.zshrc, runs git/setup.sh + tmux/setup.sh
├── new-user.sh        # creates a Linux user and bootstraps this whole setup for them
├── git/
│   ├── setup.sh                # git identity/defaults, git-lfs, SSH commit+tag signing
│   ├── gitignore_global        # applied to every repo via core.excludesfile
│   └── gitattributes_global    # applied to every repo via core.attributesfile
├── tmux/
│   ├── setup.sh                # symlinks ~/.tmux.conf, installs TPM + plugins
│   ├── tmux.conf                # main config (becomes ~/.tmux.conf via symlink)
│   └── conf.d/
│       ├── options.conf         # mouse, vi keys, true color, history
│       ├── bindings.conf        # pane splits/nav, reload binding
│       ├── statusbar.conf       # status bar styling
│       └── plugins.conf         # TPM plugin list (tpm/sensible/resurrect/continuum/yank)
├── ssh/
│   ├── setup.sh                # client-side: Include line in ~/.ssh/config, perms (safe, run by install.sh)
│   ├── ssh_config               # client hardening defaults, included via ~/.ssh/config
│   ├── harden-server.sh        # server-side hardening (opt-in, NOT run by install.sh -- see below)
│   └── sshd_hardening.conf      # drop-in installed to /etc/ssh/sshd_config.d/ by harden-server.sh
├── docker/
│   ├── setup.sh                # installs Docker Engine + Compose plugin (opt-in, NOT run by install.sh)
│   └── daemon.json              # daemon hardening, installed to /etc/docker/daemon.json
├── cleanup/
│   ├── cleanup.sh               # the actual cleanup logic; safe to run by hand, supports --dry-run
│   └── setup.sh                 # installs a weekly systemd timer for it (opt-in, NOT run by install.sh)
├── python/
│   └── setup.sh                  # installs python3 + pip + venv + dev + pipx (opt-in, NOT run by install.sh)
└── zsh/
    ├── zshrc                       # main config (becomes ~/.zshrc via symlink)
    ├── aliases/
    │   ├── git/aliases.zsh         # g, gs, ga, gc, gp, gco, gl...
    │   ├── ls/aliases.zsh          # ls/ll/lt, grep colors
    │   ├── nav/aliases.zsh         # .., ..., -
    │   ├── safety/aliases.zsh      # rm/cp/mv -i
    │   ├── system/aliases.zsh      # apt update/install, ports, myip
    │   ├── tmux/aliases.zsh        # tm/tma/tml/tmk/tmn, claude-tmux
    │   ├── docker/aliases.zsh      # d, dc, dps, dcup/dcdown, docker-compose compat
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
sudo apt update && sudo apt install -y zsh git curl tmux   # if not already present
git clone <this-repo-url> ~/dotfiles    # or scp/rsync the folder over
~/dotfiles/install.sh
exec zsh
```

(`gh` doesn't need an apt install — `git/setup.sh` fetches its binary
directly, same as git-lfs.)

`install.sh` is idempotent — re-run it any time (e.g. after pulling updates)
and it will skip anything already installed. `tmux` is optional: if it's not
installed when `install.sh` runs, the tmux step is skipped (with a note)
rather than failing the whole script — install `tmux` and re-run any time.

To make zsh your login shell: `chsh -s $(command -v zsh)` (needs a real
terminal for the password prompt).

Docker is also opt-in and not part of `install.sh` (it needs root for a
system package + daemon, unlike everything else here) — see the Docker
section below. Same for the storage cleanup timer and the Python install —
see the Cleanup and Python sections below.

## Creating a new user with this setup already applied

```bash
sudo ~/dotfiles/new-user.sh <username>              # prompts for a password and git identity
sudo ~/dotfiles/new-user.sh <username> --no-password # creates the account locked instead
sudo ~/dotfiles/new-user.sh <username> \
  --git-name "Their Name" --git-email "them@example.com"  # skip the git identity prompt too
sudo ~/dotfiles/new-user.sh <username> --docker  # also add them to the docker group
```

Must be run as root (it calls `useradd`/`apt-get`/`passwd`), so it needs a
real terminal — same reason `sudo` itself needs one. What it does:

1. Installs `zsh`/`git`/`curl`/`tmux` system-wide via `apt-get` if missing
   (no nested `sudo` needed — the script is already root).
2. Creates the user with zsh as their login shell, if they don't already
   exist. Existing users are left alone and just get the steps below re-run.
3. Copies this `dotfiles` folder into their home directory — but only if
   they don't already have one there, so re-running never clobbers a user's
   own edits to their copy.
4. Runs `install.sh` as that user (Oh My Zsh, plugins, `~/.zshrc` symlink,
   `git/setup.sh`, `tmux/setup.sh`, `ssh/setup.sh`). Server-side SSH
   hardening is never run automatically for a new user, same as for you —
   see the SSH section below.

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
- **GitHub CLI (`gh`)**: same no-`sudo` release-binary approach, into
  `~/.local/bin`. Doesn't run `gh auth login` for you — do that yourself.
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

## tmux setup (`tmux/setup.sh`)

Run automatically by `install.sh` if `tmux` is present, or standalone any
time. Symlinks `~/.tmux.conf` to `tmux/tmux.conf` (which explicitly sources
each file under `conf.d/`, in a fixed order — `plugins.conf` must load last
since TPM's own init line has to be the final thing tmux processes), then
installs [TPM](https://github.com/tmux-plugins/tpm) and the plugins listed
in `conf.d/plugins.conf`:

- `tmux-sensible` — better defaults
- `tmux-resurrect` + `tmux-continuum` — auto-save/restore session layout
  every 15 min, so a server restart doesn't lose your panes
- `tmux-yank` — copy tmux selections to the system clipboard

Prefix stays the tmux default (`C-b`). Notable bindings: `|`/`-` split
panes (keeping the current directory), `h`/`j`/`k`/`l` move between panes,
`r` reloads the config. Mouse mode and vi-style copy mode are on.

New categories under `conf.d/` just need an explicit `source-file` line
added to `tmux.conf` — kept explicit rather than globbed so load order
(plugins last) can't silently break.

### Running Claude Code inside tmux

`claude-tmux` (defined in `zsh/aliases/tmux/aliases.zsh`) attaches to a
tmux session named `claude` if one's already running, or creates it with
`claude` running inside if not:

```bash
claude-tmux
```

Detach with the usual `<prefix> d` — Claude Code keeps running in the
background (including through an SSH disconnect), and `claude-tmux` from any
terminal picks the same session back up. Other tmux shortcuts: `tm` (tmux),
`tma <name>` (attach), `tml` (list sessions), `tmk <name>` (kill a session).

## SSH setup (`ssh/`)

Client and server hardening are split into two separate scripts with very
different risk levels.

### Client (`ssh/setup.sh`) — run automatically by `install.sh`

Safe: runs as your normal user, no root, nothing here can lock you out.

- Sets `~/.ssh` to `700` and `~/.ssh/config` to `600`.
- Appends `Include <repo>/ssh/ssh_config` to the **end** of `~/.ssh/config`
  (creating it if missing) — appended rather than prepended because
  `ssh_config` resolves each parameter to its *first* match, so any
  Host-specific blocks you add yourself must stay ahead of this catch-all
  default, not get pushed after it. Idempotent: won't duplicate the line on
  re-run, and never touches Host blocks you've added.
- `ssh/ssh_config` itself sets `AddKeysToAgent`, `IdentitiesOnly`,
  `HashKnownHosts`, keepalive settings, and connection multiplexing
  (`ControlMaster`/`ControlPersist`, socket dir created at
  `~/.ssh/sockets`). No real hostnames/IPs ever belong in this repo — those
  go directly in your local `~/.ssh/config`, above the Include line.

### Server (`ssh/harden-server.sh`) — opt-in only, run it yourself

**Not** run by `install.sh`. Needs root, and a wrong sshd setting can lock
you out of remote access to the machine — that's exactly the kind of action
this repo's automation intentionally stays away from.

```bash
sudo ~/dotfiles/ssh/harden-server.sh
```

Installs `ssh/sshd_hardening.conf` to
`/etc/ssh/sshd_config.d/99-dotfiles-hardening.conf`, validates it with
`sshd -t` before touching the live service, and rolls back automatically if
validation fails. Sets `PermitRootLogin no`, `MaxAuthTries 3`,
`LoginGraceTime 30`, client-alive timeouts, and disables X11/agent
forwarding.

**Deliberately leaves `PasswordAuthentication` alone.** On this machine,
`~/.ssh/authorized_keys` was empty when this was built — disabling password
auth with no key installed would have locked out all remote access. The
line is in `ssh/sshd_hardening.conf`, commented out, with instructions:
once you've added a key to `authorized_keys` and confirmed key-based login
works from another terminal, uncomment it and re-run the script.

## Docker setup (`docker/setup.sh`)

Opt-in only, like `ssh/harden-server.sh` — needs root (apt repo + packages
+ systemd + group membership), so it's never run automatically by
`install.sh`.

```bash
sudo ~/dotfiles/docker/setup.sh [username]
```

`username` defaults to `$SUDO_USER` (whoever ran `sudo`) if not given. What
it does:

1. Adds Docker's official apt repo (key to `/etc/apt/keyrings/docker.asc`,
   source to `/etc/apt/sources.list.d/docker.list`, matching this machine's
   `$VERSION_CODENAME` and architecture) and installs `docker-ce`,
   `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, and
   `docker-compose-plugin` — skipped if `docker` + `docker compose` are
   already present.
2. Enables and starts the `docker` service.
3. Installs `docker/daemon.json` to `/etc/docker/daemon.json` (backing up
   anything already there that differs) and restarts the daemon **only**
   when the content actually changed — `live-restore: true` in that file
   means running containers survive the restart either way. Hardening in
   that file: JSON log rotation (`max-size: 10m`, `max-file: 3` — the
   default log driver has no rotation at all and will happily fill your
   disk), `no-new-privileges` by default, and `icc: false` (disables
   inter-container communication on the default bridge network only —
   doesn't affect `docker compose`, which creates its own network per
   project regardless).
4. Adds the target user to the `docker` group.

**Docker group membership is root-equivalent** on this machine — anyone in
it can bind-mount the host filesystem into a container. `new-user.sh`
reflects that: it's an explicit `--docker` flag, not automatic, for exactly
the same reason `ssh/harden-server.sh` won't touch `PasswordAuthentication`
without being asked. After being added to the group, log out/in (or open a
new terminal) for it to take effect — this shell was already running before
group membership changed, so it won't pick it up on its own.

Only `docker compose` (the plugin, v2, space not hyphen) gets installed —
the old standalone `docker-compose` binary is deprecated upstream.
`zsh/aliases/docker/aliases.zsh` adds a `docker-compose` shell alias for
muscle memory (`d`, `dc`, `dps`, `dcup`/`dcdown`, etc.), though it won't
help non-interactive scripts that call the literal `docker-compose` binary.

## Cleanup (`cleanup/`)

Reclaims disk space on a schedule: old Docker containers/images/build
cache/oversized container logs, the systemd journal, apt's package cache,
stale rotated logs in `/var/log` plus a configurable list of other service
log directories (`service-logs.txt` — redis, mongodb, nats, influxdb,
questdb, clickhouse, mysql/postgres, and more; anything not actually
installed is silently skipped), and the trash + thumbnail cache of a real
user. Everything is age-gated and only ever touches stopped/unused/rotated
things — never running containers, in-use images, or active log files
(the one opt-in exception being `LOG_TRUNCATE_UNROTATED`, off by default).

Opt-in only, like `docker/setup.sh` — the parts that touch apt, the system
journal, and `/var/log` need root, so it's never run automatically by
`install.sh`.

```bash
~/dotfiles/cleanup/cleanup.sh --dry-run   # see what it would do, no root needed
sudo ~/dotfiles/cleanup/setup.sh [username]   # installs the weekly timer
```

`username` (whose trash/thumbnail cache gets cleaned) defaults to
`$SUDO_USER` if not given, same convention as `docker/setup.sh`.
`setup.sh` installs `dotfiles-cleanup.service` + `.timer` to
`/etc/systemd/system/`, running as root every Sunday at 03:30 (±30m
jitter, `Persistent=true` so a missed run — e.g. laptop asleep — fires on
next boot).

`cleanup.sh` itself is privilege-aware and safe to run directly at any
time, with or without root:

- **Docker** (any user in the `docker` group, or root): prunes stopped
  containers older than 7 days, images unused by any container older than
  30 days, build cache older than 7 days, and anonymous unused volumes
  (never named/attached volumes). Root additionally truncates any
  container's JSON log file (whatever image it's running — no name
  matching involved) past 500MB, which matters for long-running containers
  that predate `docker/daemon.json`'s log rotation cap.
- **journald, apt, `/var/log` + `service-logs.txt`** (root only — skipped
  with a note otherwise): vacuums the journal to 14 days, runs
  `apt-get autoremove` + `autoclean`, and deletes rotated/compressed logs
  (`*.gz`, `*.xz`, `*.log.N`, `*.old`, dateext-style `*.log-YYYYMMDD`)
  older than 60 days from `/var/log` and every existing path in
  `cleanup/service-logs.txt`. That file is a plain `name path` list (same
  idea as `../github-sync/repos.txt`) pre-populated with the default log
  dirs for redis, mongodb, mysql/mariadb, postgresql, clickhouse-server,
  influxdb, elasticsearch, rabbitmq, nats, and questdb — add a line for
  anything else; entries for services not installed here are just no-ops.
  Some of those (NATS, QuestDB, InfluxDB run without an external
  `log_file`) don't rotate their own logs at all, so nothing ever gets
  deleted there by default — set `LOG_TRUNCATE_UNROTATED=1` to also
  truncate-to-zero (copytruncate-style — safe with an open fd, but
  discards history rather than archiving it) any `*.log` in those
  directories past `LOG_TRUNCATE_MB` (default 200).
- **Trash + thumbnails** (any user, targets `$TARGET_USER`'s home):
  empties `~/.local/share/Trash` items and `~/.cache/thumbnails` entries
  older than 30 days.

All the age/size thresholds are env vars (`DOCKER_CONTAINER_AGE`,
`DOCKER_IMAGE_AGE`, `DOCKER_BUILDCACHE_AGE`, `DOCKER_LOG_MAX_MB`,
`JOURNAL_RETENTION`, `LOG_AGE_DAYS`, `LOG_TRUNCATE_UNROTATED`,
`LOG_TRUNCATE_MB`, `SERVICE_LOGS_FILE`, `TRASH_AGE_DAYS`) — see the
comment header in `cleanup.sh` for defaults. Check logs with
`journalctl -u dotfiles-cleanup --since -30d`, run it on demand with
`sudo systemctl start dotfiles-cleanup.service`, and check the next
scheduled run with `systemctl list-timers dotfiles-cleanup.timer`.

## Python setup (`python/setup.sh`)

Opt-in only, like `docker/setup.sh` — needs root (apt), so it's never run
automatically by `install.sh`.

```bash
sudo ~/dotfiles/python/setup.sh
```

Installs `python3`, `python3-pip`, `python3-venv`, `python3-dev`, and
`pipx` via apt — skips the install entirely if all five are already
present, so it's safe to re-run any time. `python3` itself ships by
default on most Ubuntu installs, but `pip`/`venv`/`pipx` don't, which is
why this exists as a real script rather than a one-line dependency check
like `zsh`/`git`/`curl` at the top of `install.sh`. `~/.local/bin` (where
`pip install --user` and `pipx install` put scripts) is already on `PATH`
via `zsh/exports/core/exports.zsh`, conditional on the directory existing
— nothing further to configure after this runs.
