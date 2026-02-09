#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: setup_common_os.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.10.30
# Revision...: v0.5.0
# Purpose....: Common functions and variables for OS setup scripts
# Notes......: This script contains common functions and variables used by
#              the OS setup scripts (setup_base_os.sh, setup_builder_os.sh and
#              setup_final_os.sh). It provides logging, error handling,
#              and utility functions to ensure consistent behavior across
#              different stages of OS setup.
# Reference..: Uses a common preamble pattern shared across setup_* scripts (no sourcing)
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# see git revision history for more information on changes/updates
# ------------------------------------------------------------------------------
# set bash options
set -euo pipefail   # strict mode
set -E              # make ERR trap fire in functions too
# Helpful on failures to know where we died
trap on_error ERR
umask 0022

# ------------------------------------------------------------------------------
# Global Constants and Variables
# ------------------------------------------------------------------------------
# Common defaults (stage-specific scripts can override after this)
: "${CLEANUP:=true}"
: "${BUILD_FLAVOR:=regular}"                    # regular | slim | full | veryslim
: "${STAGE:=common}"                            # stage name for logging
# Oracle Identity
: "${ORACLE_USER:=oracle}"                      # OS Oracle user
: "${ORACLE_GROUP:=oinstall}"                   # Primary Oracle group

# Oracle directory Layout
: "${ORACLE_ROOT:=/u00}"                        # Root under which Oracle lives
: "${ORACLE_BASE:=${ORACLE_ROOT}/app/oracle}"   # Oracle Base
: "${ORACLE_INVENTORY:=${ORACLE_ROOT}/app/oraInventory}"   # Oracle Inventory

# Oracle Versions / behavior
: "${ORACLE_MAJOR:=19}"                         # 19|21|23|26

# ------------------------------------------------------------------------------
# Script scope variables
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Utilities and Functions
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# Function....: log
# Purpose.....: Print a timestamped informational message to stdout.
# Parameters..: $@ - Message text to print.
# Globals.....: None.
# Notes.......: Provides consistent timestamped output for logging progress.
# ------------------------------------------------------------------------------
log()  { printf '[%s] [%s] %s\n' "$(date +'%F %T')" "${STAGE:-os}" "$*"; }

# ------------------------------------------------------------------------------
# Function....: fail
# Purpose.....: Print an error message and exit with a given code.
# Parameters..: $1 - Exit code (optional, default=1)
#               $@ - Error message to print.
# Globals.....: None.
# Notes.......: Exits the script after printing the error message and stack trace.
# ------------------------------------------------------------------------------
fail() { local rc=1; [[ "$1" =~ ^[0-9]+$ ]] && { rc=$1; shift; }; printf 'ERROR: %s\n' "$*" >&2;  _stacktrace;  exit "$rc"; }

