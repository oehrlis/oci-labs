#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: build_all.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Build and validate the OCI lab artifacts: upload bootstrap,
#              package Terraform stacks, and run validations.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------
set -euo pipefail

# Build & validate everything needed for a lab:
# 1) Package & upload bootstrap (bootstrap/linux -> Object Storage)
# 2) Build stack ZIP(s) under infra/stacks/
# 3) Run validate.sh
#
# Usage:
#   tools/build_all.sh -b <bucket-name> [-n <object-name>] [-p <oci-profile>]
#                      [-N <namespace>] [-r <region>] [stack...]
#
# If no stack-name is given, 'lab-db19c-baseline' is used by default.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR%/tools}"

BUCKET_NAME=""
OBJECT_NAME="bootstrap_linux.tar.gz"
OCI_PROFILE=""
NAMESPACE=""
REGION=""
STACKS=()

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") -b <bucket-name> [-n <object-name>] [-p <oci-profile>] [-N <namespace>] [-r <region>] [stack-name...]

If no stack-name is given, 'lab-db19c-baseline' is used by default.
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -b)
      BUCKET_NAME="$2"
      shift 2
      ;;
    -n)
      OBJECT_NAME="$2"
      shift 2
      ;;
    -p)
      OCI_PROFILE="$2"
      shift 2
      ;;
    -N)
      NAMESPACE="$2"
      shift 2
      ;;
    -r)
      REGION="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      ;;
    *)
      STACKS+=("$1")
      shift
      ;;
  esac
done

if [[ -z "${BUCKET_NAME}" ]]; then
  echo "ERROR: -b <bucket-name> is required" >&2
  usage
fi

if [[ ${#STACKS[@]} -eq 0 ]]; then
  STACKS=("lab-db19c-baseline")
fi

UPLOAD_SCRIPT="${REPO_ROOT}/tools/upload_bootstrap.sh"
BUILD_STACK_SCRIPT="${REPO_ROOT}/tools/build_stack_zip.sh"
VALIDATE_SCRIPT="${REPO_ROOT}/tools/validate.sh"

for s in "${UPLOAD_SCRIPT}" "${BUILD_STACK_SCRIPT}" "${VALIDATE_SCRIPT}"; do
  if [[ ! -x "${s}" ]]; then
    echo "ERROR: required script not found or not executable: ${s}" >&2
    exit 1
  fi
done

echo "=== Step 1: upload bootstrap to bucket '${BUCKET_NAME}' as '${OBJECT_NAME}' ==="

UPLOAD_ARGS=(-b "${BUCKET_NAME}" -n "${OBJECT_NAME}")
if [[ -n "${OCI_PROFILE}" ]]; then
  UPLOAD_ARGS+=(-p "${OCI_PROFILE}")
fi
if [[ -n "${NAMESPACE}" ]]; then
  UPLOAD_ARGS+=(-N "${NAMESPACE}")
fi
if [[ -n "${REGION}" ]]; then
  UPLOAD_ARGS+=(-r "${REGION}")
fi

"${UPLOAD_SCRIPT}" "${UPLOAD_ARGS[@]}"

echo
echo "=== Step 2: build stack zip(s) for: ${STACKS[*]} ==="
"${BUILD_STACK_SCRIPT}" "${STACKS[@]}"

echo
echo "=== Step 3: validate Terraform & bootstrap scripts ==="
"${VALIDATE_SCRIPT}"

echo
echo "All done."
echo "Stack ZIPs are located in:"
for STACK in "${STACKS[@]}"; do
  echo "  - infra/stacks/${STACK}/${STACK}_stack.zip"
done
echo
echo "Remember to set 'bootstrap_url' in your stack variables to the URL of:"
echo "  bucket: ${BUCKET_NAME}"
echo "  object: ${OBJECT_NAME}"
echo "  namespace: ${NAMESPACE:-<see oci os ns get>}"
echo "  region: ${REGION:-<from OCI config>}"

# --- EOF ----------------------------------------------------------------------
