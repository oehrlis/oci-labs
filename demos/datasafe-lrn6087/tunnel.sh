#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: tunnel.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-10-19
# Version....: 0.2.0
# Purpose....: Open an OCI Bastion port-forwarding tunnel to the LRN6087 demo
#              host (SSH on 127.0.0.1:<port>).
# Notes......: Reads bastion_id, db_private_ip and lab_private_key_path from
#              terraform/envs/datasafe-demo, the OCI profile from its .env
#              (TF_VAR_oci_config_profile). A listening port is no proof - the
#              tunnel is probed with a real SSH command.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------
# CHANGE LOG:
# 2026-10-19 oes Initial release 0.1.0
# 2026-10-25 oes 0.2.0 restart ssh while the session key propagates
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Default Values
# ------------------------------------------------------------------------------
set -euo pipefail
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="0.2.0"
ENV_DIR="${DSDEMO_ENV_DIR:-${SCRIPT_DIR}/../../terraform/envs/datasafe-demo}"
LOCAL_PORT="${DSDEMO_LOCAL_PORT:-2222}"
SESSION_TTL="${DSDEMO_SESSION_TTL:-10800}"
TUNNEL_ATTEMPTS="${DSDEMO_TUNNEL_ATTEMPTS:-40}"
DRY_RUN="FALSE"
ACTION="open"

# ------------------------------------------------------------------------------
# usage: show script usage
# ------------------------------------------------------------------------------
usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

  Open (or check / close) the Bastion SSH tunnel to the Data Safe demo host.

Options:
  -p, --port PORT     Local port (default: ${LOCAL_PORT})
  -c, --check         Only probe the tunnel (exit 1 when unusable)
      --close         Close the local tunnel process
  -n, --dry-run       Show the OCI and SSH commands, change nothing
  -h, --help          Show this help and exit
  -V, --version       Show the version

Examples:
  ${SCRIPT_NAME} --dry-run
  ${SCRIPT_NAME}
  ssh -i <key> -o IdentitiesOnly=yes -p ${LOCAL_PORT} opc@127.0.0.1

EOF
}

log_info() { echo "$(date '+%Y-%m-%d %H:%M:%S') INFO $*"; }
log_error() { echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR $*" >&2; }

# ------------------------------------------------------------------------------
# Function: tf_out
# Purpose.: Read one raw Terraform output of the demo stack
# Args....: $1 output name
# Output..: value on stdout
# Depends.: terraform
# Example.: tf_out bastion_id
# ------------------------------------------------------------------------------
tf_out() {
    (cd "${ENV_DIR}" && terraform output -raw "$1")
}

# ------------------------------------------------------------------------------
# Function: probe
# Purpose.: Run a real command through the tunnel
# Args....: $1 private key path
# Returns.: 0 usable, 1 not usable
# Depends.: ssh
# Example.: probe ~/.ssh/key
# ------------------------------------------------------------------------------
probe() {
    ssh -i "$1" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=8 \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
        -p "${LOCAL_PORT}" opc@127.0.0.1 true 2> /dev/null
}

# ------------------------------------------------------------------------------
# Parse arguments
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p | --port) LOCAL_PORT="$2"; shift 2 ;;
        -c | --check) ACTION="check"; shift ;;
        --close) ACTION="close"; shift ;;
        -n | --dry-run) DRY_RUN="TRUE"; shift ;;
        -h | --help) usage; exit 0 ;;
        -V | --version) echo "${SCRIPT_NAME} ${VERSION}"; exit 0 ;;
        *) log_error "Unknown option $1"; usage; exit 1 ;;
    esac
done

