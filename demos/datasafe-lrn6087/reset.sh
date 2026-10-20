#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: reset.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-10-20
# Version....: 0.2.0
# Purpose....: Reset the LRN6087 demo to its start state: deregister the AI PDB
#              target (with audit trail and assessments) and drop the PDB in
#              CDB26.
# Notes......: Dry-run by default - nothing changes without --apply. Names come
#              from demo.env like in demo.sh. The base targets (CDB$ROOT and
#              PDBs of CDB19 and CDB26) and the connector stay untouched;
#              dsdemo-pdb on the host refuses to drop a start PDB.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------
# CHANGE LOG:
# 2026-10-19 oes Initial release 0.1.0
# 2026-10-20 oes 0.2.0 native CDB26 instead of the Free container
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Default Values
# ------------------------------------------------------------------------------
set -euo pipefail
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="0.2.0"
DRY_RUN="TRUE"
FORCE_YES="FALSE"
KEEP_PDB="FALSE"

DEMO_ENV_FILE="${DEMO_ENV_FILE:-${SCRIPT_DIR}/demo.env}"
DEMO_TF_DIR="${DEMO_TF_DIR:-${SCRIPT_DIR}/../../terraform/envs/datasafe-demo}"
DEMO_OCI_PROFILE="ACE"
DEMO_REGION="eu-zurich-1"
DEMO_ODB_BASE="${HOME}/demo/odb_datasafe-1.2.1"
DEMO_COMP="lab"
DEMO_HOST="db01"
DEMO_CDB26="CDB26"
DEMO_PDB="AIPDB1"
DEMO_COMP_OCID=""
DEMO_SSH_PORT="${DSDEMO_LOCAL_PORT:-2222}"
DEMO_SSH_KEY=""

# ------------------------------------------------------------------------------
# usage: show script usage
# ------------------------------------------------------------------------------
usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

  Bring the Data Safe demo back to its start state: delete the target
  <host>_${DEMO_CDB26}_${DEMO_PDB} in Data Safe, then drop ${DEMO_PDB} in ${DEMO_CDB26}.
  Default is a dry-run.

Options:
      --apply        Execute the reset (default: dry-run only)
  -n, --dry-run      Show what would be done (default)
  -y, --yes          No confirmation prompt with --apply
      --keep-pdb     Deregister only, keep the PDB
  -e, --env FILE     Demo configuration (default: ${DEMO_ENV_FILE})
  -h, --help         Show this help and exit
  -V, --version      Show the version

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --apply
  ${SCRIPT_NAME} --apply --yes --keep-pdb

EOF
}

log_info() { echo "$(date '+%H:%M:%S') INFO $*"; }
log_error() { echo "$(date '+%H:%M:%S') ERROR $*" >&2; }
die() { log_error "$*"; exit 1; }

# ------------------------------------------------------------------------------
# Function: tf_out
# Purpose.: Read one raw Terraform output of the demo stack
# Args....: $1 output name
# Depends.: terraform
# ------------------------------------------------------------------------------
tf_out() {
    (cd "${DEMO_TF_DIR}" 2> /dev/null && terraform output -raw "$1" 2> /dev/null) || true
}

# ------------------------------------------------------------------------------
# Function: host_ssh
# Purpose.: Run a command on the demo host through the Bastion tunnel
# Args....: $@ remote command
# Depends.: ssh
# ------------------------------------------------------------------------------
host_ssh() {
    ssh -i "${DEMO_SSH_KEY}" -o IdentitiesOnly=yes -o BatchMode=yes \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
        -p "${DEMO_SSH_PORT}" opc@127.0.0.1 "$@"
}

# ------------------------------------------------------------------------------
# Parse arguments
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply) DRY_RUN="FALSE"; shift ;;
        -n | --dry-run) DRY_RUN="TRUE"; shift ;;
        -y | --yes) FORCE_YES="TRUE"; shift ;;
        --keep-pdb) KEEP_PDB="TRUE"; shift ;;
        -e | --env) DEMO_ENV_FILE="$2"; shift 2 ;;
        -h | --help) usage; exit 0 ;;
        -V | --version) echo "${SCRIPT_NAME} ${VERSION}"; exit 0 ;;
        *) log_error "Unknown option $1"; usage; exit 1 ;;
    esac
done

# ------------------------------------------------------------------------------
# main
# ------------------------------------------------------------------------------
main() {
    if [[ -f "${DEMO_ENV_FILE}" ]]; then
        # shellcheck source=/dev/null
        . "${DEMO_ENV_FILE}"
    fi
    [[ -n "${DEMO_COMP_OCID}" ]] || DEMO_COMP_OCID="$(tf_out compartment_ocid)"
    [[ -n "${DEMO_SSH_KEY}" ]] || DEMO_SSH_KEY="$(tf_out lab_private_key_path)"

    # Same isolation as demo.sh - never the everyday odb_datasafe configuration.
    unset ORADBA_ETC ORADBA_BASE
    export ODB_DATASAFE_BASE="${DEMO_ODB_BASE}"
    export OCI_CLI_PROFILE="${DEMO_OCI_PROFILE}" OCI_CLI_REGION="${DEMO_REGION}"
    export DS_ROOT_COMP="${DEMO_COMP_OCID}"
    export PATH="${DEMO_ODB_BASE}/bin:${PATH}"
    [[ -x "${DEMO_ODB_BASE}/bin/ds_target_delete.sh" ]] || die "odb_datasafe not found in ${DEMO_ODB_BASE}"
    [[ ! -f "${DEMO_ODB_BASE}/etc/datasafe.conf" ]] || die "${DEMO_ODB_BASE}/etc/datasafe.conf exists - refusing"

    local target="${DEMO_HOST}_${DEMO_CDB26^^}_${DEMO_PDB^^}"
    log_info "Reset target ${target} in ${DEMO_COMP}$([[ "${KEEP_PDB}" == "TRUE" ]] || echo ", drop PDB ${DEMO_PDB}")"

    if [[ "${DRY_RUN}" == "TRUE" ]]; then
        log_info "DRY-RUN - nothing changes. Re-run with --apply."
        ds_target_delete.sh -T "${target}" -c "${DEMO_COMP}" -s ACTIVE,NEEDS_ATTENTION,INACTIVE --dry-run
        if [[ "${KEEP_PDB}" == "FALSE" ]]; then
            host_ssh sudo /usr/local/bin/dsdemo-pdb --db "${DEMO_CDB26}" --dry-run drop "${DEMO_PDB}" \
                || log_info "DRY-RUN: would drop ${DEMO_PDB} on the host (tunnel down, not checked)"
        fi
        return 0
    fi

    if [[ "${FORCE_YES}" == "FALSE" ]]; then
        local answer
        read -r -p "Delete Data Safe target ${target} and drop ${DEMO_PDB}? Type 'reset': " answer
        [[ "${answer}" == "reset" ]] || die "Aborted"
    fi

    ds_target_delete.sh -T "${target}" -c "${DEMO_COMP}" -s ACTIVE,NEEDS_ATTENTION,INACTIVE \
        --force --wait-state SUCCEEDED
    if [[ "${KEEP_PDB}" == "FALSE" ]]; then
        host_ssh sudo /usr/local/bin/dsdemo-pdb --db "${DEMO_CDB26}" drop "${DEMO_PDB}"
    fi
    log_info "Start state restored. Next: demo.sh run (step 2 creates ${DEMO_PDB} again)"
}

main "$@"
# --- EOF ----------------------------------------------------------------------
