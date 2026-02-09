#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: oci_update_sec_list_ip.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.28
# Revision...: v0.1.0
# Purpose....: Update OCI Security List ingress rules with current public IP.
# Notes......: 
#   - Modes:
#       * ssh       : nur SSH-Rule(n) für einen Port anpassen
#       * wireguard : nur WireGuard-Rule(n) für einen Port anpassen
#       * all       : alle IPs (CIDR_BLOCK) ersetzen
#   - Description-Handling:
#       * Regeln mit "KEEP"/"keep" im Description werden NIE angepasst.
#       * Auto-Regeln werden mit "OCI-LABS-SSH-AUTO" / "OCI-LABS-WG-AUTO"
#         gekennzeichnet.
#   - Standardverhalten:
#       * Regeln werden ersetzt (Quelle-IP aktualisiert), nicht nur angehängt.
#   - Append:
#       * Mit --append wird nur eine neue Auto-Rule hinzugefügt, bestehende
#         bleiben unverändert.
#   - Dry-Run:
#       * Mit --dry-run werden nur die neuen Regeln berechnet und angezeigt.
#
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Bash Optionen / Error Handling
# ------------------------------------------------------------------------------
set -euo pipefail
set -E
trap on_error ERR || true   # on_error wird weiter unten definiert
umask 0022

# ------------------------------------------------------------------------------
# Globale Defaults
# ------------------------------------------------------------------------------
STAGE="oci-sec-list"

: "${DEFAULT_SSH_PORT:=22}"
: "${DEFAULT_WG_PORT:=51820}"

VERBOSE=false
DRY_RUN=false
APPEND=false

MODE=""               # ssh | wireguard | all
SEC_LIST_ID=""        # OCID der Security List
PUBLIC_IP_CIDR=""     # <ip>/32 (auto oder -i)
SSH_PORT=""           # SSH Port (Standard 22 oder override)
WG_PORT=""            # WireGuard Port (Standard 51820 oder override)

TMP_DIR=""

# ------------------------------------------------------------------------------
# Logging / Fehlerfunktionen (an setup_common_os.sh angelehnt)
# ------------------------------------------------------------------------------

log() {
  # Auf STDERR loggen, damit Command Substitution nicht "verschmutzt" wird
  printf '[%s] [%s] %s\n' "$(date +'%F %T')" "${STAGE:-oci}" "$*" >&2
}

log_debug() {
  if [[ "${VERBOSE}" == "true" ]]; then
    log "[DEBUG] $*"
  fi
}


