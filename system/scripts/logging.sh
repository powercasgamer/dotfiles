#!/usr/bin/env bash
# Dotfiles logging utilities

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
function info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

function success() {
  echo -e "${GREEN}[✓]${NC} $*"
}

function warning() {
  echo -e "${YELLOW}[!]${NC} $*" >&2
}

function error() {
  echo -e "${RED}[✗]${NC} $*" >&2
  exit 1
}