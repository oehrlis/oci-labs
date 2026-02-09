#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: clean.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Remove Terraform metadata (.terraform folders, lock files) across
#              the repository.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR%/tools}"

echo "=== Cleaning .terraform folders under ${REPO_ROOT} ==="

find "${REPO_ROOT}" -type d -name ".terraform" -print -exec rm -rf {} +

echo "=== Cleaning .terraform.lock.hcl files ==="

find "${REPO_ROOT}" -type f -name ".terraform.lock.hcl" -print -exec rm -f {} +

echo
echo "Cleanup done."

# --- EOF ----------------------------------------------------------------------