# ------------------------------------------------------------------------------
# main
# ------------------------------------------------------------------------------
main() {
    if [[ "${ACTION}" == "close" ]]; then
        if pkill -f "L ${LOCAL_PORT}:" 2> /dev/null; then
            log_info "Tunnel on ${LOCAL_PORT} closed"
        else
            log_info "No tunnel process on ${LOCAL_PORT}"
        fi
        return 0
    fi

    [[ -f "${ENV_DIR}/.env" ]] || { log_error "${ENV_DIR}/.env missing"; exit 1; }
    set -a
    # shellcheck source=/dev/null
    . "${ENV_DIR}/.env"
    set +a
    local profile="${TF_VAR_oci_config_profile:-DEFAULT}"

    local key bastion ip
    key="$(tf_out lab_private_key_path)"
    bastion="$(tf_out bastion_id)"
    ip="$(tf_out db_private_ip)"
    [[ -n "${bastion}" && "${bastion}" != "null" ]] || { log_error "No Bastion in the stack (enable_bastion)"; exit 1; }

    if probe "${key}"; then
        log_info "Tunnel usable on 127.0.0.1:${LOCAL_PORT}"
        return 0
    fi
    [[ "${ACTION}" == "check" ]] && { log_error "Tunnel on 127.0.0.1:${LOCAL_PORT} not usable"; exit 1; }

    if [[ "${DRY_RUN}" == "TRUE" ]]; then
        log_info "DRY-RUN: oci --profile ${profile} bastion session create-port-forwarding --bastion-id <bastion> --target-private-ip ${ip} --target-port 22 --ssh-public-key-file ${key}.pub --session-ttl ${SESSION_TTL}"
        log_info "DRY-RUN: ssh -N -L ${LOCAL_PORT}:${ip}:22 -p 22 <session>@host.bastion.<region>.oci.oraclecloud.com (background)"
        return 0
    fi

    log_info "Creating a Bastion session for ${ip}:22 (profile ${profile})"
    local sid cmd
    sid="$(oci --profile "${profile}" bastion session create-port-forwarding \
        --bastion-id "${bastion}" --target-private-ip "${ip}" --target-port 22 \
        --ssh-public-key-file "${key}.pub" --session-ttl "${SESSION_TTL}" \
        --display-name "dsdemo-$(date +%H%M%S)" \
        --wait-for-state SUCCEEDED --query 'data.resources[0].identifier' --raw-output)"
    [[ -n "${sid}" ]] || { log_error "Session creation failed"; exit 1; }
    cmd="$(oci --profile "${profile}" bastion session get --session-id "${sid}" \
        --query 'data."ssh-metadata".command' --raw-output)"
    cmd="${cmd//<privateKey>/${key}}"
    cmd="${cmd//<localPort>/${LOCAL_PORT}}"

    pkill -f "L ${LOCAL_PORT}:" 2> /dev/null || true

    # A new session is ACTIVE before its key has reached the Bastion host - ssh
    # then exits with "Permission denied (publickey)". Restart ssh until it holds.
    local i starts=0
    for i in $(seq 1 "${TUNNEL_ATTEMPTS}"); do
        if ! pgrep -f "L ${LOCAL_PORT}:" > /dev/null 2>&1; then
            starts=$((starts + 1))
            [[ ${starts} -gt 1 ]] && log_info "ssh to the Bastion exited ($(tail -1 "${ENV_DIR}/.bastion-tunnel.log" 2> /dev/null | sed 's/.*: //')) - start ${starts}"
            nohup bash -c "${cmd} -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes" \
                > "${ENV_DIR}/.bastion-tunnel.log" 2>&1 &
        fi
        sleep 6
        if probe "${key}"; then
            log_info "Tunnel up on 127.0.0.1:${LOCAL_PORT} (check ${i}, ssh start ${starts})"
            return 0
        fi
    done
    log_error "Tunnel did not come up after $((TUNNEL_ATTEMPTS * 6)) s and ${starts} ssh starts - see ${ENV_DIR}/.bastion-tunnel.log"
    log_error "The session ${sid} stays valid for ${SESSION_TTL} s - rerun to try again"
    exit 1
}

main "$@"
# --- EOF ----------------------------------------------------------------------
