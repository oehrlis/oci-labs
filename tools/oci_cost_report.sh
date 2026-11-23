#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: oci_cost_report.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.11.23
# Version....: v0.1.0
# Purpose....: Read-only cost report for a credit-funded tenancy (the ACE
#              tenancy): credits used in the current credit year, what is
#              left, forecast to the end of the year, cost per month, top
#              resources and the compute/database resources with their state.
# Notes......: Usage API cost is list price in the tenancy currency. Daily
#              data is fetched in windows of at most 90 days (the API allows
#              93). The credit amount is an input (--credits): the API shows
#              the promotion of the subscription, not the yearly ACE amount,
#              so both are printed. The report is Markdown on stdout, or a
#              file with --notes / --out. Makes no changes in OCI.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.11.23 oehrli - initial version
# ------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="v0.1.0"

PROFILE="${OCI_COST_PROFILE:-ACE}"
CREDITS="${ACE_CREDITS:-5000}"
YEAR_START="${ACE_YEAR_START:-09-09}"
NOTES_DIR="${NOTES_DIR:-${HOME}/notes/costs}"
OCI_CONFIG="${OCI_CLI_CONFIG_FILE:-${HOME}/.oci/config}"
TOP_N=10
RECENT_DAYS=30
TODAY=""
OUT_FILE=""
DRY_RUN="FALSE"
YES="FALSE"

# Resource types listed under "Compute und Datenbanken" - the ones that cost
# money while they run.
WATCH_TYPES='["Instance","AutonomousDatabase","DbSystem","CloudVmCluster","MysqlDbSystem","AnalyticsInstance","IntegrationInstance"]'

WORK_DIR=""

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

  Read-only cost report for a credit-funded tenancy: credits used in the
  current credit year, what is left, forecast, cost per month, top resources
  and the compute/database resources with their state. Markdown on stdout.

Options:
  -p, --profile NAME      OCI CLI profile (default: ${PROFILE}, env OCI_COST_PROFILE)
  -c, --credits AMOUNT    Credits per credit year in the tenancy currency
                          (default: ${CREDITS}, env ACE_CREDITS)
  -s, --year-start MM-DD  First day of the credit year (default: ${YEAR_START}, env ACE_YEAR_START)
  -d, --date YYYY-MM-DD   Report as of this day (default: today, UTC); data up to the day before
  -t, --top N             Number of top resources (default: ${TOP_N})
  -n, --notes             Write to ${NOTES_DIR}/YYYY-MM.md (env NOTES_DIR)
  -o, --out FILE          Write to FILE
  -y, --yes               Overwrite an existing report file
      --dry-run           With --notes/--out: print the report, write nothing
  -h, --help              Show this help and exit
  -V, --version           Show the version

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --notes --dry-run
  ${SCRIPT_NAME} --notes --yes
  ${SCRIPT_NAME} --credits 5000 --year-start 09-09 --out /tmp/ace.md
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

info() { echo "INFO: $*" >&2; }

cleanup() {
    if [[ -n "${WORK_DIR}" && -d "${WORK_DIR}" ]]; then rm -rf "${WORK_DIR}"; fi
}

