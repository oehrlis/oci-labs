# Lessons - oci-labs

Lessons learned the hard way that are not written down elsewhere in the repo. Facts that already live in a runbook,
a role default or the CHANGELOG are not repeated here - the runbooks are the reference:
`docs/runbook-cpu-patch-lab.md` (Bastion, AutoUpgrade, gold images, cost), `docs/datasafe-demo.md`,
`docs/runbook-cost-report.md`. Sources of the older entries are the state and plan files removed on 2026-11-23
(`git show <commit>:tasks/<file>`, commits in the CHANGELOG under Unreleased - Removed).

## AutoUpgrade and patching

- **A baseline built after the next RU is not the baseline you named.** AutoUpgrade resolves `RECOMMENDED`, `MRP`,
  `OPATCH` and `JDK` against MOS on the run day: a "19.32" home built after 19.33 was released contains the MRP that
  came with 19.33 (19.32.0.0.261020). Homes built earlier with pinned patches then fail `analyze` ("OPATCH must be
  included", missing MRP). Name the real from-version in the report and pin the base MRP explicitly.
  Why: CPU 2026-10, 2026-10-23 (`plan-cpu-2026-10-tests.md`, last content `141bca9`).
- **`rollback restore` takes whatever restore point it finds.** A Guaranteed Restore Point left by an earlier run is
  used even when it belongs to another run - data loss without a warning. AutoUpgrade prints "Drop GRP SUCCESS"
  while the GRP stays (correct with `drop_grp_after_patching=no`, but misleading) and creates a GRP with the same
  name on the next run. Drop the old GRP before every new run.
  Why: CPU 2026-10 lab runs (`plan-cpu-2026-10.md`, last content `83f07f5`).
- **After deploy PDB$SEED is READ WRITE.** Reproduced on 19c and 26ai, the alert log shows READ ONLY, then READ
  WRITE. Close it and reopen READ ONLY; check it in verify, not by eye.
  Why: CPU 2026-10 (`plan-cpu-2026-10-tests.md`, last content `141bca9`).
- **Check the home before the smoke test.** `expdp` from the target home against a database still running from the
  old home hangs for more than ten minutes instead of failing. Assert oratab and the running home first.
  Why: CPU 2026-10 (`plan-cpu-2026-10-tests.md`, last content `141bca9`).

## Network

- **NSG and security list add up.** OCI evaluates both as a union, so an NSG rule with source 0.0.0.0/0 defeats the
  CIDR limit of the security list. A module default of 0.0.0.0/0 opens every stack that uses it
  (`allowed_ssh_cidrs` in `modules/network`, the Windows AD NSG - RA-oci-labs-016/021 in `review-register.md`).
  Why: repo audit 2026-10-08; WireGuard 51820 was open on every public subnet until 2026-10-23.

## Working method

- **Verify before carrying forward.** A "time critical" PAR deadline was copied from an old state file unchecked
  (re-minting is one make call); half of the M3 plan rested on `odb_autoupgrade` although the lab never used it - one
  grep would have shown it; oradba tag v1.0.3 did not contain the fix its message described. Check the tagged
  content and the code, not the note or the patch output.
  Why: 2026-08-23 to 2026-08-27 (`roadmap-cpu-lab.md`, last content `787d0e0`).
- **A mechanical count is not a measurement.** `INJECT_FACTS_AS_VARS` was estimated at 82 references, the real
  number was 12 in 8 files - the count included the vendored collections tree. Review scans made the same mistake
  (closing fences counted as bare fences, "CLAUDE.md missing" while it sat in the root). Exclude vendored trees and
  look at a sample before acting on a number.
  Why: roadmap 2026-08-23 and repo audit 2026-10-08.
- **A state file is a snapshot, not a task list.** Eight state files carried 50 unchecked items, nearly all of them
  done or overtaken by later work; nobody ticked them. Open work lives in `tasks/open-work.md`, the newest
  `state-*.md` is only the re-entry point.
  Why: tasks consolidation 2026-11-23.
