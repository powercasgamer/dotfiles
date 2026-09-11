#!/usr/bin/env bash
# UFW rule management:
#   - add/remove:   allow rules for a provider's published IP ranges (e.g.
#                   Cloudflare) instead of hand-typing dozens of CIDRs.
#   - trust-ip:     allow ALL ports/protocols, both directions, for one IP.
#   - trust-interface: allow ALL ports/protocols, both directions, on an
#                   interface (e.g. tailscale0) -- for a VPN/mesh interface
#                   where every packet already arrived pre-authenticated,
#                   which is safer than allowing its IP range by CIDR (that
#                   range may not be exclusive to your traffic, and a rule
#                   matched on source IP alone doesn't prove the packet
#                   actually came in over that interface).
# Every rule is tagged with a comment (dotfiles-firewall:...) so it's
# obvious in `ufw status` where a rule came from.
#
# Usage:
#   ~/dotfiles/firewall/setup-firewall.sh                     # interactive menu (needs gum: ~/dotfiles/gum/setup.sh)
#   sudo ~/dotfiles/firewall/setup-firewall.sh add cloudflare [--port 80,443] [--proto tcp]
#   sudo ~/dotfiles/firewall/setup-firewall.sh remove cloudflare [--port 80,443] [--proto tcp]
#   ~/dotfiles/firewall/setup-firewall.sh list-providers
#   sudo ~/dotfiles/firewall/setup-firewall.sh trust-ip 100.64.0.5
#   sudo ~/dotfiles/firewall/setup-firewall.sh untrust-ip 100.64.0.5
#   sudo ~/dotfiles/firewall/setup-firewall.sh trust-interface tailscale0
#   sudo ~/dotfiles/firewall/setup-firewall.sh untrust-interface tailscale0
#
# Adding a new provider: drop a file in providers/<name>.sh defining a
# fetch_ips() function that prints one CIDR per line (IPv4 and/or IPv6) to
# stdout. That's the only thing this script needs from a provider -- see
# providers/cloudflare.sh for a minimal example.
#
# Must run as root (ufw), except list-providers. Safe to re-run: every
# action is a no-op if the rule it would add/remove is already in the
# state it's trying to reach.
set -euo pipefail

FIREWALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVIDERS_DIR="$FIREWALL_DIR/providers"

usage() {
  cat >&2 <<EOF
Usage:
  $0 <add|remove> <provider> [--port PORTS] [--proto PROTO]
  $0 list-providers
  $0 <trust-ip|untrust-ip> <ip>
  $0 <trust-interface|untrust-interface> <iface>
EOF
  exit 1
}

list_providers() {
  find "$PROVIDERS_DIR" -maxdepth 1 -name '*.sh' -print0 |
    xargs -0 -n1 basename 2>/dev/null | sed 's/\.sh$//' | sort
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Run this as root: sudo $0 $*" >&2
    exit 1
  fi
}

require_ufw() {
  if ! command -v ufw >/dev/null 2>&1; then
    echo "ufw is not installed." >&2
    exit 1
  fi
}

do_provider_rule() {
  local action="$1" provider="$2" ports="$3" proto="$4"
  local provider_file="$PROVIDERS_DIR/$provider.sh"

  if [ ! -f "$provider_file" ]; then
    echo "Unknown provider '$provider'. Available providers:" >&2
    list_providers | sed 's/^/    /' >&2
    exit 1
  fi

  # shellcheck source=/dev/null
  source "$provider_file"

  if ! declare -f fetch_ips >/dev/null; then
    echo "Provider '$provider' (providers/$provider.sh) does not define fetch_ips()." >&2
    exit 1
  fi

  echo "==> Fetching $provider IP ranges"
  local ips
  ips="$(fetch_ips)"
  if [ -z "$ips" ]; then
    echo "No IPs returned by provider '$provider' -- aborting." >&2
    exit 1
  fi

  local comment="dotfiles-firewall:$provider"
  local count=0 cidr
  while IFS= read -r cidr; do
    [ -n "$cidr" ] || continue
    if [ "$action" = "add" ]; then
      ufw allow from "$cidr" to any port "$ports" proto "$proto" comment "$comment" >/dev/null
    else
      # Comment text isn't part of what ufw matches on delete -- from/port/proto is.
      ufw delete allow from "$cidr" to any port "$ports" proto "$proto" >/dev/null 2>&1 || true
    fi
    count=$((count + 1))
  done <<< "$ips"

  echo "==> Done: ${action}ed $count $provider CIDR rule(s) (port $ports/$proto)"
  echo "    Review with: sudo ufw status numbered | grep '$comment'"
}