parse_args() {
    local write_notes="FALSE"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p | --profile) PROFILE="${2:?--profile needs a value}"; shift 2 ;;
            -c | --credits) CREDITS="${2:?--credits needs a value}"; shift 2 ;;
            -s | --year-start) YEAR_START="${2:?--year-start needs a value}"; shift 2 ;;
            -d | --date) TODAY="${2:?--date needs a value}"; shift 2 ;;
            -t | --top) TOP_N="${2:?--top needs a value}"; shift 2 ;;
            -n | --notes) write_notes="TRUE"; shift ;;
            -o | --out) OUT_FILE="${2:?--out needs a value}"; shift 2 ;;
            -y | --yes) YES="TRUE"; shift ;;
            --dry-run) DRY_RUN="TRUE"; shift ;;
            -h | --help) usage; exit 0 ;;
            -V | --version) echo "${SCRIPT_NAME} ${SCRIPT_VERSION}"; exit 0 ;;
            *) usage >&2; die "unknown option: $1" ;;
        esac
    done

    [[ "${CREDITS}" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "--credits must be a number: ${CREDITS}"
    [[ "${YEAR_START}" =~ ^(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$ ]] || die "--year-start must be MM-DD: ${YEAR_START}"
    if [[ "${YEAR_START}" == "02-29" ]]; then die "--year-start 02-29 has no date in most years"; fi
    [[ "${TOP_N}" =~ ^[1-9][0-9]*$ ]] || die "--top must be a positive number: ${TOP_N}"
    if [[ -z "${TODAY}" ]]; then TODAY="$(date -u +%Y-%m-%d)"; fi
    [[ "${TODAY}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "--date must be YYYY-MM-DD: ${TODAY}"

    if [[ "${write_notes}" == "TRUE" ]]; then
        if [[ -n "${OUT_FILE}" ]]; then die "use either --notes or --out, not both"; fi
        OUT_FILE="${NOTES_DIR}/${TODAY:0:7}.md"
    fi
    if [[ "${DRY_RUN}" == "TRUE" && -z "${OUT_FILE}" ]]; then
        info "--dry-run without --notes/--out: the report goes to stdout anyway"
    fi
}

check_tools() {
    local tool
    for tool in oci jq; do
        command -v "${tool}" > /dev/null || die "missing tool: ${tool}"
    done
}

# Tenancy OCID of the profile from the OCI CLI config file.
tenancy_of_profile() {
    [[ -r "${OCI_CONFIG}" ]] || die "OCI config not readable: ${OCI_CONFIG}"
    awk -v p="[${PROFILE}]" '
        $0 == p { f = 1; next }
        /^\[/ { f = 0 }
        f && /^[[:space:]]*tenancy[[:space:]]*=/ { sub(/^[^=]*=[[:space:]]*/, ""); print; exit }
    ' "${OCI_CONFIG}"
}

oci_p() { oci --profile "${PROFILE}" "$@"; }

# Date arithmetic in jq: portable between BSD and GNU date.
day_add() {
    jq -rn --arg d "$1" --argjson n "$2" '($d | strptime("%Y-%m-%d") | mktime) + $n * 86400 | strftime("%Y-%m-%d")'
}

day_diff() {
    jq -rn --arg a "$1" --arg b "$2" '(($b | strptime("%Y-%m-%d") | mktime) - ($a | strptime("%Y-%m-%d") | mktime)) / 86400 | floor'
}

# First day of the credit year that contains TODAY, and the first day of the next one.
credit_year() {
    jq -rn --arg today "${TODAY}" --arg ys "${YEAR_START}" '
        def d(s): s | strptime("%Y-%m-%d") | mktime;
        ($today[0:4] | tonumber) as $y
        | (if d("\($y)-\($ys)") > d($today) then $y - 1 else $y end) as $sy
        | "\($sy)-\($ys) \($sy + 1)-\($ys)"'
}

# Runs an OCI CLI list call page by page and prints the jq filter result of every page.
oci_paged() {
    local filter="$1" resp page=""
    shift
    while :; do
        if [[ -n "${page}" ]]; then resp="$(oci_p "$@" --page "${page}")"; else resp="$(oci_p "$@")"; fi || return 1
        jq -c "${filter}" <<< "${resp}"
        page="$(jq -r '."opc-next-page" // empty' <<< "${resp}")"
        [[ -n "${page}" ]] || return 0
    done
}

# Daily cost items from $1 (incl.) to $2 (excl.), appended to $3, one JSON per line.
fetch_usage() {
    local from="$1" to="$2" out="$3" next
    while [[ "${from}" < "${to}" ]]; do
        next="$(day_add "${from}" 90)"
        if [[ "${next}" > "${to}" ]]; then next="${to}"; fi
        oci_paged '.data.items[]' usage-api usage-summary request-summarized-usages \
            --region "${HOME_REGION}" --tenant-id "${TENANCY}" --granularity DAILY --query-type COST \
            --time-usage-started "${from}T00:00:00Z" --time-usage-ended "${next}T00:00:00Z" \
            --group-by '["resourceId","service","skuName","compartmentName"]' --compartment-depth 6 \
            >> "${out}" || die "Usage API failed for ${from}..${next}"
        from="${next}"
    done
}

# Resources that are not terminated, from Search in every subscribed region.
fetch_resources() {
    local out="$1" region
    local query="query all resources where lifecycleState != 'TERMINATED' && lifecycleState != 'DELETED'"
    for region in ${REGIONS}; do
        oci_paged '.data.items[]' search resource structured-search --region "${region}" \
            --query-text "${query}" --limit 1000 |
            jq -c --arg r "${region}" '{id: .identifier, name: ."display-name", type: ."resource-type",
                state: ."lifecycle-state", comp: ."compartment-id", region: $r}' >> "${out}" ||
            die "Search failed in ${region}"
    done
}

fetch_compartments() {
    local out="$1"
    {
        oci_p iam compartment list --compartment-id "${TENANCY}" --compartment-id-in-subtree true \
            --access-level ANY --all --region "${HOME_REGION}" |
            jq -c '.data[] | {id, name}'
        jq -cn --arg id "${TENANCY}" --arg n "${TENANCY_NAME}" '{id: $id, name: "\($n) (root)"}'
    } > "${out}"
}

# Active promotions of the tenancy subscriptions, as the API reports them.
fetch_promotions() {
    local out="$1" id
    : > "${out}"
    while IFS= read -r id; do
        oci_p organizations subscription get --subscription-id "${id}" --region "${HOME_REGION}" |
            jq -c '.data as $s | ($s.promotion // [])[] | {sub: $s."classic-subscription-id", amount, cur: ."currency-unit",
                status, expires: ((."time-expired" // "")[0:10])}' >> "${out}"
    done < <(oci_p organizations subscription list --compartment-id "${TENANCY}" --all --region "${HOME_REGION}" |
        jq -r '.data.items[].id')
}

render_report() {
    local usage="$1" resources="$2" comps="$3" promos="$4"
    local days_total days_done days_left recent_from
    days_total="$(day_diff "${YEAR_FROM}" "${YEAR_TO}")"
    days_done="$(day_diff "${YEAR_FROM}" "${TODAY}")"
    days_left=$((days_total - days_done))
    recent_from="$(day_add "${TODAY}" "-${RECENT_DAYS}")"
    if [[ "${recent_from}" < "${YEAR_FROM}" ]]; then recent_from="${YEAR_FROM}"; fi

    jq -rn \
        --slurpfile u "${usage}" --slurpfile r "${resources}" --slurpfile c "${comps}" --slurpfile p "${promos}" \
        --arg tenancy "${TENANCY_NAME}" --arg profile "${PROFILE}" --arg region "${HOME_REGION}" \
        --arg today "${TODAY}" --arg yfrom "${YEAR_FROM}" --arg ylast "${YEAR_LAST}" \
        --arg rfrom "${recent_from}" --arg version "${SCRIPT_VERSION}" --arg generated "$(date -u +%Y-%m-%dT%H:%MZ)" \
        --argjson credits "${CREDITS}" --argjson dtotal "${days_total}" --argjson ddone "${days_done}" \
        --argjson dleft "${days_left}" --argjson rdays "${RECENT_DAYS}" --argjson top "${TOP_N}" \
        --argjson watch "${WATCH_TYPES}" '
        def r2: . * 100 | round / 100;
        def amt: r2 | tostring | if test("\\.") then (if test("\\.[0-9]$") then . + "0" else . end) else . + ".00" end;
        def short(id): if (id // "") == "" then "(ohne Ressource)" else "..." + (id | .[-8:]) end;
        ($u | map(select((."computed-amount" // 0) != 0))) as $rows
        | ($rows[0].currency // "CHF") as $cur
        | ($c | map({(.id): .name}) | add // {}) as $cname
        | ($r | map({(.id | ascii_downcase): .}) | add // {}) as $res
        | ($rows | map(."computed-amount") | add // 0) as $used
        | ($rows | map(select(."time-usage-started"[0:10] >= $rfrom)) | map(."computed-amount") | add // 0) as $recent
        | ([$rdays, $ddone] | min) as $rd
        | (if $rd > 0 then $recent / $rd else 0 end) as $rate
        | ($used + $rate * $dleft) as $forecast
        | ($credits - $used) as $left
        | (if $rate > 0 then (($today | strptime("%Y-%m-%d") | mktime) + ($left / $rate | floor) * 86400 | strftime("%Y-%m-%d")) else "" end) as $empty
        | ($rows | group_by(."resource-id" // "") | map({
              id: (.[0]."resource-id" // ""), service: .[0].service, comp: .[0]."compartment-name",
              sku: (group_by(."sku-name") | max_by(map(."computed-amount") | add) | .[0]."sku-name"),
              year: (map(."computed-amount") | add),
              recent: (map(select(."time-usage-started"[0:10] >= $rfrom)) | map(."computed-amount") | add // 0)})
           | sort_by(-.year)) as $byres
        | ($rows | group_by(."time-usage-started"[0:7]) | map({m: .[0]."time-usage-started"[0:7], v: (map(."computed-amount") | add)})) as $bymonth
        | ($byres | map({(.id | ascii_downcase): .recent}) | add // {}) as $recentby
        | [
            "# OCI-Kosten \($tenancy) - \($today)",
            "",
            "Erzeugt \($generated) mit `tools/oci_cost_report.sh` \($version), Profil \($profile), Usage API in \($region).",
            "Kosten zu Listenpreisen in \($cur), Tageswerte bis vor \($today); der letzte Tag kann noch unvollstaendig sein.",
            "",
            "## Credit-Jahr \($yfrom) bis \($ylast)",
            "",
            (if $forecast > $credits then
                "**WARNUNG: Die Hochrechnung (\($forecast | amt) \($cur)) uebersteigt die Credits (\($credits | amt) \($cur)) - aufgebraucht etwa am \($empty).**"
             else
                "OK: Die Hochrechnung bleibt unter den Credits, am Jahresende bleiben etwa \(($credits - $forecast) | amt) \($cur) ungenutzt."
             end),
            "",
            "| Kennzahl | Wert |",
            "| --- | --- |",
            "| Credits im Credit-Jahr (Eingabe `--credits`) | \($credits | amt) \($cur) |",
            "| Verbraucht seit \($yfrom) | \($used | amt) \($cur) (\(if $credits > 0 then ($used / $credits * 100 | r2) else 0 end) %) |",
            "| Uebrig | \($left | amt) \($cur) |",
            "| Tage | \($ddone) von \($dtotal) vorbei, \($dleft) uebrig |",
            "| Schnitt letzte \($rd) Tage | \($rate | amt) \($cur) pro Tag, \(($rate * 30) | amt) \($cur) pro 30 Tage |",
            "| Hochrechnung bis \($ylast) | \($forecast | amt) \($cur) |",
            "| Uebrig am Jahresende (Prognose) | \(($credits - $forecast) | amt) \($cur) |",
            "",
            "## Promotion laut API",
            "",
            (if ($p | length) == 0 then "Keine Promotion gefunden - die Credits stammen nur aus `--credits`."
             else
                ("| Subscription | Betrag | Status | Ablauf |", "| --- | --- | --- | --- |",
                 ($p[] | "| \(.sub) | \(.amount | amt) \(.cur) | \(.status) | \(.expires) |"),
                 "",
                 (if ($p | map(select(.status == "ACTIVE" and .amount == $credits)) | length) == 0
                  then ("Hinweis: Keine aktive Promotion ueber \($credits | amt) \($cur) - der Report rechnet mit `--credits`.",
                        "Den Restbetrag zeigt nur die Konsole (Billing & Cost Management > Subscriptions).")
                  else empty end))
             end),
            "",
            "## Kosten pro Monat",
            "",
            "| Monat | Kosten |",
            "| --- | --- |",
            (if ($bymonth | length) == 0 then "| \($today[0:7]) | 0.00 \($cur) |" else ($bymonth[] | "| \(.m) | \(.v | amt) \($cur) |") end),
            "",
            "## Top-\($top)-Ressourcen im Credit-Jahr",
            "",
            (if ($byres | length) == 0 then "Noch keine Kosten im Credit-Jahr." else
                ("| Ressource | Service / SKU | Compartment | Zustand | Credit-Jahr | Letzte \($rdays) Tage |",
                 "| --- | --- | --- | --- | --- | --- |",
                 ($byres[:$top][] as $x
                    | ($res[$x.id | ascii_downcase] // {}) as $o
                    | "| \($o.name // short($x.id)) | \($x.service) / \($x.sku) | \($x.comp) | \($o.state // (if $x.id == "" then "-" else "weg" end)) | \($x.year | amt) | \($x.recent | amt) |"))
             end),
            "",
            "## Compute und Datenbanken",
            "",
            ([$r[] | select(.type as $t | $watch | index($t))] | sort_by(.state, .name)) as $w
            | if ($w | length) == 0 then "Keine Instanzen oder Datenbanken." else
                ("| Ressource | Typ | Compartment | Region | Zustand | Letzte \($rdays) Tage |",
                 "| --- | --- | --- | --- | --- | --- |",
                 ($w[] | "| \(.name) | \(.type) | \($cname[.comp] // short(.comp)) | \(.region) | \(.state) | \(($recentby[.id | ascii_downcase] // 0) | amt) |"),
                 ([$w[] | select((.state | test("STOPPED|INACTIVE|SHUTDOWN")) and (($recentby[.id | ascii_downcase] // 0) > 0))] as $paid
                  | if ($paid | length) > 0 then
                      ("", "Gestoppt, kostet trotzdem (Storage, Lizenz oder SKU ohne Stopp-Rabatt):", "",
                       ($paid[] | "- \(.name)"))
                    else empty end))
              end
          ] | .[]'
}

write_report() {
    local report="$1"
    if [[ -z "${OUT_FILE}" ]]; then
        cat "${report}"
        return 0
    fi
    if [[ "${DRY_RUN}" == "TRUE" ]]; then
        cat "${report}"
        info "dry run - would write ${OUT_FILE}"
        return 0
    fi
    if [[ -e "${OUT_FILE}" && "${YES}" != "TRUE" ]]; then
        die "${OUT_FILE} exists - --yes overwrites it, --dry-run shows the new report"
    fi
    mkdir -p "$(dirname "${OUT_FILE}")"
    cp "${report}" "${OUT_FILE}"
    info "report written: ${OUT_FILE}"
}

main() {
    parse_args "$@"
    check_tools

    TENANCY="$(tenancy_of_profile)"
    [[ -n "${TENANCY}" ]] || die "no tenancy for profile ${PROFILE} in ${OCI_CONFIG}"
    local regions_json
    regions_json="$(oci_p iam region-subscription list --tenancy-id "${TENANCY}")"
    HOME_REGION="$(jq -r '.data[] | select(."is-home-region") | ."region-name"' <<< "${regions_json}")"
    [[ -n "${HOME_REGION}" ]] || die "home region of profile ${PROFILE} not found"
    REGIONS="$(jq -r '.data[] | select(.status == "READY") | ."region-name"' <<< "${regions_json}")"
    TENANCY_NAME="$(oci_p iam tenancy get --tenancy-id "${TENANCY}" | jq -r '.data.name')"

    read -r YEAR_FROM YEAR_TO <<< "$(credit_year)"
    YEAR_LAST="$(day_add "${YEAR_TO}" -1)"
    info "profile ${PROFILE}, tenancy ${TENANCY_NAME}, home ${HOME_REGION}, credit year ${YEAR_FROM}..${YEAR_LAST}"

    WORK_DIR="$(mktemp -d)"
    trap cleanup EXIT
    : > "${WORK_DIR}/usage.jsonl"
    : > "${WORK_DIR}/resources.jsonl"
    fetch_usage "${YEAR_FROM}" "${TODAY}" "${WORK_DIR}/usage.jsonl"
    fetch_resources "${WORK_DIR}/resources.jsonl"
    fetch_compartments "${WORK_DIR}/compartments.jsonl"
    fetch_promotions "${WORK_DIR}/promotions.jsonl"

    render_report "${WORK_DIR}/usage.jsonl" "${WORK_DIR}/resources.jsonl" \
        "${WORK_DIR}/compartments.jsonl" "${WORK_DIR}/promotions.jsonl" > "${WORK_DIR}/report.md"
    write_report "${WORK_DIR}/report.md"
}

main "$@"
