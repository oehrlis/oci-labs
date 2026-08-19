# Session State: cpu-patch-test Lab - 2026-08-19

Resume point for the next session. Companion to `plan-cpu-lab.md`.

- Branch: `feat/cpu-patch-test-lab` (pushed, not merged into `main`)
- Commit: `1097ea5`
- Lab: **still deployed and running** in OCI - costs money, see Teardown below

## What is proven

The full chain ran against a live Oracle Linux 8.10 host and was verified:

<!-- markdownlint-disable MD013 -->

| Step | Tag | Result |
| --- | --- | --- |
| Terraform | - | 40+ resources, inventory generated |
| OS prerequisites | `prereq` | 43 ok, idempotent |
| oradba | `oradba` | release installer to `/u00/app/oracle/local/oradba` |
| AutoUpgrade | `autoupgrade` | 26.5, version gate works |
| MOS credentials | `credentials` | keystore auto-login, MOS connection confirmed |
| Media | `download` | gold image attempted, fell back, 4.7 GB patches + 2.9 GB base image |
| Base home | `create_home` | 19.31, `Release Update 19.31.0.0.260421` |
| Database | `create_db` | CDB `CPUDB` OPEN, `PDB$SEED, PDB1`, 0 invalid objects |
| Target home | `patch` | 19.32 built |
| Out-of-place move | `patch` | 69 ok, oratab -> 19.32 |
| Verification | `verify` | 17 ok, `version_full 19.32.0.0.0` |

<!-- markdownlint-restore -->

Registry after the move:

```text
RU_APPLIED=19.3.0.0.0   (29517242)   base image
RU_APPLIED=19.31.0.0.0  (39034528)   create_home
RU_APPLIED=19.32.0.0.0  (39472050)   deploy
INVALID_OBJECTS=0
```

Idempotency: three consecutive `install` runs went 5 changed -> 4 -> **1**, and
the last one is `base_ssh : Allow SSH port in SELinux`, a pre-existing role that
was not touched.

## Timings on the current sizing (2 OCPU / 16 GB)

- `create_home` (19.31): ~25 min
- `create_db`: ~38 min (15:01 - 15:39)
- `create_home` (19.32) + `deploy`: ~16:00 - 16:39

Defaults were raised to **8 OCPU / 32 GB** and SGA to 8 GB but **not applied** -
a shape resize reboots the instance. The next build gives a clean baseline.

## Open questions and decisions

- [ ] **Gold image for 19c** - Stefan researches. Measured: `gold_image` is
  rejected on any download job in 26.5 (all prefixes, `AUTO` and `YES`); only
  `create_home` + `AUTO` reaches the Oracle Updater, where
  `/v2/patchplanner/requests` returned HTTP 500 on 6 of 6 calls while
  `/registration` succeeded 16 of 16. `target_version=23` works, `19` does not -
  reproduced on the lab host **and** on Stefan's Mac via `make au-download-19-linux`.
  A 19.32 gold image downloaded fine on 2026-08-18, so this is a service-side
  regression. Evidence for an SR: `<log_dir>/cfgtoollogs/patch/auto/aru/ous.log`.
  Retry in a few days; `gold_image=AUTO` picks it up with no code change.
- [ ] **Reboot test** - never run. The new `oradba-services.service` is enabled
  but has never started. Combine with applying the 8-OCPU resize, which reboots
  anyway. Checks: DB and listener come up, THP unit active, mounts fine.
- [ ] **oradba upstream work** - two things belong in oradba, not here:
  a set of dbca response-file/template variants (replacing the local
  `dbca.rsp.j2`), and the systemd unit next to `oradba_services_root.sh`.
  Both are marked `TODO` in the files.
- [ ] **Merge decision** - `feat/cpu-patch-test-lab` -> `main`, PR or fast-forward.
- [ ] **Bastion** - implemented but `enable_bastion` is still `false` and it has
  never been applied. Decide whether it replaces the IP allow-list, which would
  allow `assign_public_ip = false`.
- [ ] **Lint debt** - 15 `ansible-lint` findings and ~184 markdownlint findings,
  all in pre-existing files (`fail2ban`, `crowdsec`, `base_ssh`, `firewall`, four
  empty playbook stubs, `docs/`). Everything new is clean. Separate cleanup pass?
- [ ] **`lab-db19eng.yml`** is an empty stub and now redundant next to
  `lab-cpu-patch.yml` - delete or fill?
- [ ] **`network` module wart** - `app`/`windows` subnets are optional now, but
  `tools/validate.sh` still references the long-gone `infra/stacks` layout.

## Time-critical

- **PAR expires 2026-08-26** (7 days, deliberately short for Accenture
  monitoring). After that `download` fails with a clear message.
  Re-mint: `make cpu-lab-par`
- **SSH allow-list** is pinned to one IP. After a network change:
  `make cpu-lab-allow-ip`

## Teardown / next build

```bash
make cpu-lab-destroy          # asks for confirmation
make cpu-lab-cycle            # apply -> install -> patch -> verify
make cpu-lab-watch            # follow progress
```

The full cycle on 8 OCPU is the next milestone: it validates from zero and gives
the timings for the runbook.

## Gates from plan-cpu-lab.md

- Gate 1 Terraform: done
- Gate 2 Ansible install: done and verified
- Gate 3 AutoUpgrade patch: done and verified
- Gate 4 Makefile + runbook: done
- Gate 5 count + documentation: `lab_count` wired, plan-tested at 1; **never
  tested with `lab_count > 1`**
- Gate 6+ Docker variant, Resource Manager stack, 26ai env: not started
