#!/usr/bin/env bash
# Provider for setup-firewall.sh: Cloudflare's published edge IP ranges.
# Source: https://www.cloudflare.com/ips/
#
# fetch_ips prints one CIDR per line (IPv4 + IPv6) to stdout.
fetch_ips() {
  curl -fsSL https://www.cloudflare.com/ips-v4 || return 1
  echo # ips-v4 has no trailing newline -- without this its last CIDR runs
       # straight into ips-v6's first one on the same line.
  curl -fsSL https://www.cloudflare.com/ips-v6 || return 1
}