fail() {
  local rc=1
  if [[ $# -gt 0 && "$1" =~ ^[0-9]+$ ]]; then
    rc="$1"
    shift
  fi
  printf 'ERROR: %s\n' "$*" >&2
  _stacktrace
  exit "${rc}"
}

_stacktrace() {
  local i
  for ((i=2; i<${#FUNCNAME[@]}; i++)); do
    local func="${FUNCNAME[$i]}"
    local src="${BASH_SOURCE[$i]}"
    local line="${BASH_LINENO[$((i-1))]}"
    printf '  at %s(%s:%s)\n' "${func:-MAIN}" "${src:-?}" "${line:-?}" >&2
  done
}

on_error() {
  local rc=$?
  printf 'ERROR: Command failed (%s): %s\n' "${rc}" "${BASH_COMMAND}" >&2
  _stacktrace
  exit "${rc}"
}

run() {
  log "> $*"
  "$@"
}

# ------------------------------------------------------------------------------
# Usage
# ------------------------------------------------------------------------------

usage() {
  cat <<EOF
Usage: $0 -m <mode> -s <sec_list_ocid> [options]

Modes:
  -m ssh         Update SSH-Regeln (TCP) für einen Port (Default: ${DEFAULT_SSH_PORT})
  -m wireguard   Update WireGuard-Regeln (UDP) für einen Port (Default: ${DEFAULT_WG_PORT})
  -m all         Alle CIDR-Quellen (CIDR_BLOCK) durch eigene IP ersetzen

Pflichtparameter:
  -m <mode>          Modus: ssh | wireguard | all
  -s <sec_list_ocid> Security List OCID

Optionen:
  -p <port>          Ziel-Port für ssh/wireguard (z.B. -p 16022 im Lab)
  -i <ip[/mask]>     Eigene IP (Default: per HTTP-Endpoint ermittelt, /32 angefügt falls keine Maske)
  -a, --append       Neue Auto-Regel nur anhängen, bestehende NICHT modifizieren
                     (für Mode=all nicht sinnvoll -> wird abgewiesen)
  -n, --dry-run      Nur berechnen und anzeigen, kein "oci network security-list update"
  -v                 Verbose/Debug Logging
  -h                 Diese Hilfe anzeigen

Besonderheiten:
  - Regeln mit "KEEP"/"keep" im Description werden grundsätzlich nicht geändert.
  - In Modes ssh/wireguard werden nur Regeln für den angegebenen Port angepasst.
  - In Mode all werden alle CIDR_BLOCK-Quellen (ohne KEEP) auf die eigene IP gesetzt.

Beispiele:
  # WireGuard-Source von 0.0.0.0/0 auf eigene IP einschränken:
  $0 -m wireguard -s <sec-list-ocid>

  # SSH-Regel für Port 16022 anpassen:
  $0 -m ssh -p 16022 -s <sec-list-ocid>

  # Nur Auto-SSH-Regel zusätzlich anhängen (Bestehende bleiben unverändert):
  $0 -m ssh -p 16022 -s <sec-list-ocid> --append

  # Alle CIDRs (ohne KEEP) auf eigene IP einschränken:
  $0 -m all -s <sec-list-ocid>

EOF
}

# ------------------------------------------------------------------------------
# Hilfsfunktionen
# ------------------------------------------------------------------------------

init_tmpdir() {
  TMP_DIR="$(mktemp -d -t oci-sec-list-XXXXXX)"
}

cleanup_tmpdir() {
  if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi
}

require_binary() {
  local bin="$1"
  command -v "${bin}" >/dev/null 2>&1 || fail 1 "Required command not found: ${bin}"
}

detect_public_ip() {
  # Nur setzen, wenn nicht explizit via -i gesetzt
  if [[ -n "${PUBLIC_IP_CIDR}" ]]; then
    return 0
  fi

  # Einfacher HTTP-Service, im Zweifel kannst du das später noch anpassen.
  local ip
  ip="$(curl -4 -s https://ifconfig.me || true)"

  [[ -z "${ip}" ]] && fail 1 "Could not detect public IP. Use -i <ip>."

  # Wenn keine Maske angegeben, /32 hinzufügen
  if [[ "${ip}" != */* ]]; then
    PUBLIC_IP_CIDR="${ip}/32"
  else
    PUBLIC_IP_CIDR="${ip}"
  fi
}

parse_args() {
  local opt
  # Long-Option-Handling für --append / --dry-run
  # Wir transformieren long-opts vor getopts
  local args=()
  for arg in "$@"; do
    case "$arg" in
      --append) args+=("-a") ;;
      --dry-run) args+=("-n") ;;
      --help) args+=("-h") ;;
      *) args+=("$arg") ;;
    esac
  done

  while getopts ":m:s:p:i:avnh" opt "${args[@]}"; do
    case "${opt}" in
      m) MODE="${OPTARG}" ;;
      s) SEC_LIST_ID="${OPTARG}" ;;
      p) PORT_OVERRIDE="${OPTARG}" ;;
      i) PUBLIC_IP_CIDR="${OPTARG}" ;;
      a) APPEND=true ;;
      v) VERBOSE=true ;;
      n) DRY_RUN=true ;;
      h) usage; exit 0 ;;
      \?) fail 1 "Unknown option: -${OPTARG}" ;;
      :)  fail 1 "Option -${OPTARG} requires an argument." ;;
    esac
  done

  # Mode normalisieren
  MODE="$(printf '%s' "${MODE:-}" | tr '[:upper:]' '[:lower:]')"

  [[ -z "${MODE}" ]] && fail 1 "Mode (-m) is required."
  [[ -z "${SEC_LIST_ID}" ]] && fail 1 "Security List OCID (-s) is required."

  case "${MODE}" in
    ssh|wireguard|all) ;;
    *) fail 1 "Unsupported mode: ${MODE} (expected: ssh | wireguard | all)" ;;
  esac

  if [[ "${MODE}" == "all" && "${APPEND}" == "true" ]]; then
    fail 1 "--append is not supported in mode 'all' (undefined semantics)."
  fi

  # Ports setzen
  SSH_PORT="${DEFAULT_SSH_PORT}"
  WG_PORT="${DEFAULT_WG_PORT}"
  if [[ -n "${PORT_OVERRIDE:-}" ]]; then
    case "${MODE}" in
      ssh)       SSH_PORT="${PORT_OVERRIDE}" ;;
      wireguard) WG_PORT="${PORT_OVERRIDE}" ;;
      all)       log "Port override ignored for mode 'all'." ;;
    esac
  fi
}

prepare_ip() {
  detect_public_ip
  # Wenn IP ohne Maske via -i angegeben wurde
  if [[ "${PUBLIC_IP_CIDR}" != */* ]]; then
    PUBLIC_IP_CIDR="${PUBLIC_IP_CIDR}/32"
  fi
  log "[INFO] Using public IP: ${PUBLIC_IP_CIDR}"
}

fetch_security_list() {
  local out_json="${TMP_DIR}/sec_list.json"
  log "[INFO] Fetching current security list: ${SEC_LIST_ID}"
  run oci network security-list get \
    --security-list-id "${SEC_LIST_ID}" \
    --output json > "${out_json}"

  echo "${out_json}"
}

build_ingress_rules() {
  local sec_list_json="$1"
  local jq_filter

  # Boolean für jq
  local append_json
  if [[ "${APPEND}" == "true" ]]; then
    append_json=true
  else
    append_json=false
  fi

  case "${MODE}" in
    all)
      jq_filter='
        def has_keep: ((.description // "") | ascii_upcase | contains("KEEP"));

        .data["ingress-security-rules"] // [] |
        map(
          if has_keep then
            .
          else
            . + { "source": $ip }
          end
        )
      '
      ;;

    ssh)
      jq_filter='
        def has_keep: ((.description // "") | ascii_upcase | contains("KEEP"));
        def is_ssh_rule:
          .protocol == "6"
          and (.["tcp-options"] // {})."destination-port-range" != null
          and .["tcp-options"]["destination-port-range"].min == ($sshPort|tonumber)
          and .["tcp-options"]["destination-port-range"].max == ($sshPort|tonumber);

        .data["ingress-security-rules"] // [] |
        if $append == true then
          . + [{
            "source": $ip,
            "protocol": "6",
            "is-stateless": false,
            "source-type": "CIDR_BLOCK",
            "icmp-options": null,
            "tcp-options": {
              "destination-port-range": {
                "min": ($sshPort|tonumber),
                "max": ($sshPort|tonumber)
              },
              "source-port-range": null
            },
            "udp-options": null,
            "description": "OCI-LABS-SSH-AUTO"
          }]
        else
          map(
            if has_keep then
              .
            elif is_ssh_rule then
              . + {
                "source": $ip,
                "description": (
                  if ((.description // "") | length) == 0
                  then "OCI-LABS-SSH-AUTO"
                  else .description
                  end
                )
              }
            else
              .
            end
          )
        end
      '
      ;;

    wireguard)
      jq_filter='
        def has_keep: ((.description // "") | ascii_upcase | contains("KEEP"));
        def is_wg_rule:
          .protocol == "17"
          and (.["udp-options"] // {})."destination-port-range" != null
          and .["udp-options"]["destination-port-range"].min == ($wgPort|tonumber)
          and .["udp-options"]["destination-port-range"].max == ($wgPort|tonumber);

        .data["ingress-security-rules"] // [] |
        if $append == true then
          . + [{
            "source": $ip,
            "protocol": "17",
            "is-stateless": false,
            "source-type": "CIDR_BLOCK",
            "icmp-options": null,
            "tcp-options": null,
            "udp-options": {
              "destination-port-range": {
                "min": ($wgPort|tonumber),
                "max": ($wgPort|tonumber)
              },
              "source-port-range": null
            },
            "description": "OCI-LABS-WG-AUTO"
          }]
        else
          map(
            if has_keep then
              .
            elif is_wg_rule then
              . + {
                "source": $ip,
                "description": (
                  if ((.description // "") | length) == 0
                  then "OCI-LABS-WG-AUTO"
                  else .description
                  end
                )
              }
            else
              .
            end
          )
        end
      '
      ;;
  esac

  log_debug "Building ingress rules for mode='${MODE}' (append=${APPEND})"
  local ingress_json_file="${TMP_DIR}/ingress.json"

  jq \
    --arg ip "${PUBLIC_IP_CIDR}" \
    --arg sshPort "${SSH_PORT}" \
    --arg wgPort "${WG_PORT}" \
    --argjson append "${append_json}" \
    "${jq_filter}" \
    "${sec_list_json}" > "${ingress_json_file}"

  if [[ "${VERBOSE}" == "true" ]]; then
    log_debug "Final ingress JSON to be applied:"
    sed 's/^/  /' "${ingress_json_file}" >&2
  fi
  echo "${ingress_json_file}"
}

apply_update() {
  local ingress_json="$1"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log "[INFO] Dry-run enabled — not calling OCI CLI."
    return 0
  fi

  log "[INFO] Updating Security List: ${SEC_LIST_ID}"
  log_debug "OCI CLI will use ingress JSON: ${ingress_json}"

  run oci network security-list update \
    --security-list-id "${SEC_LIST_ID}" \
    --ingress-security-rules "file://${ingress_json}" \
    --force

  log "[INFO] Security List updated successfully."
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

main() {
  require_binary "oci"
  require_binary "jq"
  require_binary "curl"

  parse_args "$@"
  init_tmpdir
  trap cleanup_tmpdir EXIT

  log_debug "Mode: ${MODE}, SSH port: ${SSH_PORT}, WG port: ${WG_PORT}"
  prepare_ip

  local sec_list_json ingress_json
  sec_list_json="$(fetch_security_list)"
  ingress_json="$(build_ingress_rules "${sec_list_json}")"
  apply_update "${ingress_json}"
}

main "$@"
# --- EOF ----------------------------------------------------------------------
