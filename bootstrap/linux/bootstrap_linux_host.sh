#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: bootstrap_linux_host.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Minimal cloud-init bootstrap for Linux lab hosts to prepare
#              folders and log bootstrap status.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------
set -euo pipefail

LOGFILE="/var/log/lab-bootstrap.log"
STATUSFILE="/var/lib/lab-bootstrap/status"

mkdir -p "$(dirname "${LOGFILE}")" "$(dirname "${STATUSFILE}")"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2" | tee -a "${LOGFILE}"
}

PROFILE_TYPE="unknown"
PROFILE_NAME="unknown"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type) PROFILE_TYPE="$2"; shift 2 ;;
    --profile) PROFILE_NAME="$2"; shift 2 ;;
    *) shift ;;
  esac
done

echo "RUNNING" > "${STATUSFILE}"
log INFO "Bootstrap starting: type=${PROFILE_TYPE}, profile=${PROFILE_NAME}"

log INFO "Preparing simple folder layout"
mkdir -p /u01/app
mkdir -p /u02

log INFO "Listing block devices for inspection:"
lsblk | tee -a "${LOGFILE}"

log INFO "Bootstrap finished (no DB setup)."
echo "OK" > "${STATUSFILE}"

# --- EOF ----------------------------------------------------------------------
