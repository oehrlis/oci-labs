# Session State: cpu-patch-test Lab - 2026-08-21

> **Superseded by `state-cpu-lab-2026-08-23.md`.** Kept for the record.
> The claim that `feat/cpu-patch-test-lab` is unmerged is wrong - it is on `main`.

Resume point for the next session. Supersedes `state-cpu-lab-2026-08-19.md`
where the two disagree.

- Branch: `feat/cpu-patch-test-lab`, 9+ commits ahead of `main`, **not merged**
- Lab: **stopped, not destroyed** - the instance can be started again
- Gold image: in the `orarepo` bucket, so a rebuild is cheap either way

## What is proven now

A full reference run on a fresh host, 8 OCPU / 32 GB, ending green:

<!-- markdownlint-disable MD013 MD060 -->

| Step | Duration | Result |
| --- | --- | --- |
| Terraform apply | ~3 min | 33 resources |
| prereq, oradba, AutoUpgrade, keystore, download 19.31 | 14:31 - 14:34 | ok |
| `create_home` 19.31 **incl. gold image** | 14:34 - 14:54 (20 min) | 4.79 GiB artifact |
| `create_db` CPUDB | 14:56 - 15:29 (33 min) | CDB + PDB1 |
| baseline snapshot | seconds | 19.31.0.0.0, 2 PDBs, 0 invalid, 15 components |
| download 19.32 (`RECOMMENDED:19.32,JDK`) | ~3 min | MRP included: yes |
| `create_home` 19.32 | ~13 min | ok |
| deploy (out-of-place move) | ~12 min | oratab -> 19.32 |
| smoke test | ~2 min | PL/SQL, OJVM, Data Pump all PASS |
| verify | ~2 min | 4 hard + 4 soft criteria PASS |

<!-- markdownlint-restore -->

For comparison, at 2 OCPU / 16 GB `create_home` alone took 25 minutes and
`create_db` 38.

Final verification output:

```text
CPU patch test PASSED - CPUDB runs 19.32.0.0.0 from .../19.32/dbhome_1
bundled, members counted individually: DATABASE MRP 19.32.0.0.260818
8 file(s) fetched to ansible/reports/oradb01/
```

## Patch list strategy (decided this session)

```text
base   RU:<base>,JDK,OPATCH,OJVM,DPBP     explicit - the control group
target RECOMMENDED:<target>,JDK           what Oracle recommends this quarter
```

Resolved on 2026-08-21, a clean one-quarter delta across every component:

```text
19.31  RU 39034528  JDK 39791916  OPatch 6880880  OJVM 38906621  DPBP 39196236
19.32  RU 39472050  JDK 39791916  OPatch 6880880  OJVM 39222882  DPBP 39657094
       + MRP 39834034
```

Every download writes `patchset-<RU>.{json,txt}` with an explicit MRP yes/no.
In a plain RU quarter that flag reads `no` with no configuration change.

## Findings worth remembering

1. **19c gold images are unobtainable from Oracle.** `target_version=19` is the
   only release whose gold-image resolution goes through the Oracle Update
   Advisor, and `POST transport.oracle.com/v2/patchplanner/requests` answers
   HTTP 500. 21 and 23 skip the Updater and work. `gold_image=YES` takes the
   same path; `target_version=19.32` is rejected as not a single version.
   Every download job therefore pins `gold_image=NO`. Stefan is clarifying the
   19c situation with the Oracle PM.
2. **Self-made gold images work and are the real lever.** `create_gold_image` on
   a `create_home` job is accepted without a `source_home`. 20 minutes to build,
   4.79 GiB, and an install from it needs no MOS access at all. Naming rejects
   dots, hence `goldimage-db-19_31_0_0_0-linux-x64-ee-20260821.zip`.
3. **ARCHIVELOG is mandatory**, not a preference - without it the deploy dies in
   stage GRP after 22 seconds.
4. **A deploy that keeps its GRP blocks every later AutoUpgrade job**, including
   plain downloads, in the same `global_log_dir`. `-clear_recovery_data` does not
   help; only deploy can resume. Other jobs need their own log directory.
5. **`local_listener` broke silently after the move** - missing `LISTENER_<SID>`
   alias plus a short host name that resolves to IPv6 link-local first. The
   database was healthy and unreachable at the same time.
6. **An MRP is a bundle** - `opatch` registers its members, never the bundle
   number.
7. **Inbound connectivity to the public IP was broken all afternoon.** OCI flow
   logs recorded the SYNs as ACCEPT, the guest never saw them, its own egress
   kept working, and a replaced instance behaved identically. Everything ran
   through the OCI Bastion instead, which also verified that path for the first
   time.

## Open

- [ ] **Merge** `feat/cpu-patch-test-lab` into `main`, then push. Not done yet.
- [ ] **Reboot test** - still never run. `oradba-services.service` is enabled but
  has never started.
- [ ] **Gold-image install test** - the two-minute claim is unmeasured. Needs a
  read PAR for the artifact plus
  `-e db19_gold_image_file=... -e db19_gold_image_url=...`.
- [ ] **`rollback.yml` is untested.** Written carefully, never exercised. The
  restore point from this run exists, so the stopped instance still has
  everything needed to try it.
- [ ] **DPBP 19.31 applied `WITH ERRORS`** during `create_db` in the first
  attempt of the day. It was rolled back and superseded, and the rebuilt run is
  clean, but nobody has read the datapatch log to find out why.
- [ ] **`lab_count > 1`** (Gate 5) still untested. The gold image is what makes
  this practical.
- [ ] **`assign_public_ip = false`** now that the Bastion is proven. Forces an
  instance replacement, so it belongs to the next clean rebuild.
- [ ] **Consumer of the report JSON** unanswered - as long as nobody reads it,
  the schema is cheap to change.
- [ ] **`INJECT_FACTS_AS_VARS` deprecation** - the role uses `ansible_date_time`
  and friends as top-level variables throughout. Mechanical, role-wide.
- [ ] **Lint debt** - 7 ansible-lint findings and the markdownlint backlog, all
  in pre-existing files.

## Time-critical

- **Base image PAR expires 2026-08-28**, gold-image read PAR not yet minted.
  Re-mint with `make cpu-lab-par`.
- **Bastion sessions last 3 hours** and were re-created three times today.
  `make cpu-lab-bastion-session` then `make cpu-lab-bastion-tunnel`.

## Restarting the lab

```bash
make cpu-lab-start                 # boots the stopped instance
make cpu-lab-bastion-session       # sessions do not survive
make cpu-lab-bastion-tunnel
make cpu-lab-progress ANSIBLE_EXTRA="-e ansible_host=127.0.0.1 -e ansible_port=2222"
```

Every Ansible target needs that `ANSIBLE_EXTRA` override while the direct
inbound path stays broken.
