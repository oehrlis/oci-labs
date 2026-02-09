#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: upload_bootstrap.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Package bootstrap/linux into a tar.gz and upload it to OCI Object
#              Storage using the OCI CLI.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------
set -euo pipefail

# Package bootstrap/linux into a tar.gz and upload it to an OCI Object Storage
# bucket using the OCI CLI.
#
# Usage:
#   tools/upload_bootstrap.sh -b <bucket-name> [-n <object-name>] [-p <oci-
#   profile>] [-N <namespace>] [-r <region>]
#
# Example:
#   tools/upload_bootstrap.sh -b tvd-cpureport -N trivadisbdsxsp -r eu-zurich-1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR%/tools}"

BUCKET_NAME=""
OBJECT_NAME="bootstrap_linux.tar.gz"
OCI_PROFILE=""
NAMESPACE=""   # optional explicit namespace
REGION=""      # optional explicit region
BOOTSTRAP_DIR="${REPO_ROOT}/bootstrap/linux"
DIST_DIR="${REPO_ROOT}/dist"

usage() {
  echo "Usage: $(basename "$0") -b <bucket-name> [-n <object-name>] [-p <oci-profile>] [-N <namespace>] [-r <region>]" >&2
  exit 1
}

while getopts ":b:n:p:N:r:" opt; do
  case "${opt}" in
    b) BUCKET_NAME="${OPTARG}" ;;
    n) OBJECT_NAME="${OPTARG}" ;;
    p) OCI_PROFILE="${OPTARG}" ;;
    N) NAMESPACE="${OPTARG}" ;;
    r) REGION="${OPTARG}" ;;
    *) usage ;;
  esac
done

if [[ -z "${BUCKET_NAME}" ]]; then
  echo "ERROR: -b <bucket-name> is required" >&2
  usage
fi

if [[ ! -d "${BOOTSTRAP_DIR}" ]]; then
  echo "ERROR: Bootstrap directory not found: ${BOOTSTRAP_DIR}" >&2
  exit 1
fi

if ! command -v oci >/dev/null 2>&1; then
  echo "ERROR: OCI CLI (oci) not found in PATH" >&2
  exit 1
fi

mkdir -p "${DIST_DIR}"
TAR_FILE="${DIST_DIR}/bootstrap_linux.tar.gz"

echo "Packaging bootstrap from ${BOOTSTRAP_DIR} -> ${TAR_FILE}"
tar czf "${TAR_FILE}" -C "${BOOTSTRAP_DIR}/.." linux

OCI_CMD=(oci)
if [[ -n "${OCI_PROFILE}" ]]; then
  OCI_CMD+=(--profile "${OCI_PROFILE}")
fi
if [[ -n "${REGION}" ]]; then
  OCI_CMD+=(--region "${REGION}")
fi

# Determine namespace if not explicitly provided
if [[ -z "${NAMESPACE}" ]]; then
  echo "Trying to auto-detect Object Storage namespace via 'oci os ns get'..."
  if NAMESPACE_DETECTED="$("${OCI_CMD[@]}" os ns get --query 'data' --raw-output 2>/dev/null)"; then
    if [[ -n "${NAMESPACE_DETECTED}" ]]; then
      NAMESPACE="${NAMESPACE_DETECTED}"
      echo "Detected namespace: ${NAMESPACE}"
    else
      echo "ERROR: Could not detect namespace (empty response). Use -N <namespace>." >&2
      exit 1
    fi
  else
    echo "ERROR: Unable to auto-detect namespace. Please rerun with -N <namespace>." >&2
    exit 1
  fi
else
  echo "Using explicitly provided namespace: ${NAMESPACE}"
fi

echo "Uploading ${TAR_FILE} to bucket '${BUCKET_NAME}' (namespace '${NAMESPACE}', region '${REGION:-from-config}') as object '${OBJECT_NAME}'"

"${OCI_CMD[@]}" os object put \
  --namespace-name "${NAMESPACE}" \
  --bucket-name "${BUCKET_NAME}" \
  --file "${TAR_FILE}" \
  --name "${OBJECT_NAME}" \
  --force

echo "Upload completed."
echo "Object: namespace='${NAMESPACE}', bucket='${BUCKET_NAME}', name='${OBJECT_NAME}', region='${REGION:-from-config}'"

# --- EOF ----------------------------------------------------------------------
