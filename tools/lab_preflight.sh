#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: lab_preflight.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.11.05
# Version....: v0.1.1
# Purpose....: Read-only check that every shared resource a layer needs exists
#              in its target (tenancy, compartment, state bucket, core, image,
#              shape) - before anything is built.
# Notes......: Reads backend.hcl and terraform.tfvars of a layer directory
#              (templates/core or templates/host-on-core copies), plus any
#              *.auto.tfvars with Terraform's precedence. Every
#              missing piece is named together with the command that creates
#              it; nothing is skipped silently. Exit 0 = ready, 1 = not ready,
#              2 = usage error. Makes no changes in OCI.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.11.05 oehrli - initial version
# 2026.11.05 oehrli - read *.auto.tfvars like Terraform (product values)
# ------------------------------------------------------------------------------
set -euo pipefail

TF_MIN_MAJOR=1
TF_MIN_MINOR=9

FAILS=0
WARNS=0

usage() {
    cat <<'EOF'
Usage: tools/lab_preflight.sh <layer-dir>

  <layer-dir>  directory with backend.hcl and terraform.tfvars of a core or
               host layer (a copy of terraform/templates/core|host-on-core)

The layer type is taken from terraform.tfvars: a core_state block means a host
layer, otherwise a core layer.
EOF
}

ok() { printf '  OK    %s\n' "$*"; }
warn() {
    printf '  WARN  %s\n' "$*"
    WARNS=$((WARNS + 1))
}
fail() {
    printf '  FAIL  %s\n' "$1"
    shift
    local line
    for line in "$@"; do printf '        %s\n' "$line"; done
    FAILS=$((FAILS + 1))
}

