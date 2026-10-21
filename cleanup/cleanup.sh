#!/usr/bin/env bash
# Reclaims disk space: old Docker containers/images/build cache/oversized
# container logs, systemd journal, apt cache, unused flatpak
# runtimes/extensions, stale rotated logs (/var/log plus whatever's listed
# in service-logs.txt -- redis/mongo/nats/influxdb/questdb/clickhouse/sql/
# etc, if actually present), and the invoking user's trash + thumbnail
# cache. Meant to run unattended (see setup.sh's timer) but is just as fine
# run by hand.
#
# Nothing here is hardcoded to a fixed set of services -- service-logs.txt
# is a plain "name path" list, skipped per-line if the path doesn't exist,
# so covering something new is just adding a line.
#
# Everything here is age-gated and only ever touches stopped/unused/rotated
# things -- never running containers, in-use images, or active log files
# (the one opt-in exception is LOG_TRUNCATE_UNROTATED, off by default --
# see below).
#
# Usage:
#   ./cleanup.sh [-n|--dry-run] [-y|--yes]
#
# When run interactively (a TTY) without --dry-run, asks for confirmation
# first (via gum if installed, else a plain y/N read) since this deletes
# things for real. Skipped automatically for --dry-run and for
# non-interactive runs (e.g. the systemd timer from setup.sh), so the
# unattended schedule is never blocked waiting on input; --yes skips it
# by hand. Unknown arguments are an error, so a typo like --dryrun can't
# fall through to a real run.
#
# Env vars (all ages accept docker-style durations like 168h/30d, or find's
# day counts where noted):
#   DOCKER_CONTAINER_AGE   default 168h  (7d)  -- stopped containers older than this
#   DOCKER_IMAGE_AGE       default 720h  (30d) -- images unused by any container, older than this
#   DOCKER_BUILDCACHE_AGE  default 168h  (7d)  -- build cache older than this
#   DOCKER_LOG_MAX_MB      default 500          -- truncate any container's json-log past this size (root only)
#   JOURNAL_RETENTION      default 14d          -- journalctl --vacuum-time (root only)
#   LOG_AGE_DAYS           default 60            -- rotated/compressed logs in /var/log + service-logs.txt (root only)
#   LOG_TRUNCATE_UNROTATED default 0 (off)        -- also truncate-to-zero *.log files in service-logs.txt
#                                                     paths past LOG_TRUNCATE_MB, for services with no rotation
#                                                     of their own (NATS, QuestDB, etc). Safe (copytruncate-style,
#                                                     doesn't break an open fd) but opt-in since it discards
#                                                     history rather than archiving it. Root only.
#   LOG_TRUNCATE_MB        default 200           -- size threshold for LOG_TRUNCATE_UNROTATED
#   SERVICE_LOGS_FILE      default: service-logs.txt next to this script
#   TRASH_AGE_DAYS         default 30             -- items in ~/.local/share/Trash trashed longer ago than this
#   TARGET_USER            default: $SUDO_USER, else current user -- whose trash/cache to clean
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

usage() {
  echo "Usage: $0 [-n|--dry-run] [-y|--yes]"
  echo "  -n, --dry-run  print what would be removed, change nothing"
  echo "  -y, --yes      skip the confirmation prompt"
  echo "Thresholds are env vars -- see the comment header in $0."
}

DRY_RUN=0
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_RUN=1 ;;
    -y|--yes)     ASSUME_YES=1 ;;
    -h|--help)    usage; exit 0 ;;
    *)            echo "Unknown argument: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

DOCKER_CONTAINER_AGE="${DOCKER_CONTAINER_AGE:-168h}"
DOCKER_IMAGE_AGE="${DOCKER_IMAGE_AGE:-720h}"
DOCKER_BUILDCACHE_AGE="${DOCKER_BUILDCACHE_AGE:-168h}"
DOCKER_LOG_MAX_MB="${DOCKER_LOG_MAX_MB:-500}"
JOURNAL_RETENTION="${JOURNAL_RETENTION:-14d}"
LOG_AGE_DAYS="${LOG_AGE_DAYS:-60}"
LOG_TRUNCATE_UNROTATED="${LOG_TRUNCATE_UNROTATED:-0}"
LOG_TRUNCATE_MB="${LOG_TRUNCATE_MB:-200}"
SERVICE_LOGS_FILE="${SERVICE_LOGS_FILE:-$SCRIPT_DIR/service-logs.txt}"
TRASH_AGE_DAYS="${TRASH_AGE_DAYS:-30}"
TARGET_USER="${TARGET_USER:-${SUDO_USER:-$(id -un)}}"

