#!/usr/bin/env bash
# apt housekeeping in one go: refresh package lists, upgrade, then remove
# what's no longer needed. Run by hand (the `maintenance` zsh alias) --
# unlike cleanup.sh it upgrades packages, so it's not put on a timer.
#
# Steps, in order:
#   1. Pre-flight: enough free space on /, /var and /boot, and no packages
#      left half-installed by an interrupted dpkg run (`dpkg --audit`).
#   2. apt-get update.
#   3. apt-get upgrade --with-new-pkgs: installs new dependencies (e.g. a
#      new kernel) but never removes anything. --full uses full-upgrade
#      instead, which may remove packages to resolve conflicts.
#   4. apt-get autoremove --purge: unused dependencies, old kernels
#      included. apt's own kernel rules always keep the running kernel and
#      the newest ones, so there's no hand-rolled kernel purging here.
#   5. Purges leftover config files of already-removed packages (dpkg
#      state "rc").
#   6. apt-get autoclean: drops downloaded .debs that can no longer be
#      installed.
#   7. Lists held packages (left alone -- a hold is respected, never
#      lifted) and says whether a reboot is needed.
#
# Each apt step shows its own package list and [Y/n] prompt; answering n
# stops the run there. Any failing step stops it too -- unlike cleanup.sh,
# carrying on after a failed upgrade could autoremove the wrong things.
#
# Usage:
#   sudo ~/dotfiles/apt/maintenance.sh [-n|--dry-run] [-y|--yes] [--full]
#
#   -n, --dry-run  simulate the upgrade/remove steps (apt-get -s); no root
#                  needed. Skips apt-get update, so it works from the
#                  current lists, and autoclean.
#   -y, --yes      answer yes to every prompt, and keep the installed
#                  version of any config file a package update changes.
#                  Required when there's no terminal to prompt on.
#   --full         full-upgrade instead of upgrade
#
# Env vars:
#   MIN_FREE_MB       default 1024 -- free space needed on / and /var
#   MIN_BOOT_FREE_MB  default 150  -- free space needed on /boot (room for
#                                     one more kernel + initramfs)
set -euo pipefail

usage() {
  echo "Usage: $0 [-n|--dry-run] [-y|--yes] [--full]"
  echo "  -n, --dry-run  simulate, change nothing"
  echo "  -y, --yes      don't prompt; keep installed config files on conflicts"
  echo "  --full         full-upgrade instead of upgrade (may remove packages)"
}

DRY_RUN=0
ASSUME_YES=0
FULL=0
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_RUN=1 ;;
    -y|--yes)     ASSUME_YES=1 ;;
    --full)       FULL=1 ;;
    -h|--help)    usage; exit 0 ;;
    *)            echo "Unknown argument: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

MIN_FREE_MB="${MIN_FREE_MB:-1024}"
MIN_BOOT_FREE_MB="${MIN_BOOT_FREE_MB:-150}"

if ! command -v apt-get >/dev/null 2>&1; then
  echo "apt-get not found -- this script is for Debian/Ubuntu." >&2
  exit 1
fi
if [[ "$DRY_RUN" -eq 0 && "$(id -u)" -ne 0 ]]; then
  echo "Run this as root: sudo $0 (or try --dry-run)" >&2
  exit 1
fi
if [[ "$DRY_RUN" -eq 0 && "$ASSUME_YES" -eq 0 && ! -t 0 ]]; then
  echo "No terminal to prompt on -- pass --yes to run unattended." >&2
  exit 1
fi

# Wait up to 5 minutes for the dpkg lock (unattended-upgrades holding it
# is common right after boot) instead of failing immediately.
APT=(apt-get -o DPkg::Lock::Timeout=300)
if [[ "$ASSUME_YES" -eq 1 ]]; then
  export DEBIAN_FRONTEND=noninteractive
  APT+=(-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)
fi
[[ "$DRY_RUN" -eq 1 ]] && APT+=(-s)

# ---- 1. pre-flight ------------------------------------------------------
check_free() {
  local path="$1" min_mb="$2" avail_mb
  [[ -d "$path" ]] || return 0
  avail_mb=$(( $(df -B1M --output=avail "$path" | tail -1) ))
  if [[ "$avail_mb" -lt "$min_mb" ]]; then
    echo "Only ${avail_mb}MB free on $path (need ${min_mb}MB) -- free some space first" >&2
    echo "(e.g. sudo ~/dotfiles/cleanup/cleanup.sh)." >&2
    exit 1
  fi
}

echo "==> Pre-flight checks"
check_free / "$MIN_FREE_MB"
check_free /var "$MIN_FREE_MB"
check_free /boot "$MIN_BOOT_FREE_MB"

audit="$(dpkg --audit 2>&1 || true)"
if [[ -n "$audit" ]]; then
  echo "$audit" >&2
  echo "dpkg reports unfinished packages -- fix those first with:" >&2
  echo "  sudo dpkg --configure -a && sudo apt-get -f install" >&2
  exit 1
fi

# ---- 2. update ----------------------------------------------------------
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "==> apt-get update: skipped (dry run, using current package lists)"
else
  echo "==> apt-get update"
  "${APT[@]}" update
fi

# ---- 3. upgrade ---------------------------------------------------------
if [[ "$FULL" -eq 1 ]]; then
  echo "==> apt-get full-upgrade"
  "${APT[@]}" full-upgrade
else
  echo "==> apt-get upgrade --with-new-pkgs"
  "${APT[@]}" upgrade --with-new-pkgs
fi

# ---- 4. autoremove ------------------------------------------------------
echo "==> apt-get autoremove --purge"
"${APT[@]}" autoremove --purge

# ---- 5. leftover config -------------------------------------------------
mapfile -t leftover < <(dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' | awk '$1 == "rc" { print $2 }')
if [[ "${#leftover[@]}" -gt 0 ]]; then
  echo "==> Purging leftover config of ${#leftover[@]} removed package(s)"
  "${APT[@]}" purge "${leftover[@]}"
else
  echo "==> No leftover config from removed packages"
fi

# ---- 6. autoclean -------------------------------------------------------
# Not simulated: -s lists nothing for it, and fails without root (it
# still opens /var/cache/apt/archives/partial).
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "==> apt-get autoclean: skipped (dry run)"
else
  echo "==> apt-get autoclean"
  "${APT[@]}" autoclean
fi

# ---- 7. report ----------------------------------------------------------
mapfile -t held < <(apt-mark showhold)
if [[ "${#held[@]}" -gt 0 ]]; then
  echo "==> Held back (apt-mark unhold <pkg> to release): ${held[*]}"
fi

if [[ -f /var/run/reboot-required ]]; then
  echo "==> Reboot required"
  if [[ -f /var/run/reboot-required.pkgs ]]; then
    echo "    for: $(sort -u /var/run/reboot-required.pkgs | paste -sd' ')"
  fi
fi

echo "==> Done"