# ------------------------------------------------------------------------------
# Function....: _stacktrace
# Purpose.....: Print a stack trace to stderr.
# Parameters..: None.
# Globals.....: None.
# Notes.......: Used for debugging to show call stack on errors.
# ------------------------------------------------------------------------------
_stacktrace() {
    # Frame 0 is _stacktrace; 1 is the caller (fail/on_error); start at 2
    local i
    for ((i=2; i<${#FUNCNAME[@]}; i++)); do
        local func="${FUNCNAME[$i]}"
        local src="${BASH_SOURCE[$i]}"
        local line="${BASH_LINENO[$((i-1))]}"
        printf '  at %s(%s:%s)\n' "${func:-MAIN}" "${src:-?}" "${line:-?}" >&2
    done
}

# ------------------------------------------------------------------------------
# Function....: on_error
# Purpose.....: Error handler for trapping ERR signals.
# Parameters..: None.
# Globals.....: None.
# Notes.......: Prints the command that failed and a stack trace before exiting.
# ------------------------------------------------------------------------------
on_error() {
    local rc=$?
    # BASH_COMMAND contains the command that failed
    printf 'ERROR: Command failed (%s): %s\n' "$rc" "${BASH_COMMAND}" >&2
    _stacktrace
    exit "$rc"
}

# ------------------------------------------------------------------------------
# Function....: run
# Purpose.....: Log and execute a command.
# Parameters..: $@ - Command and arguments to execute.
# Globals.....: None.
# Notes.......: Logs the command before execution for traceability.
# ------------------------------------------------------------------------------
run()  { log "> $*"; "$@"; }

# ------------------------------------------------------------------------------
# Function....: normalize_flavor
# Purpose.....: Normalize BUILD_FLAVOR to lowercase.
# Parameters..: None.
# Globals.....: BUILD_FLAVOR
# Notes.......: Ensures consistent handling of flavor strings.
# ------------------------------------------------------------------------------
normalize_flavor() { printf '%s' "${BUILD_FLAVOR:-regular}" | tr '[:upper:]' '[:lower:]'; }

# ------------------------------------------------------------------------------
# Function....: require_root
# Purpose.....: Ensure the script is run with root privileges.
# Parameters..: None.
# Globals.....: None.
# Notes.......: Exits with error if not run as root.
# ------------------------------------------------------------------------------
require_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || fail "This script must be run as root"; }

# ------------------------------------------------------------------------------
# Function....: ensure_dnf
# Purpose.....: Ensure dnf is available (install via microdnf if needed).
# Parameters..: None.
# Globals.....: None.
# Notes.......: OL8-slim may only have microdnf; we need dnf/yum semantics.
# ------------------------------------------------------------------------------
ensure_dnf() {
    if command -v dnf >/dev/null 2>&1; then return; fi
    if command -v microdnf >/dev/null 2>&1; then
        log "DNF not found — installing yum via microdnf for compatibility"
        microdnf install --nodocs -y yum || fail "Failed to install yum (DNF compatibility)"
        return
    fi
    fail "Neither dnf nor microdnf found — unsupported base image"
}

# ------------------------------------------------------------------------------
# Function....: clean_pkg_caches_tmp
# Purpose.....: Clean package manager caches and temporary files.
# Parameters..: None.
# Globals.....: CLEANUP
# Notes.......: Cleans dnf/yum caches and temp dirs if CLEANUP=true.
# ------------------------------------------------------------------------------
clean_pkg_caches_tmp() {
    if [[ "${CLEANUP}" == "true" ]]; then
        command -v dnf >/dev/null 2>&1 && dnf -y clean all || true
        rm -rf /var/cache/dnf/* /var/cache/yum /var/tmp/* /tmp/* 2>/dev/null || true
    else
        log "Skipping package cache cleanup (CLEANUP=false)"
    fi
}

# ------------------------------------------------------------------------------
# Function....: enable_repos
# Purpose.....: Enable optional package repositories based on flavor.
# Parameters..: None.
# Globals.....: BUILD_FLAVOR
# Notes.......: Enables EPEL repo for non-slim flavors if available.   
# ------------------------------------------------------------------------------
enable_repos() {
    local flavor; flavor="$(normalize_flavor)"
    if [[ "$flavor" == "slim" ]] || [[ "$flavor" == "veryslim" ]]; then
        log "Flavor=slim or flavor=veryslim → skip enabling optional repos at base stage"
        return 0
    fi

    log "Enabling optional repos if available"
    # only attempt if metadata exists; avoids noisy failures on minimal images
    if dnf -q list oracle-epel-release* >/dev/null 2>&1; then
        dnf -y install --nodocs oracle-epel-release* \
          || log "EPEL release package not available; continuing without"
    else
        log "EPEL repo package not present; skipping"
    fi
}

# ------------------------------------------------------------------------------
# Function....: set_oracle_password
# Purpose.....: Set the default password for the Oracle OS user.
# Parameters..: None.
# Globals.....: ORACLE_USER
# Notes.......: Uses chpasswd if available; ignores failure if user absent.
# ------------------------------------------------------------------------------
set_oracle_password() {
    # Set default oracle password (only if passwd exists and user present)
    if command -v chpasswd >/dev/null 2>&1 && getent passwd "${ORACLE_USER}" >/dev/null; then
        echo "${ORACLE_USER}:${ORACLE_USER}" | chpasswd \
          || log "Warning: failed to set default password"
    fi
}

# ------------------------------------------------------------------------------
# Function....: fix_oracle_tree_perms
# Purpose.....: Ensure Oracle directory tree has correct ownership and permissions.
# Parameters..: None.
# Globals.....: ORACLE_BASE, ORACLE_USER, ORACLE_GROUP
# Notes.......: Recursively sets ownership to ORACLE_USER:ORACLE_GROUP and
#               makes all .sh files executable by user and group.
# ------------------------------------------------------------------------------
fix_oracle_tree_perms() {
    if [[ -d "${ORACLE_BASE}" ]]; then
        chown -R "${ORACLE_USER}:${ORACLE_GROUP}" "${ORACLE_BASE}"
        find "${ORACLE_BASE}" -type f -name '*.sh' -exec chmod ug+x {} +
    else
        log "ORACLE_BASE '${ORACLE_BASE}' not present — skipping perms fix"
    fi
}

# ------------------------------------------------------------------------------
# Core functions
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Main Script Logic
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# Function....: main
# Purpose.....: Execute all steps to configure the OS for the ${STAGE} stage.
# Parameters..: None.
# Globals.....: STAGE, BUILD_FLAVOR
# Notes.......: Must be executed as root. Runs all setup steps sequentially.
# ------------------------------------------------------------------------------
main() {
    require_root                        # Ensure we have root privileges
    local flavor; flavor="$(normalize_flavor)"
    local major; major="${ORACLE_MAJOR:-19}"

    log "Starting ${STAGE} OS setup (ORACLE_MAJOR=${major}, BUILD_FLAVOR=${flavor})"
    ensure_dnf                          # Ensure DNF is available
    enable_repos                        # Enable optional repos based on flavor
    
    # Stage-specific tasks go here in derived scripts

    # Common finalization steps
    fix_oracle_tree_perms               # fix ownership & perms under ORACLE_BASE
    set_oracle_password                 # set default oracle password
    clean_pkg_caches_tmp                # Clean package caches and temp files
    log "${STAGE} OS setup complete"
}

# --- Call the main function ---------------------------------------------------
main "$@"
# --- EOF ----------------------------------------------------------------------