IS_ROOT=0
[[ "$(id -u)" -eq 0 ]] && IS_ROOT=1

if [[ "$DRY_RUN" -eq 0 && "$ASSUME_YES" -eq 0 && -t 0 ]]; then
  PROMPT="This will prune Docker resources, vacuum journald/apt/flatpak, delete old rotated logs, and empty trash/thumbnails older than ${TRASH_AGE_DAYS}d for '$TARGET_USER'. Continue?"
  if command -v gum >/dev/null 2>&1; then
    gum confirm "$PROMPT" || { echo "Cancelled." >&2; exit 1; }
  else
    read -rp "$PROMPT [y/N] " REPLY
    [[ "$REPLY" =~ ^[Yy]$ ]] || { echo "Cancelled." >&2; exit 1; }
  fi
fi

# A failing step (flatpak repair, a docker prune racing a container
# start, ...) is noted and skipped rather than aborting the run under
# set -e, so one broken section doesn't stop every section after it. Any
# failures are listed at the end and make the run exit 1 -- which marks
# the systemd unit failed, so it shows up in `systemctl --failed`.
FAILED=()

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "    [dry-run] $*"
  elif ! "$@"; then
    echo "    !! failed, continuing: $*" >&2
    FAILED+=("$*")
  fi
}

echo "==> Cleanup starting $(date -Iseconds) (dry-run=$DRY_RUN, root=$IS_ROOT, target-user=$TARGET_USER)"

# ---- Docker ----------------------------------------------------------
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  echo "==> Docker: before"
  docker system df

  echo "==> Docker: stopped containers older than $DOCKER_CONTAINER_AGE"
  run docker container prune -f --filter "until=${DOCKER_CONTAINER_AGE}"

  echo "==> Docker: unused images older than $DOCKER_IMAGE_AGE"
  run docker image prune -af --filter "until=${DOCKER_IMAGE_AGE}"

  echo "==> Docker: build cache older than $DOCKER_BUILDCACHE_AGE"
  run docker builder prune -af --filter "until=${DOCKER_BUILDCACHE_AGE}"

  echo "==> Docker: anonymous unused volumes"
  run docker volume prune -f

  echo "==> Docker: after"
  docker system df

  if [[ "$IS_ROOT" -eq 1 ]]; then
    echo "==> Docker: container logs over ${DOCKER_LOG_MAX_MB}MB (any service -- redis/mongo/whatever's containerized)"
    while IFS=$'\t' read -r cid cname; do
      logpath="$(docker inspect --format='{{.LogPath}}' "$cid" 2>/dev/null || true)"
      [[ -z "$logpath" || ! -f "$logpath" ]] && continue
      size_mb=$(( $(stat -c%s "$logpath") / 1024 / 1024 ))
      if [[ "$size_mb" -gt "$DOCKER_LOG_MAX_MB" ]]; then
        echo "    $cname: ${size_mb}MB -> truncating"
        run truncate -s 0 "$logpath"
      fi
    done < <(docker ps -a --format '{{.ID}}\t{{.Names}}')
  else
    echo "==> Docker: container log size cap skipped (needs root)"
  fi
else
  echo "==> Docker: not available, skipping"
fi

# ---- systemd journal (root only) --------------------------------------
if [[ "$IS_ROOT" -eq 1 ]]; then
  echo "==> journald: vacuuming to $JOURNAL_RETENTION"
  run journalctl --vacuum-time="$JOURNAL_RETENTION"
else
  echo "==> journald: skipping (needs root)"
fi

# ---- apt (root only) ---------------------------------------------------
if [[ "$IS_ROOT" -eq 1 ]] && command -v apt-get >/dev/null 2>&1; then
  echo "==> apt: autoremove + autoclean + clean"
  run apt-get -y autoremove
  run apt-get -y autoclean
  run apt-get -y clean
else
  echo "==> apt: skipping (needs root, or not present)"
fi

# ---- flatpak (root only) ------------------------------------------------
if [[ "$IS_ROOT" -eq 1 ]] && command -v flatpak >/dev/null 2>&1; then
  echo "==> flatpak: removing unused runtimes/extensions"
  run flatpak uninstall --system --unused -y

  echo "==> flatpak: repairing/deduplicating local repo"
  run flatpak repair --system
