#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: validate.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Run terraform fmt/validate per stack and optional linters for the
#              OCI lab repository.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR%/tools}"
INFRA_DIR="${REPO_ROOT}/infra"
STACKS_DIR="${INFRA_DIR}/stacks"
BOOTSTRAP_LINUX_DIR="${REPO_ROOT}/bootstrap/linux"

echo "=== terraform fmt (recursive) ==="
terraform fmt -recursive "${INFRA_DIR}"

echo
echo "=== terraform validate per stack ==="

for STACK_PATH in "${STACKS_DIR}"/*; do
  [[ ! -d "${STACK_PATH}" ]] && continue

  echo
  echo "--- Validating stack: ${STACK_PATH} ---"

  # Remove old terraform metadata
  if [[ -d "${STACK_PATH}/.terraform" ]]; then
    echo "Cleaning ${STACK_PATH}/.terraform/"
    rm -rf "${STACK_PATH}/.terraform"
  fi

  if [[ -f "${STACK_PATH}/.terraform.lock.hcl" ]]; then
    echo "Removing ${STACK_PATH}/.terraform.lock.hcl"
    rm -f "${STACK_PATH}/.terraform.lock.hcl"
  fi

  (
    cd "${STACK_PATH}"
    terraform init -backend=false >/dev/null
    terraform validate
  )
done

echo
echo "--- Optional linters ---"

if command -v tflint >/dev/null; then
  echo "Running tflint..."
  (cd "${INFRA_DIR}" && tflint)
else
  echo "tflint not installed – skipping"
fi

if command -v shellcheck >/dev/null; then
  echo "Running shellcheck..."
  find "${BOOTSTRAP_LINUX_DIR}" -maxdepth 1 -name "*.sh" -print0 | xargs -0 -r shellcheck
else
  echo "shellcheck not installed – skipping"
fi

echo
echo "Validation OK."

# --- EOF ----------------------------------------------------------------------
