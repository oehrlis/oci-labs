#!/usr/bin/env python3
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: gen_fleet_snapshot.py
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-10-19
# Version....: 0.1.0
# Purpose....: Generate a SYNTHETIC Data Safe fleet snapshot for LRN6087, in the
#              format ds_target_list.sh writes with --save-json and reads with
#              --input-json: {"data": [<TargetDatabaseSummary>, ...]}, the
#              kebab-case output of "oci data-safe target-database list --all".
# Notes......: Stdlib only, deterministic (--seed). Every value is invented:
#              names demo-cluNN_cdbNN_<pdb>, fake OCIDs, a fake compartment,
#              description "SAMPLE DATA", freeform tag sample=true. Nothing is
#              derived from a real tenancy. Display names follow the
#              odb_datasafe convention <cluster>_<sid>_<pdb|CDBROOT>, so the
#              overview and problems parsers work; two names are deliberately
#              non-standard to show the naming check.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------
"""Generate a synthetic Data Safe target snapshot (sample data only)."""

import argparse
import datetime as dt
import json
import random
import string
import sys

SAMPLE_DESCRIPTION = "SAMPLE DATA - synthetic target for the LRN6087 demo, not a real database"
REGION = "eu-zurich-1"
# Short unique part on purpose: visibly fake and not a well-formed tenancy OCID.
COMPARTMENT_IDS = {
    "prod": "ocid1.compartment.oc1..samplecompartmentprod",
    "test": "ocid1.compartment.oc1..samplecompartmenttest",
    "dev": "ocid1.compartment.oc1..samplecompartmentdev",
}
CONNECTORS = ["sample-conn-01", "sample-conn-02"]

# lifecycle-details wording follows Data Safe messages; the keywords match the
# classifier in ds_target_list.sh (classify_needs_attention_issue).
NEEDS_ATTENTION_REASONS = [
    "ORA-01017: invalid username/password; logon denied",
    "ORA-28000: The account is locked.",
    "Login timeout: connection to the target database could not be established within 60 seconds",
    "Failed to connect to the target database through on-premises connector {conn}: connector is not reachable",
    "Failed to fetch connection details for the target database",
    "ORA-28001: the password has expired",
    "ORA-12514: TNS:listener does not currently know of service requested in connect descriptor",
]
INACTIVE_REASONS = [
    "Target database deactivated by user",
    "Target database deactivated - planned decommissioning (sample)",
]
FEATURES_FULL = ["ASSESSMENT", "AUDIT_COLLECTION", "AUDIT_SETTING", "DATA_DISCOVERY", "MASKING"]
FEATURES_BASE = ["ASSESSMENT", "AUDIT_COLLECTION"]


def fake_ocid(rng: random.Random, resource: str) -> str:
    """Return a well-formed but random OCID (lowercase base32-like alphabet)."""
    alphabet = string.ascii_lowercase + "234567"
    unique = "an" + "".join(rng.choice(alphabet) for _ in range(58))
    return f"ocid1.{resource}.oc1.{REGION}.{unique}"


def build_fleet(rng: random.Random, clusters: int) -> list:
    """Build the list of (cluster, sid, db, env) tuples - CDB root plus PDBs."""
    envs = ["prod", "prod", "prod", "test", "test", "dev"]
    fleet = []
    for idx in range(1, clusters + 1):
        cluster = f"demo-clu{idx:02d}"
        sid = f"cdb{idx:02d}"
        env = envs[(idx - 1) % len(envs)]
        fleet.append((cluster, sid, "CDBROOT", env))
        for pdb in range(1, rng.randint(2, 5) + 1):
            fleet.append((cluster, sid, f"pdb{pdb:02d}", env))
    return fleet