else
  echo "==> flatpak: skipping (needs root, or not present)"
fi

# ---- stale rotated logs (root only) ------------------------------------
# Matches: foo.log.gz, foo.log.1, foo.log.old, and dateext-style
# foo.log-20260101 / foo.log_2026-08-08 (mongod's own rotation, logrotate
# with `dateext`, etc).
ROTATED_LOG_PATTERN=( -name '*.gz' -o -name '*.xz' -o -name '*.log.[0-9]*' -o -name '*.old' -o -name '*.log-*' -o -name '*.log_*' )

sweep_rotated_logs() {
  local dir="$1" label="$2"
  echo "==> ${label}: rotated/compressed logs older than ${LOG_AGE_DAYS}d"
  while IFS= read -r -d '' f; do
    run rm -f -- "$f"
  done < <(find "$dir" -type f \( "${ROTATED_LOG_PATTERN[@]}" \) -mtime +"$LOG_AGE_DAYS" -print0)
}

if [[ "$IS_ROOT" -eq 1 ]]; then
  sweep_rotated_logs /var/log "/var/log"

  # Extra log locations (redis, mongo, nats, influxdb, questdb, clickhouse,
  # sql, and anything else listed) -- skipped per-line if not present.
  if [[ -f "$SERVICE_LOGS_FILE" ]]; then
    while IFS= read -r line; do
      line="${line#"${line%%[![:space:]]*}"}"
      line="${line%"${line##*[![:space:]]}"}"
      [[ -z "$line" || "$line" == \#* ]] && continue
      name="${line%% *}"
      rest="${line#"$name"}"
      [[ "$rest" =~ ^[[:space:]]*(.*)$ ]]
      log_dir="${BASH_REMATCH[1]}"
      [[ ! -d "$log_dir" ]] && continue

      sweep_rotated_logs "$log_dir" "$name ($log_dir)"

      if [[ "$LOG_TRUNCATE_UNROTATED" -eq 1 ]]; then
        while IFS= read -r -d '' f; do
          size_mb=$(( $(stat -c%s "$f") / 1024 / 1024 ))
          if [[ "$size_mb" -gt "$LOG_TRUNCATE_MB" ]]; then
            echo "    $name: $f is ${size_mb}MB -> truncating (copytruncate-style, keeps the fd valid)"
            run truncate -s 0 "$f"
          fi
        done < <(find "$log_dir" -type f -name '*.log' -print0)
      fi
    done < "$SERVICE_LOGS_FILE"
  fi
else
  echo "==> /var/log + service logs: skipping (needs root)"
fi

# ---- user trash + thumbnail cache --------------------------------------
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6 || true)"
if [[ -n "$TARGET_HOME" && -d "$TARGET_HOME" ]]; then
  TRASH_DIR="$TARGET_HOME/.local/share/Trash"
  echo "==> Trash: items trashed more than ${TRASH_AGE_DAYS}d ago in $TRASH_DIR"
  # Aged by when each item was trashed, not by its own mtime (which
  # trashing leaves alone -- a year-old file trashed yesterday would go on
  # the next run). Its .trashinfo is written at trash time, so go by that.
  if [[ -d "$TRASH_DIR/info" ]]; then
    while IFS= read -r -d '' info; do
      base="$(basename -- "$info" .trashinfo)"
      run rm -rf -- "$TRASH_DIR/files/$base" "$info"
    done < <(find "$TRASH_DIR/info" -mindepth 1 -maxdepth 1 -name '*.trashinfo' -mtime +"$TRASH_AGE_DAYS" -print0)
  fi

  echo "==> Thumbnail cache: $TARGET_HOME/.cache/thumbnails"
  if [[ -d "$TARGET_HOME/.cache/thumbnails" ]]; then
    run find "$TARGET_HOME/.cache/thumbnails" -type f -mtime +"$TRASH_AGE_DAYS" -delete
  fi
else
  echo "==> Trash/thumbnails: could not resolve home for '$TARGET_USER', skipping"
fi

if [[ "${#FAILED[@]}" -gt 0 ]]; then
  echo "==> Cleanup finished $(date -Iseconds) with ${#FAILED[@]} failed step(s):" >&2
  printf '    %s\n' "${FAILED[@]}" >&2
  exit 1
fi
echo "==> Cleanup finished $(date -Iseconds)"
