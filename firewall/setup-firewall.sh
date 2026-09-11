#!/usr/bin/env bash
# Adds/removes UFW allow rules for a provider's published IP ranges (e.g.
# Cloudflare) instead of hand-typing dozens of CIDRs. Every rule is tagged
# with a comment (dotfiles-firewall:<provider>) so it's obvious in
# `ufw status` where a rule came from.
#
# Usage:
#   sudo ~/dotfiles/firewall/setup-firewall.sh add cloudflare [--port 80,443] [--proto tcp]
#   sudo ~/dotfiles/firewall/setup-firewall.sh remove cloudflare [--port 80,443] [--proto tcp]
#   ~/dotfiles/firewall/setup-firewall.sh list-providers
#
# Adding a new provider: drop a file in providers/<name>.sh defining a
# fetch_ips() function that prints one CIDR per line (IPv4 and/or IPv6) to
# stdout. That's the only thing this script needs from a provider -- see
# providers/cloudflare.sh for a minimal example.
#
# Must run as root (ufw). Safe to re-run: `add` is a no-op for CIDRs already
# allowed, `remove` is a no-op for ones not present.
set -euo pipefail

FIREWALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVIDERS_DIR="$FIREWALL_DIR/providers"

usage() {
  echo "Usage: $0 <add|remove> <provider> [--port PORTS] [--proto PROTO]" >&2
  echo "       $0 list-providers" >&2
  exit 1
}

list_providers() {
  find "$PROVIDERS_DIR" -maxdepth 1 -name '*.sh' -print0 |
    xargs -0 -n1 basename 2>/dev/null | sed 's/\.sh$//' | sort
}

[ "$#" -ge 1 ] || usage
ACTION="$1"; shift

if [ "$ACTION" = "list-providers" ]; then
  list_providers
  exit 0
fi

if [ "$ACTION" != "add" ] && [ "$ACTION" != "remove" ]; then
  usage
fi

[ "$#" -ge 1 ] || usage
PROVIDER="$1"; shift

PORTS="80,443"
PROTO="tcp"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --port)
      [ "$#" -ge 2 ] || usage
      PORTS="$2"; shift 2 ;;
    --proto)
      [ "$#" -ge 2 ] || usage
      PROTO="$2"; shift 2 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root: sudo $0 $ACTION $PROVIDER" >&2
  exit 1
fi

if ! command -v ufw >/dev/null 2>&1; then
  echo "ufw is not installed." >&2
  exit 1
fi

PROVIDER_FILE="$PROVIDERS_DIR/$PROVIDER.sh"
if [ ! -f "$PROVIDER_FILE" ]; then
  echo "Unknown provider '$PROVIDER'. Available providers:" >&2
  list_providers | sed 's/^/    /' >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$PROVIDER_FILE"

if ! declare -f fetch_ips >/dev/null; then
  echo "Provider '$PROVIDER' (providers/$PROVIDER.sh) does not define fetch_ips()." >&2
  exit 1
fi

echo "==> Fetching $PROVIDER IP ranges"
IPS="$(fetch_ips)"
if [ -z "$IPS" ]; then
  echo "No IPs returned by provider '$PROVIDER' -- aborting." >&2
  exit 1
fi

COMMENT="dotfiles-firewall:$PROVIDER"
COUNT=0
while IFS= read -r cidr; do
  [ -n "$cidr" ] || continue
  if [ "$ACTION" = "add" ]; then
    ufw allow from "$cidr" to any port "$PORTS" proto "$PROTO" comment "$COMMENT" >/dev/null
  else
    # Comment text isn't part of what ufw matches on delete -- from/port/proto is.
    ufw delete allow from "$cidr" to any port "$PORTS" proto "$PROTO" >/dev/null 2>&1 || true
  fi
  COUNT=$((COUNT + 1))
done <<< "$IPS"

echo "==> Done: ${ACTION}ed $COUNT $PROVIDER CIDR rule(s) (port $PORTS/$PROTO)"
echo "    Review with: sudo ufw status numbered | grep '$COMMENT'"
