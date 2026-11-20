#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: bastion-tunnel-supervisor.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.11.20
# Version....: v0.1.0
# Purpose....: Keep a Bastion port-forwarding tunnel up for as long as a lab run
#              needs it: restart the ssh when it exits, renew the Bastion
#              session before its TTL ends, stop when the owner process is gone.
# Usage......: bastion-tunnel-supervisor.sh <env-dir> <ttl-s> <renew-before-s> \
#                  -- <command that writes a fresh .bastion-tunnel.cmd>
# Notes......: Started in the background by "make cpu-lab-bastion-tunnel"; it
#              writes its pid to <env-dir>/.bastion-tunnel.pid, and the Makefile
#              stops it through that file. BASTION_OWNER_PID (lab_run.sh) ends
#              the supervisor once that process is gone - even when it was
#              killed hard and ran no trap.
#              Why (2026-11-19/20): a restart loop alone kept the tunnel through
#              ten network drops, then the three hour session expired mid-step
#              ("Permission denied (publickey)" on every restart), and the loop
#              ran on for a day after its run had ended.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
set -euo pipefail

SSH_OPTS="-o StrictHostKeyChecking=no -o IdentitiesOnly=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes"
POLL=10
MAX_RENEW_FAILS=5
# An ssh that dies this many times in a row within FAST_EXIT seconds of its start
# has no session to talk to (expired while the Mac slept, deleted by the
# Bastion): renew instead of retrying the same dead session.
FAST_EXIT=30
MAX_FAST_EXITS=6

log() { echo "$(date '+%F %T') $*"; }
mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1"; }

[[ $# -ge 4 && "$4" == "--" ]] || { echo "usage: $0 <env-dir> <ttl-s> <renew-before-s> -- <renew command>" >&2; exit 2; }
env_dir="$1" ttl="$2" renew_before="$3"
shift 4
cd "${env_dir}"
echo $$ > .bastion-tunnel.pid

ssh_pid=""
stop_ssh() {
    if [[ -n "${ssh_pid}" ]]; then
        kill "${ssh_pid}" 2>/dev/null || true
        wait "${ssh_pid}" 2>/dev/null || true
    fi
    ssh_pid=""
}
trap 'stop_ssh; rm -f .bastion-tunnel.pid' EXIT
trap 'exit 0' TERM INT

renew_fails=0
fast_exits=0
ssh_start=0
renew_session() {
    log "renewing the Bastion session"
    if "$@" >/dev/null 2>&1; then
        renew_fails=0
        return 0
    fi
    renew_fails=$((renew_fails + 1))
    log "session renewal failed (${renew_fails}/${MAX_RENEW_FAILS})"
    if [[ ${renew_fails} -ge ${MAX_RENEW_FAILS} ]]; then
        log "giving up - the tunnel stays down"
        exit 1
    fi
    return 1
}

log "supervisor up (pid $$, owner ${BASTION_OWNER_PID:-none}, TTL ${ttl}s, renew ${renew_before}s before)"
while :; do
    if [[ -n "${BASTION_OWNER_PID:-}" ]] && ! kill -0 "${BASTION_OWNER_PID}" 2>/dev/null; then
        log "owner pid ${BASTION_OWNER_PID} is gone - supervisor stops"
        exit 0
    fi
    age=$(($(date +%s) - $(mtime .bastion-tunnel.cmd)))
    if [[ ${age} -gt $((ttl - renew_before)) || ${fast_exits} -ge ${MAX_FAST_EXITS} ]]; then
        log "session is ${age}s old, ${fast_exits} fast ssh exits in a row"
        fast_exits=0
        if renew_session "$@"; then
            stop_ssh
        else
            sleep 30
            continue
        fi
    fi
    if [[ -z "${ssh_pid}" ]] || ! kill -0 "${ssh_pid}" 2>/dev/null; then
        if [[ -n "${ssh_pid}" ]]; then
            rc=0
            wait "${ssh_pid}" 2>/dev/null || rc=$?
            if [[ $(($(date +%s) - ssh_start)) -lt ${FAST_EXIT} ]]; then
                fast_exits=$((fast_exits + 1))
            else
                fast_exits=0
            fi
            log "tunnel ssh exited rc=${rc} - restarting"
            sleep 5
        fi
        bash -c "$(cat .bastion-tunnel.cmd) ${SSH_OPTS}" &
        ssh_pid=$!
        ssh_start=$(date +%s)
    fi
    sleep "${POLL}"
done
