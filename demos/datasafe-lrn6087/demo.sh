#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: demo.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-10-19
# Version....: 0.1.0
# Purpose....: LRN6087 (Oracle AI World 2026) Data Safe demo - the five steps
#              of slide 20 with pauses, plus the preparation of the demo state.
# Notes......: Actions:
#                check          isolation and prerequisites (no changes)
#                register-base  register CDB$ROOT + start PDBs, tag, start trails
#                prepare        create AIPDB1 + DS_ADMIN on the host (off-screen)
#                run            the five demo steps (default)
#                step N         one demo step (1-5)
#              Real names come from demo.env (see demo.env.example). The Data
#              Safe secret is read with op read and handed over as a 0600
#              base64 file - never typed, never on an argv.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------
# CHANGE LOG:
# 2026-10-19 oes Initial release 0.1.0
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Default Values
# ------------------------------------------------------------------------------
set -euo pipefail
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="0.1.0"
DRY_RUN="FALSE"
PAUSE="TRUE"
ACTION="run"
STEP=""

# Demo names - overridden by demo.env. Slide placeholders in brackets.
DEMO_ENV_FILE="${DEMO_ENV_FILE:-${SCRIPT_DIR}/demo.env}"
DEMO_TF_DIR="${DEMO_TF_DIR:-${SCRIPT_DIR}/../../terraform/envs/datasafe-demo}"
DEMO_OCI_PROFILE="ACE"
DEMO_REGION="eu-zurich-1"
DEMO_ODB_BASE="${HOME}/demo/odb_datasafe-1.2.1"
DEMO_COMP="lab" # [lab]
DEMO_HOST="db01" # [db01]
DEMO_SID="FREE" # [CDB01] - Oracle AI Database Free only runs as FREE
DEMO_PDB="AIPDB1" # [AIPDB1]
DEMO_BASE_PDBS="FREEPDB1,ODBSEED,ODBREPO"
DEMO_CONNECTOR="dsc-zrh-lab-dsdemo-01"
DEMO_DS_USER="DS_ADMIN"
DEMO_OP_DS_SECRET=""
DEMO_REGISTER_MODE="oci"
DEMO_INFRA_TYPE="ORACLE_CLOUD"
DEMO_LISTENER_PORT="1521"
DEMO_COMP_OCID=""
DEMO_INSTANCE_ID=""
DEMO_DB_IP=""
DEMO_SA=""
DEMO_UA=""
DEMO_FLEET_SOURCE="snapshot"
DEMO_SNAPSHOT="${SCRIPT_DIR}/fleet-snapshot/fleet-snapshot-sample.json"
DEMO_SSH_PORT="${DSDEMO_LOCAL_PORT:-2222}"
DEMO_SSH_KEY=""

WORK_DIR=""

# ------------------------------------------------------------------------------
# usage: show script usage
# ------------------------------------------------------------------------------
usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS] [ACTION]

  LRN6087 Data Safe demo: fleet state, register the AI PDB, tags, audit trail,
  assessments. Names and 1Password references come from demo.env.

Actions:
  check              Verify isolation, tools and names (no changes)
  register-base      Register CDB\$ROOT and ${DEMO_BASE_PDBS}, tag, start trails (once)
  prepare            Create ${DEMO_PDB} and its Data Safe user on the host (before the session)
  run                Run the five demo steps with pauses (default)
  step N             Run one demo step (1-5)

Options:
  -n, --dry-run      Print every command, execute none (rehearsal without OCI)
      --no-pause     Do not wait for Enter between commands (recording)
  -e, --env FILE     Demo configuration (default: ${DEMO_ENV_FILE})
  -h, --help         Show this help and exit
  -V, --version      Show the version

Examples:
  ${SCRIPT_NAME} --dry-run run
  ${SCRIPT_NAME} check
  ${SCRIPT_NAME} prepare && ${SCRIPT_NAME} run
  ${SCRIPT_NAME} step 3

EOF
}

log_info() { echo "$(date '+%H:%M:%S') INFO $*" >&2; }
log_warn() { echo "$(date '+%H:%M:%S') WARN $*" >&2; }
log_error() { echo "$(date '+%H:%M:%S') ERROR $*" >&2; }
die() { log_error "$*"; exit 1; }