def make_target(rng, cluster, sid, db, env, state, reason, base_time, display_name=None):
    """Return one target summary in OCI CLI kebab-case."""
    ctype = "cdbroot" if db == "CDBROOT" else "pdb"
    created = base_time - dt.timedelta(days=rng.randint(30, 700), minutes=rng.randint(0, 1440))
    created_str = created.strftime("%Y-%m-%dT%H:%M:%S.") + f"{rng.randint(0, 999):03d}000+00:00"
    exacc = cluster in ("demo-clu01", "demo-clu02")
    tagged = rng.random() > 0.1
    defined_tags = {
        "Oracle-Tags": {"CreatedBy": "sample-automation", "CreatedOn": created_str},
    }
    if tagged:
        defined_tags["DBSec"] = {
            "Environment": env,
            "ContainerType": ctype,
            "ContainerStage": f"{ctype}-{env}",
            "Classification": "undef",
        }
    return {
        "associated-resource-ids": [],
        "compartment-id": COMPARTMENT_IDS[env],
        "database-type": "DATABASE_CLOUD_SERVICE" if exacc else "INSTALLED_DATABASE",
        "defined-tags": defined_tags,
        "description": SAMPLE_DESCRIPTION,
        "display-name": display_name or f"{cluster}_{sid}_{db}",
        "features": FEATURES_FULL if env == "prod" else FEATURES_BASE,
        "freeform-tags": {"sample": "true", "container-type": ctype, "stage": env},
        "id": fake_ocid(rng, "datasafetargetdatabase"),
        "infrastructure-type": "CLOUD_AT_CUSTOMER" if exacc else "ON_PREMISES",
        "lifecycle-details": reason,
        "lifecycle-state": state,
        "system-tags": {},
        "time-created": created_str,
    }


def generate(seed: int, clusters: int, needs_attention: int, inactive: int) -> dict:
    """Generate the snapshot payload."""
    rng = random.Random(seed)
    base_time = dt.datetime(2026, 10, 19, 6, 0, tzinfo=dt.timezone.utc)
    fleet = build_fleet(rng, clusters)

    pdb_positions = [i for i, entry in enumerate(fleet) if entry[2] != "CDBROOT"]
    picked = rng.sample(pdb_positions, needs_attention + inactive)
    na_set = set(picked[:needs_attention])
    inactive_set = set(picked[needs_attention:])
    # One CDB root in NEEDS_ATTENTION as well - a connector problem hits the root too.
    root_na = next(i for i, entry in enumerate(fleet) if entry[2] == "CDBROOT" and entry[0].endswith("04"))

    targets = []
    reasons = list(NEEDS_ATTENTION_REASONS)
    for i, (cluster, sid, db, env) in enumerate(fleet):
        state, reason = "ACTIVE", None
        if i in na_set or i == root_na:
            state = "NEEDS_ATTENTION"
            reason = reasons[len([t for t in targets if t["lifecycle-state"] == "NEEDS_ATTENTION"]) % len(reasons)]
            reason = reason.format(conn=rng.choice(CONNECTORS))
        elif i in inactive_set:
            state, reason = "INACTIVE", rng.choice(INACTIVE_REASONS)
        targets.append(make_target(rng, cluster, sid, db, env, state, reason, base_time))

    # Two deliberately non-standard names (naming check in --problems).
    targets.append(make_target(rng, "demo-legacy", "", "", "test", "ACTIVE", None, base_time,
                               display_name="sample-legacy-db"))
    targets.append(make_target(rng, "demo-clu99", "cdb99", "pdb01", "dev", "ACTIVE", None, base_time,
                               display_name="demo-cdb99-pdb01"))
    return {"data": targets}


def main() -> int:
    """CLI entry point."""
    parser = argparse.ArgumentParser(description="Generate a synthetic Data Safe fleet snapshot (sample data).")
    parser.add_argument("-o", "--output", default="-", help="output file (default: stdout)")
    parser.add_argument("--seed", type=int, default=6087, help="random seed (default: 6087)")
    parser.add_argument("--clusters", type=int, default=12, help="number of demo CDBs (default: 12)")
    parser.add_argument("--needs-attention", type=int, default=6, help="PDBs in NEEDS_ATTENTION (default: 6)")
    parser.add_argument("--inactive", type=int, default=3, help="PDBs in INACTIVE (default: 3)")
    args = parser.parse_args()

    payload = generate(args.seed, args.clusters, args.needs_attention, args.inactive)
    text = json.dumps(payload, indent=2) + "\n"
    if args.output == "-":
        sys.stdout.write(text)
    else:
        with open(args.output, "w", encoding="utf-8") as handle:
            handle.write(text)
        states = {}
        for target in payload["data"]:
            states[target["lifecycle-state"]] = states.get(target["lifecycle-state"], 0) + 1
        print(f"wrote {len(payload['data'])} sample targets to {args.output}: {states}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