# Value of a top-level 'key = "value"' line; empty when absent or commented.
hcl_get() {
    local file="$1" key="$2"
    sed -nE "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"([^\"]*)\".*/\1/p" "$file" | head -1
}

# Value of a variable as Terraform resolves it from the layer's files:
# *.auto.tfvars are loaded after terraform.tfvars (alphabetically), so the last
# auto file that sets it wins, then terraform.tfvars.
tfvar_get() {
    local key="$1" f val
    local files=()
    while IFS= read -r f; do files+=("$f"); done < <(find "$LAYER_DIR" -maxdepth 1 -name '*.auto.tfvars' | sort -r)
    files+=("$TFVARS")
    for f in "${files[@]}"; do
        val="$(hcl_get "$f" "$key")"
        [[ -n "$val" ]] && { printf '%s\n' "$val"; return 0; }
    done
    return 0
}

# Value of 'key = "value"' inside a 'block = { ... }' of terraform.tfvars.
hcl_get_in_block() {
    local file="$1" block="$2" key="$3"
    awk -v b="$block" -v k="$key" '
        $0 ~ "^[[:space:]]*" b "[[:space:]]*=[[:space:]]*\\{" { inb = 1; next }
        inb && /^[[:space:]]*\}/ { inb = 0 }
        inb && $0 ~ "^[[:space:]]*" k "[[:space:]]*=" {
            sub(/^[^"]*"/, ""); sub(/".*$/, ""); print; exit
        }' "$file"
}

[[ $# -eq 1 && "$1" != "-h" && "$1" != "--help" ]] || {
    usage
    [[ $# -eq 1 ]] && exit 0
    exit 2
}

LAYER_DIR="$1"
BACKEND="${LAYER_DIR}/backend.hcl"
TFVARS="${LAYER_DIR}/terraform.tfvars"

for f in "$BACKEND" "$TFVARS"; do
    [[ -f "$f" ]] || {
        echo "ERROR: $f not found - copy ${f##*/}.example and fill it in" >&2
        exit 2
    }
done

PROFILE="$(tfvar_get oci_config_profile)"
REGION="$(tfvar_get region)"
COMPARTMENT="$(tfvar_get compartment_ocid)"
STATE_BUCKET="$(hcl_get "$BACKEND" bucket)"
STATE_NS="$(hcl_get "$BACKEND" namespace)"
STATE_KEY="$(hcl_get "$BACKEND" key)"
CORE_KEY="$(hcl_get_in_block "$TFVARS" core_state key)"
SHAPE="$(tfvar_get shape)"
OL_VERSION="$(tfvar_get ol_version)"
IMAGE_OCID="$(tfvar_get instance_image_ocid)"

if [[ -n "$CORE_KEY" ]]; then
    LAYER_TYPE="host"
    # template defaults when the tfvars do not set them
    SHAPE="${SHAPE:-VM.Standard.E5.Flex}"
    OL_VERSION="${OL_VERSION:-9}"
else
    LAYER_TYPE="core"
fi

OCI=(oci --profile "$PROFILE" --region "$REGION")

echo "Preflight ${LAYER_DIR} (${LAYER_TYPE} layer, profile ${PROFILE:-<unset>}, region ${REGION:-<unset>})"

# --- local tools --------------------------------------------------------------
echo "Tools"
for tool in oci terraform jq; do
    if command -v "$tool" >/dev/null 2>&1; then ok "$tool found"; else fail "$tool not in PATH" "install it (brew install ${tool/oci/oci-cli})"; fi
done
if command -v terraform >/dev/null 2>&1; then
    tf_version="$(terraform version -json | jq -r .terraform_version)"
    IFS=. read -r tf_major tf_minor _ <<<"$tf_version"
    if ((tf_major > TF_MIN_MAJOR || (tf_major == TF_MIN_MAJOR && tf_minor >= TF_MIN_MINOR))); then
        ok "terraform ${tf_version} (>= ${TF_MIN_MAJOR}.${TF_MIN_MINOR}: oci backend, naming validations)"
    else
        fail "terraform ${tf_version} is older than ${TF_MIN_MAJOR}.${TF_MIN_MINOR}" "brew upgrade terraform"
    fi
fi

# --- required inputs ----------------------------------------------------------
echo "Inputs"
missing=()
for pair in "oci_config_profile:$PROFILE" "region:$REGION" "compartment_ocid:$COMPARTMENT" \
    "bucket (backend.hcl):$STATE_BUCKET" "namespace (backend.hcl):$STATE_NS" "key (backend.hcl):$STATE_KEY"; do
    [[ -n "${pair#*:}" && "${pair#*:}" != \<* ]] || missing+=("${pair%%:*}")
done
if ((${#missing[@]})); then
    fail "unset or placeholder: ${missing[*]}" "fill them in ${TFVARS} / ${BACKEND}"
    echo "Not ready: ${FAILS} failure(s) - the remaining checks need these inputs."
    exit 1
fi
ok "all inputs set"

# --- tenancy ------------------------------------------------------------------
echo "Tenancy"
if ! grep -q "^\[${PROFILE}\]" "${OCI_CLI_CONFIG_FILE:-$HOME/.oci/config}" 2>/dev/null; then
    fail "profile ${PROFILE} not in ~/.oci/config" "oci setup config   (or oci session authenticate --profile-name ${PROFILE})"
    echo "Not ready: ${FAILS} failure(s)."
    exit 1
fi
if ! subs="$("${OCI[@]}" iam region-subscription list --output json 2>/dev/null)"; then
    fail "authentication with profile ${PROFILE} failed" "check key_file / fingerprint in ~/.oci/config: oci iam region list --profile ${PROFILE}"
    echo "Not ready: ${FAILS} failure(s)."
    exit 1
fi
ok "profile ${PROFILE} authenticates"
home_region="$(jq -r '.data[] | select(."is-home-region") | ."region-name"' <<<"$subs")"
if jq -e --arg r "$REGION" '.data[] | select(."region-name" == $r)' <<<"$subs" >/dev/null; then
    ok "region ${REGION} subscribed (home region ${home_region} - IAM resources go there)"
else
    fail "tenancy is not subscribed to ${REGION}" "subscribe in the console (Governance > Region Management) or pick a subscribed region"
fi

if comp_state="$("${OCI[@]}" iam compartment get -c "$COMPARTMENT" --query 'data."lifecycle-state"' --raw-output 2>/dev/null)" &&
    [[ "$comp_state" == "ACTIVE" ]]; then
    ok "compartment active ($("${OCI[@]}" iam compartment get -c "$COMPARTMENT" --query 'data.name' --raw-output))"
else
    fail "compartment not found or not ACTIVE (${comp_state:-not found})" "check compartment_ocid; list: oci iam compartment list --profile ${PROFILE} --compartment-id-in-subtree true --all --query 'data[].name'"
fi

ns="$("${OCI[@]}" os ns get --query data --raw-output 2>/dev/null || true)"
if [[ "$ns" == "$STATE_NS" ]]; then
    ok "namespace matches backend.hcl"
else
    fail "backend.hcl namespace does not match the tenancy (${ns:-unreadable})" "set namespace = \"${ns}\" in ${BACKEND}"
fi

# --- state bucket -------------------------------------------------------------
echo "State"
if bucket="$("${OCI[@]}" os bucket get -bn "$STATE_BUCKET" --output json 2>/dev/null)"; then
    access="$(jq -r '.data."public-access-type"' <<<"$bucket")"
    versioning="$(jq -r '.data.versioning' <<<"$bucket")"
    if [[ "$access" == "NoPublicAccess" ]]; then
        ok "state bucket ${STATE_BUCKET} exists, private, versioning ${versioning}"
    else
        fail "state bucket ${STATE_BUCKET} is public (${access}) - the state holds keys and passwords" \
            "oci os bucket update --profile ${PROFILE} -bn ${STATE_BUCKET} --public-access-type NoPublicAccess"
    fi
else
    fail "state bucket ${STATE_BUCKET} not found" \
        "oci os bucket create --profile ${PROFILE} -c <compartment OCID> --name ${STATE_BUCKET} --public-access-type NoPublicAccess"
    bucket=""
fi

# Lock left behind by an aborted run: the next apply would fail with HTTP 412.
if [[ -z "$bucket" ]]; then
    printf '  SKIP  lock, state and core checks - they need the state bucket\n'
elif "${OCI[@]}" os object head -bn "$STATE_BUCKET" --name "${STATE_KEY}.lock" >/dev/null 2>&1; then
    fail "lock ${STATE_KEY}.lock is held - a run is active or was aborted" \
        "if no run is active: terraform -chdir=${LAYER_DIR} force-unlock <LOCK_ID>   (ID in the 412 error)"
else
    ok "no lock on ${STATE_KEY}"
fi

if [[ -z "$bucket" ]]; then
    :
elif "${OCI[@]}" os object head -bn "$STATE_BUCKET" --name "$STATE_KEY" >/dev/null 2>&1; then
    ok "state ${STATE_KEY} exists - apply updates the layer"
else
    ok "state ${STATE_KEY} not there yet - apply builds the layer"
fi

# --- core (host layers only) --------------------------------------------------
if [[ "$LAYER_TYPE" == "host" ]]; then
    echo "Core"
    core_dir="<core layer dir>"
    if [[ -z "$bucket" ]]; then
        printf '  SKIP  core state - see the state bucket failure above\n'
    elif core_state="$("${OCI[@]}" os object get -bn "$STATE_BUCKET" --name "$CORE_KEY" --file - 2>/dev/null)"; then
        for out in vcn_id db_subnet_id bastion_id vcn_cidr lab_name_core; do
            val="$(jq -r --arg o "$out" '.outputs[$o].value // empty' <<<"$core_state")"
            if [[ -n "$val" ]]; then ok "core output ${out}"; else fail "core output ${out} missing in ${CORE_KEY}" "terraform -chdir=${core_dir} apply   (core template of this release)"; fi
        done
        vcn_id="$(jq -r '.outputs.vcn_id.value // empty' <<<"$core_state")"
        if [[ -n "$vcn_id" ]] && [[ "$("${OCI[@]}" network vcn get --vcn-id "$vcn_id" --query 'data."lifecycle-state"' --raw-output 2>/dev/null)" == "AVAILABLE" ]]; then
            ok "core VCN available"
        else
            fail "core VCN from ${CORE_KEY} does not exist in OCI (state stale?)" "terraform -chdir=${core_dir} apply"
        fi
        bastion_id="$(jq -r '.outputs.bastion_id.value // empty' <<<"$core_state")"
        if [[ -n "$bastion_id" ]] && [[ "$("${OCI[@]}" bastion bastion get --bastion-id "$bastion_id" --query 'data."lifecycle-state"' --raw-output 2>/dev/null)" == "ACTIVE" ]]; then
            ok "core Bastion active"
        else
            warn "no active Bastion in the core - private hosts are only reachable from inside the VCN"
        fi
    else
        fail "core state ${CORE_KEY} not found in ${STATE_BUCKET}" "build the core first: terraform -chdir=${core_dir} init -backend-config=backend.hcl && terraform -chdir=${core_dir} apply"
    fi

    # --- image and shape --------------------------------------------------------
    echo "Compute"
    ad="$("${OCI[@]}" iam availability-domain list -c "$COMPARTMENT" --query 'data[0].name' --raw-output 2>/dev/null || true)"
    if [[ -n "$ad" ]] && "${OCI[@]}" compute shape list -c "$COMPARTMENT" --availability-domain "$ad" --all --output json 2>/dev/null |
        jq -e --arg s "$SHAPE" '.data[] | select(.shape == $s)' >/dev/null; then
        ok "shape ${SHAPE} offered in ${ad##*:}"
    else
        fail "shape ${SHAPE} not offered in the first AD of ${REGION}" "pick another shape; list: oci compute shape list --profile ${PROFILE} -c <compartment OCID> --query 'data[].shape'"
    fi
    if [[ -n "$IMAGE_OCID" ]]; then
        if "${OCI[@]}" compute image get --image-id "$IMAGE_OCID" >/dev/null 2>&1; then ok "image ${IMAGE_OCID:0:24}... exists"; else fail "instance_image_ocid not found in ${REGION}" "remove instance_image_ocid to use the lookup"; fi
    else
        img="$("${OCI[@]}" compute image list -c "$COMPARTMENT" --operating-system "Oracle Linux" --operating-system-version "$OL_VERSION" \
            --shape "$SHAPE" --sort-by TIMECREATED --sort-order DESC --limit 1 --query 'data[0]."display-name"' --raw-output 2>/dev/null || true)"
        if [[ -n "$img" ]]; then ok "image lookup: ${img}"; else fail "no Oracle Linux ${OL_VERSION} image for ${SHAPE}" "set ol_version or shape in ${TFVARS}"; fi
    fi
fi

echo
if ((FAILS)); then
    echo "Not ready: ${FAILS} failure(s), ${WARNS} warning(s) - fix the FAIL lines above, then rerun."
    exit 1
fi
echo "Ready: ${WARNS} warning(s). Next: terraform -chdir=${LAYER_DIR} init -backend-config=backend.hcl && terraform -chdir=${LAYER_DIR} plan"