# ------------------------------------------------------------------------------
# Function: cleanup
# Purpose.: Remove the temporary work directory (secret files, JSON payloads)
# ------------------------------------------------------------------------------
cleanup() {
    [[ -n "${WORK_DIR}" && -d "${WORK_DIR}" ]] && rm -rf "${WORK_DIR}"
    return 0
}
trap cleanup EXIT INT TERM

# ------------------------------------------------------------------------------
# Function: banner
# Purpose.: Print a step banner
# Args....: $1 title
# Example.: banner "1 - Fleet state"
# ------------------------------------------------------------------------------
banner() {
    printf '\n\033[1m== %s ==\033[0m\n' "$1"
}

# ------------------------------------------------------------------------------
# Function: pause
# Purpose.: Wait for Enter unless --no-pause or --dry-run
# ------------------------------------------------------------------------------
pause() {
    [[ "${PAUSE}" == "TRUE" && "${DRY_RUN}" == "FALSE" ]] || return 0
    read -r -p "  [Enter] " _ < /dev/tty || true
}

# ------------------------------------------------------------------------------
# Function: show_and_run
# Purpose.: Show the command as on the slide, pause, then execute it
# Args....: $1 display text (what the audience sees), $@ command to execute
# Returns.: exit code of the command (0 in dry-run)
# Example.: show_and_run "ds_target_list.sh --count" ds_target_list.sh --count
# ------------------------------------------------------------------------------
show_and_run() {
    local display="$1"
    shift
    printf '\n\033[32m$ %s\033[0m\n' "${display}"
    pause
    if [[ "${DRY_RUN}" == "TRUE" ]]; then
        log_info "DRY-RUN: $*"
        return 0
    fi
    "$@"
}

# ------------------------------------------------------------------------------
# Function: tf_out
# Purpose.: Read one raw Terraform output of the demo stack
# Args....: $1 output name
# Output..: value on stdout (empty when the stack is not deployed)
# Depends.: terraform
# Example.: tf_out db_instance_id
# ------------------------------------------------------------------------------
tf_out() {
    (cd "${DEMO_TF_DIR}" 2> /dev/null && terraform output -raw "$1" 2> /dev/null) || true
}

# ------------------------------------------------------------------------------
# Function: load_config
# Purpose.: Source demo.env, fill OCIDs from terraform output, isolate odb_datasafe
# Depends.: terraform
# ------------------------------------------------------------------------------
load_config() {
    if [[ -f "${DEMO_ENV_FILE}" ]]; then
        # shellcheck source=/dev/null
        . "${DEMO_ENV_FILE}"
    else
        log_warn "No ${DEMO_ENV_FILE} - using the built-in placeholder names"
    fi

    [[ -n "${DEMO_COMP_OCID}" ]] || DEMO_COMP_OCID="$(tf_out compartment_ocid)"
    [[ -n "${DEMO_INSTANCE_ID}" ]] || DEMO_INSTANCE_ID="$(tf_out db_instance_id)"
    [[ -n "${DEMO_DB_IP}" ]] || DEMO_DB_IP="$(tf_out db_private_ip)"
    [[ -n "${DEMO_SSH_KEY}" ]] || DEMO_SSH_KEY="$(tf_out lab_private_key_path)"

    # Isolation: only the demo copy of odb_datasafe and its .env may load.
    # ORADBA_ETC would pull in the everyday datasafe.conf of another tenancy.
    unset ORADBA_ETC ORADBA_BASE DATASAFE_SECRET_FILE
    export ODB_DATASAFE_BASE="${DEMO_ODB_BASE}"
    export OCI_CLI_PROFILE="${DEMO_OCI_PROFILE}"
    export OCI_CLI_REGION="${DEMO_REGION}"
    export DS_ROOT_COMP="${DEMO_COMP_OCID}"
    export PATH="${DEMO_ODB_BASE}/bin:${PATH}"
    export LANG="${LANG:-en_US.UTF-8}"
}

