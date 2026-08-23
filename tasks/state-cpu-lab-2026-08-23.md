# Session State: cpu-patch-test Lab - 2026-08-23

Supersedes `state-cpu-lab-2026-08-21.md` and `state-cpu-lab-2026-08-19.md`.
Steering document is `tasks/roadmap-cpu-lab.md`.

- Branch: everything is on `main` and pushed, `v0.3.0` tagged.
- Lab: **stopped, not destroyed.** Database `CPUDB` is at **19.31.0.0.0** from
  the base home after the rollback test. `make cpu-lab-start` brings it back.
- Gold image: in the `orarepo` bucket, so a rebuild is cheap either way.
- oradba on the host: **1.0.4**, which is the minimum for a lab that survives a
  reboot.

## What is proven now

Beyond the reference run of 2026-08-21, three things that were open are closed.

### Rollback, previously untested

`make cpu-lab-rollback` against the restore point the deploy left behind:

```text
rolledback: 19.31.0.0.0, OPEN, 2 PDB(s), 0 invalid object(s), 15 component(s)
Rollback complete - CPUDB runs 19.31.0.0.0 from .../19.31/dbhome_1
PLAY RECAP: ok=20  changed=5  failed=0
```

The playbook asserts its own result and writes a `snapshot-rolledback`, so a
green run needs no manual check.

### Reboot, previously never run

Third attempt, green. The two before it were red and productive.

```text
Unit   : active
tnslsnr LISTENER
ora_pmon_CPUDB
systemd: Started Oracle listeners and databases (oradba)
```

17 seconds from the unit starting to the database being open, unattended, with
no profile loaded.

### The lint suite

`make lint` passes end to end - Terraform, Ansible, YAML, Markdown, Shell.

## What the reboot test cost and what it bought

It exposed six defects in oradba, all pre-existing in v1.0.0, all of the same
class: a bare `${VAR}` under `set -euo pipefail` aborts the script when the
caller's environment does not define it. Four oradba releases came out of it
(1.0.1 through 1.0.4). Details and the review scope are in
`~/Repos/own/oehrlis/oradba/tasks/review-brief-boot-path-2026-08-23.md`.

The important part for this repo: **oradba 1.0.4 or later is a hard
requirement** for a lab that has to survive a reboot. Earlier versions cannot
complete an unattended start.

## Fixed after the reboot test

All six findings are closed. Four are proven on the host, one is documented,
one is written but unexercised.

| # | Finding | State |
| --- | --- | --- |
| B1 | oradba never wired into the oracle profile | fixed, proven |
| B2 | `rollback.yml` leaves `oratab` at `:N` | fixed, **not exercised** |
| B3 | tunnel without `IdentitiesOnly` | fixed |
| B4 | Bastion sessions unstable, `UNREACHABLE` mid-run | fixed, proven |
| B5 | rollout cannot upgrade | documented |
| B6 | `/var/log/oracle` missing | fixed, proven |

B1, measured on the host - four empty values before, now:

```text
ORADBA_BASE=[/u00/app/oracle/local/oradba]
ORACLE_SID=[CPUDB]
ORACLE_HOME=[/u00/app/oracle/product/19.31/dbhome_1]
```

B4 is the one that matters for automation. Use `BASTION=1` on any Ansible
target and the tunnel is established, probed with a real command and re-created
if the session was dropped:

```bash
make cpu-lab-step TAG=oradba BASTION=1
```

**B2 is honestly unproven.** Exercising it needs a guaranteed restore point,
which needs another patch run, which needs MOS credentials from 1Password - and
`op` is not signed in in a non-interactive session. It sits exactly where
`rollback.yml` sat before this weekend: written carefully, never run.

## Also done

- **M1**: `cpu-patch-tests/tools/import_lab_results.py` plus
  `make import-lab`. Fills the report CSV from the lab artifacts. Committed
  locally in that repo, not pushed - your uncommitted work on `VERSION` and
  `data/2026-07.yaml` is next to it and untouched.
- **M2, partly**: `terraform/modules/core/` and `terraform/envs/core/` exist,
  validate, and plan cleanly against the live tenancy. **Not applied.**
  Migrating `cpu-patch-test` to consume the core was deliberately left alone -
  the stack is live, and both currently claim `10.29.0.0/16`, so the migration
  needs a decision rather than a copy-paste.

## Open in this repo

Two of them come from `cpu-patch-tests` rather than from here, surfaced by the
M1 converter on its first run.

- **The period data and the lab do not test the same patch list.** The period
  lists JDK `39329591`, the lab installs `39791916`, and the lab tests DPBP
  `39657094` which the period does not track. Combo patches, GI RU and the
  Windows bundle are legitimately absent from a single-instance Linux lab. One
  of the two JDK numbers is wrong and it is worth finding out which.
- **`results.matrix` was never filled automatically for the database.**
  `import_test_results.py` mapped the `db` product to `oracle database` while
  every period since 2025-04 labels its rows `RDBMS 19.0.0.0`. Fixed and
  verified by comparison. The overview had been maintained by hand without
  anyone knowing why.
- **`INJECT_FACTS_AS_VARS` deprecation** in the role, mechanical and role-wide.
- **Migrating `cpu-patch-test` onto the shared core**, the rest of M2.

## Still untested

- **Gold-image install.** The two-minute claim remains unmeasured. Recommended
  as a second instance via `lab_count=2` so the evidence host survives and
  Gate 5 gets tested at the same time.
- **`lab_count > 1`.** Untouched.
- **`assign_public_ip = false`.** Forces an instance replacement, belongs to the
  next clean rebuild.
- **DPBP 19.31 applied `WITH ERRORS`** during the first `create_db` attempt on
  2026-08-21. It was rolled back and superseded and the rebuilt run is clean,
  but nobody has read the datapatch log.

## Not a deadline

The base image PAR expiry was carried forward from the 08-21 state document as
if it were time critical. It is not: two PARs exist, and minting a new one is a
single `make cpu-lab-par`.

## Restarting the lab

```bash
make cpu-lab-start
make cpu-lab-progress BASTION=1
```

`BASTION=1` replaces the old `ANSIBLE_EXTRA` dance: it sets host and port and
makes the tunnel a prerequisite, retrying and re-creating the session as needed.

For a patch run you also need `eval $(op signin)` - the MOS credentials come
from 1Password.
