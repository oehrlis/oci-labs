# Session State: cpu-patch-test Lab - 2026-08-23

Supersedes `state-cpu-lab-2026-08-21.md` and `state-cpu-lab-2026-08-19.md`.
Steering document is `tasks/roadmap-cpu-lab.md`.

- Branch: everything is on `main` and pushed. The claim in the 08-21 state
  document that `feat/cpu-patch-test-lab` was unmerged was already wrong when
  it was written.
- Lab: running, database `CPUDB` open at **19.31.0.0.0** from the base home
  after the rollback test.
- Gold image: in the `orarepo` bucket, so a rebuild is cheap either way.

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

## Open in this repo

Numbered as in `tasks/roadmap-cpu-lab.md` section 4.

- **B1** oradba is never wired into the oracle user's profile. The role runs
  the installer as root, so the profile line lands in `/root/.bash_profile`.
  `su - oracle -c 'echo $ORACLE_HOME'` is empty on the lab.
- **B2** `rollback.yml` leaves `oratab` at `:N` and never restores `:Y`. After a
  successful rollback the database no longer starts on boot. This turns a
  reboot test into a false green.
- **B4** Bastion sessions are less stable than the Makefile assumes: a fresh
  session needs seconds before it accepts SSH, and one session was `DELETED`
  three minutes into a three hour TTL. Blocks unattended runs, roadmap M6.
- **B5** The oradba rollout cannot upgrade. It needs
  `db19_oradba_force_install=true`, which is undocumented.
- **B6** `/var/log/oracle` is neither created nor handed to `oracle:oinstall`.

Fixed on the way: **B3**, the Bastion tunnel needed `IdentitiesOnly=yes`.

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
make cpu-lab-bastion-session && make cpu-lab-bastion-tunnel
make cpu-lab-progress ANSIBLE_EXTRA="-e ansible_host=127.0.0.1 -e ansible_port=2222"
```

Every Ansible target needs that `ANSIBLE_EXTRA` override while the direct
inbound path stays broken. Retry the tunnel if it does not come up on the first
attempt, see B4.