# ------------------------------------------------------------------------------
# Function: check_isolation
# Purpose.: Refuse a configuration that could show another tenancy on screen
# Returns.: 0 ok, exits otherwise
# ------------------------------------------------------------------------------
check_isolation() {
    [[ -x "${DEMO_ODB_BASE}/bin/ds_target_list.sh" ]] \
        || die "odb_datasafe not found in ${DEMO_ODB_BASE} (see docs/datasafe-demo.md, Laptop)"
    [[ ! -f "${DEMO_ODB_BASE}/etc/datasafe.conf" ]] \
        || die "${DEMO_ODB_BASE}/etc/datasafe.conf exists - the demo copy must carry only its .env"
    [[ -f "${DEMO_ODB_BASE}/.env" ]] || die "${DEMO_ODB_BASE}/.env missing (copy odb_datasafe.env.example)"
    if [[ -n "${DEMO_COMP_OCID}" ]] && ! grep -q "${DEMO_COMP_OCID}" "${DEMO_ODB_BASE}/.env"; then
        die "${DEMO_ODB_BASE}/.env does not point at the demo compartment"
    fi
}

# ------------------------------------------------------------------------------
# Function: ds_secret_file
# Purpose.: Read the Data Safe secret from 1Password into a 0600 base64 file
# Output..: path of the file on stdout
# Depends.: op, base64
# ------------------------------------------------------------------------------
ds_secret_file() {
    [[ -n "${DEMO_OP_DS_SECRET}" ]] || die "DEMO_OP_DS_SECRET not set in demo.env"
    local f="${WORK_DIR}/ds_secret.b64"
    if [[ ! -s "${f}" ]]; then
        (umask 077 && op read "${DEMO_OP_DS_SECRET}" | tr -d '\n' | base64 > "${f}") \
            || die "op read failed - run: eval \$(op signin)"
    fi
    printf '%s' "${f}"
}

# ------------------------------------------------------------------------------
# Function: host_ssh
# Purpose.: Run a command on the demo host through the Bastion tunnel
# Args....: $@ remote command
# Depends.: ssh, tunnel.sh (tunnel on 127.0.0.1:DEMO_SSH_PORT)
# Example.: host_ssh sudo dsdemo-pdb list
# ------------------------------------------------------------------------------
host_ssh() {
    ssh -i "${DEMO_SSH_KEY}" -o IdentitiesOnly=yes -o BatchMode=yes \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
        -p "${DEMO_SSH_PORT}" opc@127.0.0.1 "$@"
}

# ------------------------------------------------------------------------------
# Function: target_name
# Purpose.: Display name in the odb_datasafe convention <host>_<sid>_<pdb|CDBROOT>
# Args....: $1 PDB name or CDBROOT
# ------------------------------------------------------------------------------
target_name() {
    printf '%s_%s_%s' "${DEMO_HOST}" "${DEMO_SID}" "${1^^}"
}

