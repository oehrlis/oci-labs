#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: cpu-lab-progress.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.08.19
# Version....: v0.1.0
# Purpose....: Report the progress of the currently running cpu-patch-test step
#              (dbca or AutoUpgrade) on an Oracle lab host.
# Notes......: Runs ON the lab host, as root - the Oracle directories are not
#              readable by opc, and without privileges du/find silently return
#              nothing, which looks like "nothing is happening" even while dbca
#              is at 36%. Invoked by "make cpu-lab-progress" via
#              ansible -m script --become. Read-only.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
set -euo pipefail

ORACLE_ROOT="${ORACLE_ROOT:-/u00}"
ORACLE_DATA="${ORACLE_DATA:-/u01}"
ORACLE_BASE="${ORACLE_BASE:-${ORACLE_ROOT}/app/oracle}"
DBCA_LOG_DIR="${ORACLE_BASE}/cfgtoollogs/dbca"
AU_LOG_DIR="${ORACLE_BASE}/cfgtoollogs/autoupgrade"

printf -- '--- %s on %s ---\n' "$(date +%H:%M:%S)" "$(hostname -s)"

# ------------------------------------------------------------------------------
# Which long-running step is active
# ------------------------------------------------------------------------------
if pgrep -f 'assistants.dbca' >/dev/null 2>&1; then
    dbca_log="$(find "${DBCA_LOG_DIR}" -name '*.log' -print 2>/dev/null |
        grep -vE 'Clone|rman|trace' | head -1)"
    pct="unknown"
    phase="unknown"
    if [[ -n "${dbca_log}" ]] && [[ -r "${dbca_log}" ]]; then
        pct="$(grep -oE 'DBCA_PROGRESS : [0-9]+%' "${dbca_log}" | tail -1 |
            grep -oE '[0-9]+%' || echo 'unknown')"
        phase="$(grep -v 'DBCA_PROGRESS' "${dbca_log}" | tail -1 || true)"
    fi
    echo "step......: dbca (create_db)"
    echo "progress..: ${pct}"
    echo "phase.....: ${phase}"
elif pgrep -f 'autoupgrade.jar' >/dev/null 2>&1; then
    mode="$(pgrep -af 'autoupgrade.jar' | grep -oE '\-mode [a-z_]+' | head -1 ||
        echo '-mode ?')"
    echo "step......: autoupgrade (${mode})"
    au_log="$(find "${AU_LOG_DIR}" -name '*.log' -newermt '-5 minutes' 2>/dev/null |
        head -1)"
    if [[ -n "${au_log}" ]] && [[ -r "${au_log}" ]]; then
        echo "phase.....: $(tail -1 "${au_log}")"
        echo "log.......: ${au_log}"
    fi
else
    echo "step......: idle - no dbca or autoupgrade process running"
fi

# ------------------------------------------------------------------------------
# Durable state - useful whether or not a step is running
# ------------------------------------------------------------------------------
homes="$(find "${ORACLE_BASE}/product" -maxdepth 2 -name dbhome_1 -type d 2>/dev/null |
    tr '\n' ' ')"
echo "homes.....: ${homes:-none}"

if [[ -d "${ORACLE_DATA}/oradata" ]]; then
    echo "datafiles.: $(du -sh "${ORACLE_DATA}"/oradata/* 2>/dev/null | tr '\n' ' ')"
fi

echo "oratab....: $(grep -v '^#' /etc/oratab 2>/dev/null | grep . | tr '\n' ' ')"
echo "diskfree..: $(df -h "${ORACLE_ROOT}" | awk 'NR==2 {print $4}') free on ${ORACLE_ROOT}"

# --- EOF ----------------------------------------------------------------------
