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

log_init() {
    LOG_FILE=${1:-"script-$(date +%Y%m%d-%H%M%S).log"}
    echo "Logging to $LOG_FILE"
    exec > >(tee -a "$LOG_FILE") 2>&1
}

log_header() {
    echo -e "\n\033[1;36m===== $1 =====\033[0m"
}

log_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

log_step() {
    echo -e "\033[1;33m[STEP]\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

log_warning() {
    echo -e "\033[1;35m[WARNING]\033[0m $1" >&2
}

log_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
}