# ------------------------------------------------------------------------------
# Function: register_oci
# Purpose.: Register a target with plain OCI CLI (INSTALLED_DATABASE + connector)
# Args....: $1 PDB name or CDBROOT, $2 plan|apply
# Notes...: ds_target_register.sh v1.2.1 builds an ExaCC payload only
#           (DATABASE_CLOUD_SERVICE / CLOUD_AT_CUSTOMER) - see the runbook.
# Depends.: oci, jq
# ------------------------------------------------------------------------------
register_oci() {
    local scope="${1^^}" mode="$2"
    local name service user
    name="$(target_name "${scope}")"
    if [[ "${scope}" == "CDBROOT" ]]; then
        service="${DEMO_SID}"
        user="C##${DEMO_DS_USER}"
    else
        service="${scope,,}"
        user="${DEMO_DS_USER}"
    fi

    local conn_ocid
    conn_ocid="$(oci data-safe on-prem-connector list --compartment-id "${DEMO_COMP_OCID}" \
        --compartment-id-in-subtree true --all --profile "${DEMO_OCI_PROFILE}" \
        --query "data[?\"display-name\"=='${DEMO_CONNECTOR}'].id | [0]" --raw-output 2> /dev/null || true)"
    [[ "${DRY_RUN}" == "TRUE" ]] && conn_ocid="${conn_ocid:-<connector-ocid>}"
    [[ -n "${conn_ocid}" && "${conn_ocid}" != "null" ]] || die "Connector ${DEMO_CONNECTOR} not found"

    jq -n --arg infra "${DEMO_INFRA_TYPE}" --arg inst "${DEMO_INSTANCE_ID}" --arg ip "${DEMO_DB_IP}" \
        --argjson port "${DEMO_LISTENER_PORT}" --arg svc "${service}" '
        {databaseType: "INSTALLED_DATABASE", infrastructureType: $infra,
         ipAddresses: [$ip], listenerPort: $port, serviceName: $svc}
        | if $infra == "ORACLE_CLOUD" then . + {instanceId: $inst} else . end' \
        > "${WORK_DIR}/db.json"
    jq -n --arg c "${conn_ocid}" '{connectionType: "ONPREM_CONNECTOR", onPremConnectorId: $c}' \
        > "${WORK_DIR}/conn.json"

    if [[ "${mode}" == "plan" ]]; then
        echo "Registration plan (dry-run) for ${name}:"
        echo "  compartment: ${DEMO_COMP}"
        echo "  connector..: ${DEMO_CONNECTOR}"
        echo "  user.......: ${user} (secret from vault)"
        jq -c . "${WORK_DIR}/db.json" | sed 's/^/  details....: /'
        return 0
    fi

    local secret_file
    secret_file="$(ds_secret_file)"
    (umask 077 && jq -n --arg u "${user}" --arg p "$(base64 -d < "${secret_file}")" \
        '{userName: $u, password: $p}' > "${WORK_DIR}/cred.json")
    oci data-safe target-database create --profile "${DEMO_OCI_PROFILE}" \
        --compartment-id "${DEMO_COMP_OCID}" --display-name "${name}" \
        --description "LRN6087 demo - ${scope} on ${DEMO_SID} at ${DEMO_HOST}" \
        --database-details "file://${WORK_DIR}/db.json" \
        --connection-option "file://${WORK_DIR}/conn.json" \
        --credentials "file://${WORK_DIR}/cred.json" \
        --wait-for-state SUCCEEDED --wait-for-state FAILED \
        --query 'data.status' --raw-output
    rm -f "${WORK_DIR}/cred.json"
}

# ------------------------------------------------------------------------------
# Function: register_target
# Purpose.: Register one target, plan first or apply, in the chosen mode
# Args....: $1 PDB name or CDBROOT, $2 plan|apply
# ------------------------------------------------------------------------------
register_target() {
    local scope="$1" mode="$2"
    local -a scope_args=(--pdb "${scope}")
    [[ "${scope^^}" == "CDBROOT" ]] && scope_args=(--root)

    if [[ "${DEMO_REGISTER_MODE}" == "odb" ]]; then
        local -a args=(-H "${DEMO_HOST}" --sid "${DEMO_SID}" "${scope_args[@]}" -c "${DEMO_COMP}"
            --connector "${DEMO_CONNECTOR}" --secret-file "$(ds_secret_file)")
        [[ "${mode}" == "plan" ]] && args+=(-n)
        ds_target_register.sh "${args[@]}"
    else
        register_oci "${scope}" "${mode}"
    fi
}

# ------------------------------------------------------------------------------
# Function: target_ocid
# Purpose.: Resolve a target display name to its OCID
# Args....: $1 display name
# Depends.: oci
# ------------------------------------------------------------------------------
target_ocid() {
    oci data-safe target-database list --compartment-id "${DEMO_COMP_OCID}" --all \
        --profile "${DEMO_OCI_PROFILE}" --lifecycle-state ACTIVE \
        --query "data[?\"display-name\"=='$1'].id | [0]" --raw-output 2> /dev/null || true
}

# ------------------------------------------------------------------------------
# Demo steps
# ------------------------------------------------------------------------------
step_1() {
    banner "1 - Fleet state, then what needs attention"
    if [[ "${DEMO_FLEET_SOURCE}" == "snapshot" ]]; then
        [[ -f "${DEMO_SNAPSHOT}" ]] || die "Snapshot ${DEMO_SNAPSHOT} missing"
        echo "  (sample data - synthetic fleet snapshot, no real targets)"
        show_and_run "ds_target_list.sh -A --count" \
            ds_target_list.sh --input-json "${DEMO_SNAPSHOT}" --count
        show_and_run "ds_target_list.sh -A --problems" \
            ds_target_list.sh --input-json "${DEMO_SNAPSHOT}" --problems
    else
        show_and_run "ds_target_list.sh -A --count" ds_target_list.sh -A --count
        show_and_run "ds_target_list.sh -A --problems" ds_target_list.sh -A --problems
    fi
}

