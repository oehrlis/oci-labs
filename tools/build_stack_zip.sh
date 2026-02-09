#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: build_stack_zip.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Build zip archives for one or more Terraform stacks under
#              infra/stacks/.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------
set -euo pipefail

# Build a zip archive for one or more Terraform stacks under infra/stacks/
#
# Usage:
#   tools/build_stack_zip.sh lab-db19c-baseline [another-stack]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR%/tools}"

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <stack-name> [<stack-name>...]" >&2
  exit 1
fi

for STACK_NAME in "$@"; do
  STACK_PATH="${REPO_ROOT}/infra/stacks/${STACK_NAME}"

  if [[ ! -d "${STACK_PATH}" ]]; then
    echo "ERROR: Stack directory not found: ${STACK_PATH}" >&2
    exit 1
  fi

  ZIP_NAME="${STACK_NAME}_stack.zip"

  echo
  echo "=== Preparing stack ${STACK_NAME} ==="

  # Clean Terraform metadata inside the stack
  if [[ -d "${STACK_PATH}/.terraform" ]]; then
    echo " - Removing ${STACK_PATH}/.terraform/"
    rm -rf "${STACK_PATH}/.terraform"
  fi

  if [[ -f "${STACK_PATH}/.terraform.lock.hcl" ]]; then
    echo " - Removing ${STACK_PATH}/.terraform.lock.hcl"
    rm -f "${STACK_PATH}/.terraform.lock.hcl"
  fi

  echo " - Creating ZIP: ${ZIP_NAME}"

  (
    cd "${STACK_PATH}"
    rm -f "${ZIP_NAME}"
    # Exclude obvious junk
    zip -r "${ZIP_NAME}" . \
      -x "*.terraform*" \
      -x "*.zip" \
      >/dev/null
  )

  echo " - Created: ${STACK_PATH}/${ZIP_NAME}"
done

# --- EOF ----------------------------------------------------------------------