do_ip_rule() {
  local action="$1" ip="$2"
  local comment="dotfiles-firewall:trust-ip:$ip"

  if [ "$action" = "trust-ip" ]; then
    ufw allow from "$ip" comment "$comment" >/dev/null
    ufw allow out to "$ip" comment "$comment" >/dev/null
    echo "==> Trusted $ip (all ports/protocols, both directions)"
  else
    ufw delete allow from "$ip" >/dev/null 2>&1 || true
    ufw delete allow out to "$ip" >/dev/null 2>&1 || true
    echo "==> Removed trust for $ip"
  fi
  echo "    Review with: sudo ufw status numbered | grep '$comment'"
}

do_interface_rule() {
  local action="$1" iface="$2"
  local comment="dotfiles-firewall:trust-interface:$iface"

  if [ "$action" = "trust-interface" ]; then
    ufw allow in on "$iface" comment "$comment" >/dev/null
    ufw allow out on "$iface" comment "$comment" >/dev/null
    echo "==> Trusted interface $iface (all ports/protocols, both directions)"
  else
    ufw delete allow in on "$iface" >/dev/null 2>&1 || true
    ufw delete allow out on "$iface" >/dev/null 2>&1 || true
    echo "==> Removed trust for interface $iface"
  fi
  echo "    Review with: sudo ufw status numbered | grep '$comment'"
}

run_interactive() {
  if ! command -v gum >/dev/null 2>&1; then
    echo "No arguments given, and 'gum' isn't installed for the interactive menu." >&2
    echo "Install it with: ~/dotfiles/gum/setup.sh   (or pass args directly)" >&2
    echo >&2
    usage
  fi

  local action
  action="$(gum choose --header "What do you want to do?" \
    add remove trust-ip untrust-ip trust-interface untrust-interface list-providers)" || true
  [ -n "$action" ] || { echo "Cancelled." >&2; exit 1; }

  case "$action" in
    list-providers)
      list_providers
      ;;

    add | remove)
      local provider ports proto
      provider="$(list_providers | gum choose --header "Provider?")" || true
      [ -n "$provider" ] || { echo "Cancelled." >&2; exit 1; }
      ports="$(gum input --header "Ports" --value "80,443")" || true
      proto="$(gum input --header "Protocol" --value "tcp")" || true
      gum confirm "About to $action $provider's IP ranges (port $ports/$proto). Continue?" \
        || { echo "Cancelled." >&2; exit 1; }
      require_root "$action" "$provider"
      require_ufw
      do_provider_rule "$action" "$provider" "$ports" "$proto"
      ;;

    trust-ip | untrust-ip)
      local ip
      ip="$(gum input --header "IP address")" || true
      [ -n "$ip" ] || { echo "Cancelled." >&2; exit 1; }
      gum confirm "About to $action $ip (all ports/protocols, both directions). Continue?" \
        || { echo "Cancelled." >&2; exit 1; }
      require_root "$action" "$ip"
      require_ufw
      do_ip_rule "$action" "$ip"
      ;;

    trust-interface | untrust-interface)
      local iface
      iface="$(gum input --header "Interface name" --value "tailscale0")" || true
      [ -n "$iface" ] || { echo "Cancelled." >&2; exit 1; }
      gum confirm "About to $action interface $iface (all ports/protocols, both directions). Continue?" \
        || { echo "Cancelled." >&2; exit 1; }
      require_root "$action" "$iface"
      require_ufw
      do_interface_rule "$action" "$iface"
      ;;
  esac
}

if [ "$#" -eq 0 ]; then
  run_interactive
  exit 0
fi

ACTION="$1"; shift

case "$ACTION" in
  list-providers)
    list_providers
    ;;

  add | remove)
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

    require_root "$ACTION" "$PROVIDER"
    require_ufw
    do_provider_rule "$ACTION" "$PROVIDER" "$PORTS" "$PROTO"
    ;;

  trust-ip | untrust-ip)
    [ "$#" -eq 1 ] || usage
    IP="$1"
    require_root "$ACTION" "$IP"
    require_ufw
    do_ip_rule "$ACTION" "$IP"
    ;;

  trust-interface | untrust-interface)
    [ "$#" -eq 1 ] || usage
    IFACE="$1"
    require_root "$ACTION" "$IFACE"
    require_ufw
    do_interface_rule "$ACTION" "$IFACE"
    ;;

  *)
    usage
    ;;
esac