step_2() {
    banner "2 - Register the new AI PDB (plan first)"
    local slide="ds_target_register.sh -H ${DEMO_HOST} --sid ${DEMO_SID} --pdb ${DEMO_PDB}"
    show_and_run "${slide} -n" register_target "${DEMO_PDB}" plan
    show_and_run "${slide}" register_target "${DEMO_PDB}" apply
}

step_3() {
    banner "3 - Tags"
    show_and_run "ds_find_untagged_targets.sh -c ${DEMO_COMP}" \
        ds_find_untagged_targets.sh -c "${DEMO_COMP}"
    show_and_run "ds_target_update_tags.sh -c ${DEMO_COMP} -r ${DEMO_PDB}" \
        ds_target_update_tags.sh -c "${DEMO_COMP}" -r "${DEMO_PDB}"
    show_and_run "ds_target_update_tags.sh -c ${DEMO_COMP} -r ${DEMO_PDB} --apply" \
        ds_target_update_tags.sh -c "${DEMO_COMP}" -r "${DEMO_PDB}" --apply
}

step_4() {
    banner "4 - Audit trail: collecting, not just configured"
    show_and_run "ds_audit_trail_state.sh -c ${DEMO_COMP} --state NOT_STARTED,NEEDS_ATTENTION" \
        ds_audit_trail_state.sh -c "${DEMO_COMP}" --state NOT_STARTED,NEEDS_ATTENTION
    show_and_run "ds_target_audit_trail.sh -T $(target_name "${DEMO_PDB}")" \
        ds_target_audit_trail.sh -T "$(target_name "${DEMO_PDB}")"
    show_and_run "ds_audit_trail_state.sh -c ${DEMO_COMP} -r ${DEMO_PDB}" \
        ds_audit_trail_state.sh -c "${DEMO_COMP}" -r "${DEMO_PDB}"
}

step_5() {
    banner "5 - Assessments with the OCI CLI"
    local sa="${DEMO_SA}"
    if [[ -z "${sa}" && "${DRY_RUN}" == "FALSE" ]]; then
        local tid
        tid="$(target_ocid "$(target_name "${DEMO_PDB}")")"
        [[ -n "${tid}" && "${tid}" != "null" ]] || die "Target $(target_name "${DEMO_PDB}") not ACTIVE yet"
        sa="$(oci data-safe security-assessment list --compartment-id "${DEMO_COMP_OCID}" \
            --target-id "${tid}" --type LATEST --all --profile "${DEMO_OCI_PROFILE}" \
            --query 'data[0].id' --raw-output)"
    fi
    sa="${sa:-<latest-security-assessment>}"
    show_and_run "oci data-safe security-assessment refresh --security-assessment-id \$SA" \
        oci data-safe security-assessment refresh --security-assessment-id "${sa}" \
        --profile "${DEMO_OCI_PROFILE}" --wait-for-state SUCCEEDED --query 'data.status' --raw-output
    show_and_run "oci data-safe security-assessment list-findings --security-assessment-id \$SA --severity HIGH" \
        oci data-safe security-assessment list-findings --security-assessment-id "${sa}" \
        --severity HIGH --all --profile "${DEMO_OCI_PROFILE}" \
        --query 'data[].{key:key,title:title,severity:severity}' --output table
    if [[ -n "${DEMO_UA}" ]]; then
        show_and_run "oci data-safe user-assessment list-users --user-assessment-id \$UA" \
            oci data-safe user-assessment list-users --user-assessment-id "${DEMO_UA}" --all \
            --profile "${DEMO_OCI_PROFILE}" --query 'data[].{user:"user-name",type:"user-types"}' --output table
    fi
}

# ------------------------------------------------------------------------------
# Actions
# ------------------------------------------------------------------------------
do_check() {
    local tool
    for tool in oci jq op terraform ssh; do
        command -v "${tool}" > /dev/null || die "Missing tool: ${tool}"
    done
    check_isolation
    echo "Profile: ${DEMO_OCI_PROFILE} (${DEMO_REGION})"
    echo "Compartment: ${DEMO_COMP} ${DEMO_COMP_OCID:+(OCID from terraform)}"
    echo "Target: $(target_name "${DEMO_PDB}") via ${DEMO_CONNECTOR}, mode ${DEMO_REGISTER_MODE}/${DEMO_INFRA_TYPE}"
    echo "Snapshot: ${DEMO_SNAPSHOT}"
    if [[ "${DRY_RUN}" == "FALSE" ]]; then
        ds_target_list.sh --input-json "${DEMO_SNAPSHOT}" --count > /dev/null \
            && echo "Snapshot readable by ds_target_list.sh: ok"
        if host_ssh true; then
            echo "Tunnel to the demo host: ok"
        else
            log_warn "Tunnel down - run make dsdemo-tunnel"
        fi
    fi
}

do_register_base() {
    banner "Register CDB\$ROOT and ${DEMO_BASE_PDBS} (start state)"
    local scope
    local -a scopes=(CDBROOT)
    IFS=',' read -ra pdbs <<< "${DEMO_BASE_PDBS}"
    scopes+=("${pdbs[@]}")
    for scope in "${scopes[@]}"; do
        show_and_run "register $(target_name "${scope}")" register_target "${scope}" apply
    done
    show_and_run "ds_target_update_tags.sh -c ${DEMO_COMP} --apply" \
        ds_target_update_tags.sh -c "${DEMO_COMP}" --apply
    show_and_run "ds_target_audit_trail.sh -c ${DEMO_COMP} -L ACTIVE" \
        ds_target_audit_trail.sh -c "${DEMO_COMP}" -L ACTIVE
}

# ------------------------------------------------------------------------------
# Function: prereqs_remote
# Purpose.: Create the Data Safe user in a PDB on the host, secret via stdin
# Args....: $1 PDB name
# Depends.: op, ssh
# ------------------------------------------------------------------------------
prereqs_remote() {
    local secret_file
    secret_file="$(ds_secret_file)"
    base64 -d < "${secret_file}" | host_ssh sudo /usr/local/bin/dsdemo-pdb prereqs --pdb "$1"
}

do_prepare() {
    banner "Prepare ${DEMO_PDB} on the demo host (off-screen)"
    show_and_run "sudo dsdemo-pdb create ${DEMO_PDB}" host_ssh sudo /usr/local/bin/dsdemo-pdb create "${DEMO_PDB}"
    show_and_run "sudo dsdemo-pdb prereqs --pdb ${DEMO_PDB} < secret" prereqs_remote "${DEMO_PDB}"
    show_and_run "sudo dsdemo-pdb check --pdb ${DEMO_PDB}" host_ssh sudo /usr/local/bin/dsdemo-pdb check --pdb "${DEMO_PDB}"
}

# ------------------------------------------------------------------------------
# Parse arguments
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n | --dry-run) DRY_RUN="TRUE"; shift ;;
        --no-pause) PAUSE="FALSE"; shift ;;
        -e | --env) DEMO_ENV_FILE="$2"; shift 2 ;;
        -h | --help) usage; exit 0 ;;
        -V | --version) echo "${SCRIPT_NAME} ${VERSION}"; exit 0 ;;
        check | register-base | prepare | run) ACTION="$1"; shift ;;
        step) ACTION="step"; STEP="${2:-}"; shift 2 || die "step needs a number 1-5" ;;
        *) log_error "Unknown option $1"; usage; exit 1 ;;
    esac
done

# ------------------------------------------------------------------------------
# main
# ------------------------------------------------------------------------------
main() {
    load_config
    WORK_DIR="$(umask 077 && mktemp -d "${TMPDIR:-/tmp}/dsdemo.XXXXXX")"
    [[ "${ACTION}" == "check" ]] || check_isolation
    [[ "${DRY_RUN}" == "TRUE" ]] && log_info "DRY-RUN - commands are printed, not executed"

    case "${ACTION}" in
        check) do_check ;;
        register-base) do_register_base ;;
        prepare) do_prepare ;;
        run)
            step_1
            step_2
            step_3
            step_4
            step_5
            banner "Done - console contrast: same target in the Data Safe UI"
            ;;
        step)
            [[ "${STEP}" =~ ^[1-5]$ ]] || die "step needs a number 1-5"
            "step_${STEP}"
            ;;
    esac
}

main "$@"
# --- EOF ----------------------------------------------------------------------
