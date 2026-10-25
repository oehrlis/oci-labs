# Changelog

All notable changes to this project will be documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Security

- **network**: `allowed_wireguard_cidrs` defaults to `[]` (was `0.0.0.0/0`) - no stack passes it and none runs
  WireGuard, yet every public subnet had UDP 51820 open to the internet. Opt-in like `allowed_ssh_cidrs`; the next
  `apply` of core, cpu-lab and datasafe-demo removes the rule

### Changed

- `db19_engineering`: `db_release` 19 | 26 with `db_release_profiles` - OS check, preinstall RPM,
  AutoUpgrade `target_version` (26ai: 23, the tool's value), gold image, patch lists, dbca schema,
  `CV_ASSUME_DISTID` and `binopt.uniaud` per release; the `db19_*` names stay, so `oracle_db_native`
  keeps working. A guard rejects a release that does not fit the RU strings
- `db19_engineering`: both releases try the gold image first (`db19_try_gold_image` true,
  `gold_image=YES`) instead of the 19.3.0 base image plus patches - AutoUpgrade 26.6 serves 19c gold
  images again (Lauf A). 19c not yet run on this path; without a gold image it falls back to the
  base image. Also affects the 19c home of `oracle_db_native` (datasafe-demo)
- **datasafe-demo**: odb_datasafe default 1.3.1 (first release with `ds_target_register.sh --type onprem`),
  sha256 from the release asset.
- **lint-shell** also checks `demos/`.
- **RA-oci-labs-014**: `enable_auto_stop` default changed from `false` to `true`
  in `terraform/envs/cpu-patch-test`. Idle labs stop nightly at 18:00 UTC.
  AutoUpgrade runs must set `enable_auto_stop = false` explicitly to avoid
  interruption. Description updated, tfvars.example and docs revised.
- **RA-oci-labs-005 + 030**: Tenancy namespace `<namespace>`, OCI profile
  `<oci_profile>` and compartment `<compartment_name>` replace the real values in
  all docs, examples, CHANGELOG and code comments. Namespace grep returns 0 matches.
  Code defaults in Makefile and `variables.tf` stay (overrideable).

### Removed

- **RA-oci-labs-018**: Deleted `tools/infra-tools/scripts/setup_common_os.sh` -
  dead code with a known default credential (`oracle:oracle`), no callers in repo.
- **RA-oci-labs-034..039**: Deleted 6 empty placeholder docs:
  `ansible/docs/ansible-workflow.md`, `ansible/docs/architecture-config.md`,
  `ansible/docs/profiles-overview.md`, `ansible/inventories/README.md`,
  `docs/lab-odb19eng-single.md`, `docs/lab-odb19sec-dg.md`.
  Links in `docs/architecture-overview.md` updated; planned labs and Ansible
  migration roadmap added to `tasks/roadmap-cpu-lab.md`.

### Added

- `db19_engineering` evidence per run (`tasks/evidence.yml`): before the patch / rollback a run
  marker plus `opatch lspatches` and `lsinventory` of every home; after verify / rollback the same
  again, the AutoUpgrade job logs, the sqlpatch / datapatch logs and the alert log since the marker,
  report and snapshots - fetched to `ansible/reports/<host>/<SID>-<base>-to-<target>-<time>/` with
  an `index.md`. Not yet run on a host
- `make` secrets helper takes `LAB_MOS_USER` / `LAB_MOS_PASS` from the environment when set - the
  cpu-patch-tests `lab-run` reads 1Password once at its start, so a run needs nobody later
- Lab profiles from cpu-patch-tests (`make lab-profile`, passed by `make lab-run` as `-e @file`):
  `wls_engineering` takes the SPB file names per version from `wls_spb`; `db19_engineering`
  asserts that the target home carries the target RU, so a new profile against old tfvars stops
  instead of patching into the previous quarter's home
- **cpu-patch-wls** (`terraform/envs/cpu-patch-wls`): one WebLogic host on the shared core (OL9,
  4 OCPU / 32 GB), inventory group `cpu_wls_hosts`
- Role `wls_engineering` and playbook `lab-wls-patch.yml`: WebLogic 12.2.1.4 / 14.1.1 / 14.1.2 /
  15.1.1 side by side - JDK, Oracle home, baseline SPB via SPBAT, domain (AdminServer + ms1,
  administration port, SSL), REST smoke test with a static WAR, the SPB under test in place
  (home and inventory archived first) and its rollback with `opatch nrollback` - the swap at the
  same path from the first draft was dropped on 2026-10-24. Not yet run on a host
- `make cpu-lab-repo-par`: read-by-name PAR on the flat `orarepo` bucket, no listing; passed to
  Ansible as `lab_repo_url` in the 0600 vars file
- **cpu-patch-26ai** (`terraform/envs/cpu-patch-26ai`): 26ai host for the CPU tests on the shared
  core - VCN, DB subnet and Bastion are read from `envs/core` via `terraform_remote_state`, the stack
  creates only host, NSG, keys and inventory (OL9, 8 OCPU / 32 GB, no public IP). First stack of the
  layout "one CPU network, one stack per product/release"
- `make cpu-lab-* CPU_ENV=<stack>`: every CPU lab target works on the chosen stack (default
  `cpu-patch-test`), with its own Bastion tunnel port (2222 / 2224 / 2225 - 2223 is the
  datasafe-demo tunnel)
- **Patch PAR fallback for the target RU**: `make cpu-lab-patch-par PATCH_PREFIX=...`
  mints a read PAR (AnyObjectRead + ListObjects) on a prefix of the `orarepo`
  bucket, where `cpu-patch-tests` uploads its downloaded patch set. With it,
  `db19_engineering` stages the target RU from the bucket into `/opt/stage`
  and runs AutoUpgrade with `download=no`; MOS on the host stays the default.
  The URL travels in the 0600 vars file, not through Terraform.
  `cpu-lab-par-revoke` now revokes it together with the base-image PAR (and no
  longer stops early when no base-image PAR exists). Runbook: "Fallback - target
  RU from the bucket instead of MOS".
- **oradba.automation lab test**: `ansible/playbooks/lab-oradba-automation.yml`
  runs the collection's `site_setup`, `patch_download`, `home_create`,
  `patch_apply` and `patch_rollback` against the real `CPUDB` of the
  cpu-patch-test lab, one tag per step, rollback only by tag. Collection
  variables live in `ansible/inventories/cpu-patch-test/group_vars/`, loaded only
  by the new targets `make cpu-lab-coll-install` (v0.2.0, sha256-pinned, into
  `ansible/collections`), `cpu-lab-coll-check` (offline), `cpu-lab-coll STEP=...`
  and `cpu-lab-coll-rollback MODE=restore|home`. Engine pinned to 0.6.1.
  Runbook: `docs/runbook-oradba-automation-lab.md`.

- **datasafe-demo**: new stack `terraform/envs/datasafe-demo` for the LRN6087 Data Safe demo (Oracle AI
  World 2026) - own core (VCN, Bastion), one OL8 x86 host (4 OCPU, 32 GB) with a data volume on `/u01`,
  daily START and STOP schedules from `schedule_profile` (`cest`, `cet`, `pdt`, `off`; working hours
  07:00-22:00 local, cron in UTC) plus the IAM policy the schedules need, optional instance principal.
  Ansible role `oracle_db_native` and playbook `lab-datasafe-demo.yml`: native Oracle Database 19c EE
  (CDB19, PDB19A/PDB19B) and Oracle AI Database 26ai EE (CDB26, PDB26A/PDB26B), homes through AutoUpgrade
  (19c via `db19_engineering` tasks, unchanged; 26ai via `create_home` with the MOS RU gold image, zip
  fallback), one listener, OraDBA, Data Safe service accounts, odb_datasafe 1.2.1, on-premises connector as
  systemd service registered in OraDBA (`oradba_homes.sh`, `ds_connector_register_oradba.sh`). Demo scripts
  (six steps: AIPDB1 created live in CDB26, registration through `ds_target_register.sh --type` when
  available, else OCI CLI; connector managed with OraDBA), reset, Bastion tunnel and a synthetic fleet
  snapshot generator in `demos/datasafe-lrn6087/`. `dsdemo-*` Makefile targets incl. `dsdemo-schedule`,
  `dsdemo-par` and `dsdemo-par-revoke`; runbook `docs/datasafe-demo.md`. Decisions 2026-10-20: targets
  are registered as `ON_PREMISES` (`--type onprem`, OCI CLI payload without `instanceId`); step 6 restarts
  the connector and waits until Data Safe reports it ACTIVE (timeout); 19c and 26ai RUs are not pinned by
  default (latest at install time, optional `db19_ru` / `db26_ru`, resolved releases reported by verify);
  odb_datasafe version and SHA-256 overridable from Terraform for the 1.3.0 bump (default stays 1.2.1).
- **oracle_db_host**: optional `egress_https_only` (NSG egress TCP 443 plus intra-VCN). Default `false`;
  a `moved` block keeps existing stacks free of a rule replacement.
- **Secret scan with OCI rules**: `.gitleaks.toml` extends the gitleaks
  defaults with rules for OCI pre-authenticated request URLs, real OCIDs and
  API key fingerprints - the defaults find none of them. The GitHub Actions
  job `.github/workflows/gitleaks.yml` scans the full history on every push
  and pull request (checkout pinned by SHA, gitleaks by version and SHA-256).
  The reviewed historical findings are allowlisted by commit, path and rule.
- **`make hooks`** installs a gitleaks pre-commit hook
  (`tools/git-hooks/pre-commit`); **`make lint-secrets`** scans the history
  and is part of `make lint`.
- **README.md, SECURITY.md, LICENSE (Apache-2.0)** - the public repo had no
  landing page, no reporting path and no license file.
- **Review lens and register** (`docs/review-lens.md`,
  `tasks/review-register.md`) from the first `/repo-audit`: history findings
  in 93d3f77 and f70530f are recorded as accepted (owner decision, no
  history rewrite), open gate gaps stay tracked there.
- **terraform/envs/core applied**: the shared core stack is no longer only
  validated. `chzh-l-core-01` in tenancy `<namespace>` - VCN, three subnets,
  IGW and NAT, three route tables, three security lists, VCN flow logs, one
  Bastion - 20 resources, re-plan without drift, all 19 OCI resources tagged
  `core_owner = "core"`. Nothing consumes it yet: `cpu-patch-test` still owns
  its own network on the same CIDR in a separate VCN, untouched while its
  database is live. The two coexist because they are never peered.
- **assert_vars.yml**: an assertion that the `date_time` fact is present. Two
  artifact names are derived from it - the cputest report stem and the gold
  image name - and neither carries a fallback. Without the fact they rendered
  without a date, so a second run would overwrite the first run's evidence
  under an identical name instead of failing. Found by rendering the changed
  expressions offline against an empty fact dict.
- **lint-terraform** names every env it skips (no `provider.tf`) instead of
  a silent `continue`; **lint-shell** also checks `tools/git-hooks/`.

- **facts are addressed as `ansible_facts['name']`** throughout the Ansible
  layer, and `inject_facts_as_vars = False` is pinned in `ansible.cfg`. Ansible
  deprecated the injected top-level `ansible_<name>` variables and will flip
  that default; pinning it now means a missed reference fails loudly here
  instead of silently working until the default changes. Twelve references in
  eight files - the roadmap's "mechanical, role-wide" estimate came from a
  count that included the vendored collections tree and connection variables
  such as `ansible_user`, which this deprecation does not touch.

- **assign_public_ip defaults to false** in `envs/cpu-patch-test` and
  `modules/oracle_db_host`. The Bastion path is proven (finding B4), so a lab
  host has no reason to be reachable from the internet. The switch also selects
  the subnet and the addresses the generated Ansible inventory is built from, so
  under the new default every Ansible target needs `BASTION=1` - now stated in
  the env README and `terraform.tfvars.example`, and the README no longer claims
  a private host needs a jumphost or DRG/VPN. The running lab sets the value
  explicitly and is unaffected.

### Fixed

- `db19_engineering`: with a gold image of the target staged, the deploy runs `download=no` too.
  With `download=yes` it asked the Update Advisor to build the gold image again - 5 GB more on
  2026-10-23, and on 2026-10-25 a rejected request (UPD-02008 Invalid Authorization) that failed
  the analyze
- `db19_engineering`: every PDB is opened and its state saved after dbca and again before a patch
  (`tasks/pdbs_open.yml`). dbca saves no state, so after an instance restart PDB1 sat MOUNTED and
  AutoUpgrade failed in PREFIXUPS / PRE_FIXED_OBJECTS with ORA-20011 / ORA-01219 (26ai, 2026-10-24,
  before the downtime - the database stayed untouched)
- **datasafe-demo**: IAM resources (scheduler policy, instance-principal dynamic group and policy) via an
  `oci.home` provider and `home_region` - tenancies whose home region differs from the deployment region
  (Trivadis: FRA vs. ZRH) rejected them with 403 NotAllowed
- **datasafe-demo** fresh-host install (2026-10-22/23): `getent` result from `ansible_facts` (ansible-core 2.21),
  26ai gold image downloaded before `create_home`, connector `setup.py` with `JAVA_HOME`, `oracle_cman_home` as the
  installed marker, the CMAN started by `setup.py` stopped before systemd takes over, OraDBA registration batch
  (`--alias`, stdin)
- `db19_engineering`: the deploy job switches to `gold_image=YES` when a gold image of the target RU
  is staged. With `NO` and no base image in the folder, analyze stopped with "A usable base image
  file is not found" (26ai 2026-10-23, Lauf A finding 7). The patch-set manifest reads the gold
  download on the gold path - it listed the base RU's patches and verify reported a false
  "missing 39578879"; fix not yet run on a host. Known: the deploy downloads the gold image a
  second time (about 5 GB)
- `db19_engineering`: the oracle-user check read `getent_passwd`, which current ansible-core no
  longer injects as a variable - it failed on every fresh host although the preinstall RPM had
  created the user. Reads `ansible_facts['getent_passwd']` now (affects 19c too)
- `db19_engineering`: the gold-image path works end to end. The download template lacked
  `dl1.gold_image=YES` (AutoUpgrade then fetches individual patches only), and create_home never
  used the downloaded image. create_home now builds from the newest `db_goldimage_<RU>_*.zip` via
  `GOLDIMAGE:`; 19c falls back to `gold_image=AUTO` plus the base image when none came down. The
  download stamp has its own name on the gold path. Verified on the 26ai host 2026-10-23: gold image
  23.26.3 (RU + OCW + MRP fixes) downloaded, home built, CDB created in 12.5 min
- `db19_engineering` smoke test: asserts first that oratab points at the target home
  (new `tasks/target_home_active.yml`, shared with `verify.yml`). Before, `cpu-lab-verify`
  against a database still on the base home ran `expdp` from the target home and hung for
  more than 10 minutes (2026-10-23, 19.32 tools against CPUDB on 19.31)
- `db19_engineering` smoke test: the `CPUSMOKE` password no longer shows up in `ps`. The
  schema SQL goes to sqlplus on stdin, the Data Pump parfile is written by Ansible (0600)
  and removed even when the round trip fails. Before, both heredocs sat in the argv of the
  `/bin/bash -c` that Ansible spawns
- `db19_engineering` test report: the base line now lists the patches the base home
  actually carries (`opatch lspatches`). It printed `db19_patch_list_base` - wrong for a
  base home built with another list (2026-10-23: `RECOMMENDED:19.32,JDK` shown as
  `RU:19.32,JDK,OPATCH,OJVM,DPBP`). The AutoUpgrade line shows the build instead of the
  raw command result, the host line no longer breaks

- **`make cpu-lab-bastion-tunnel` failed three times in a row** on a fresh
  session: the Bastion refuses the key for a few seconds after the session is
  ACTIVE, ssh exits at once, and the loop kept probing a dead tunnel. The loop now
  restarts a dead ssh within the same session; the first attempt succeeds.
- **`terraform plan` replaced the lab instance** when the workstation key in
  `ssh_public_key_files` changed - the database would have been destroyed for a
  value cloud-init reads on first boot only. `modules/oracle_db_host` now ignores
  `metadata["ssh_authorized_keys"]`; rolling keys is an explicit `-replace`.
- **`BASTION=1` with a command-line `ANSIBLE_EXTRA`** dropped the tunnel host and
  port, and Ansible went to the public IP. The append is now `override`.

- **docs/runbook-ad-cmu-lab.md** carried the real compartment and DRG OCID in
  its `terraform.tfvars` example - replaced by `<compartment_ocid>` and
  `<drg_ocid>`. The history keeps the old values (identifiers, not
  credentials).

- **CHANGELOG**: 365 lines of work that shipped in `v0.3.0` were filed under a
  second `## [Unreleased]` heading below the `[0.3.0]` section - verified by
  reading the heading out of the `v0.3.0` tag itself. Both blocks are now one
  `[0.3.0]` section, merged per subsection; the content is byte-identical, 393
  lines in and 393 out as the same multiset.

## [0.3.0] - 2026-08-23

### Added

- **docs/runbook-cpu-patch-lab.md**: measured step durations for both shapes.
  A build that takes 40 minutes is fine as long as you know that beforehand;
  the table exists for predictability, not for speed. Roughly 90 minutes at
  8 OCPU and 100 at 2 OCPU from nothing to a patched, verified database.
- **tasks/roadmap-cpu-lab.md**: the reworked plan - milestones, the decisions
  still open with their trade-offs, and what was deliberately left out.
- **tasks/state-cpu-lab-2026-08-23.md**: current state. The two earlier state
  documents are marked superseded; both claimed the feature branch was
  unmerged, which was already wrong when they were written.
- **.yamllint** and **.markdownlintignore**: yamllint had no configuration and
  applied 80 column defaults that contradicted ansible-lint at profile
  production, so the two linters disagreed on the same files.

- **role/db19_engineering**: verification rewritten into four levels, because a
  patch can fail at four places - binary (`opatch lsinventory` against the
  resolved patch set), SQL (`dba_registry_sqlpatch`, `datapatch -prereq`),
  container (`cdb_registry_sqlpatch`, every PDB at the root's patch level) and
  runtime (instance, listener services). Version, all-rows-SUCCESS,
  nothing-pending and container sync are hard gates; the rest is collected and
  reported even after a hard failure, so a red run still leaves a complete
  report. The gate is the last task and the artifacts are written and fetched
  before it.
- **role/db19_engineering**: `tasks/db_snapshot.yml` - one comparable state
  snapshot, taken twice per test (baseline from the source home at the start of
  the patch phase, post from the target home during verification). Invalid
  objects are judged as a delta against the baseline, never as an absolute:
  an object that was already invalid is not a patch defect, and zero invalid
  objects is not a realistic criterion.
- **role/db19_engineering**: `tasks/smoke.yml` - one functional canary per
  patched component in a throwaway schema inside the PDB: a PL/SQL package for
  the Release Update, a Java stored procedure for OJVM, and an export/drop/import
  round trip for the Data Pump bundle patch. Registered patches say nothing about
  whether the patched code runs. The Data Pump credential goes through a `0600`
  parfile, never argv. Disable with `db19_run_smoke=false`.
- **role/db19_engineering**: `tasks/fetch_reports.yml` - pulls the result report,
  both snapshots and the patch-set manifests to `ansible/reports/<host>/`. The
  lab is destroyed after a test, so evidence that stays on the host is lost.
  The directory is git-ignored; a run is output, not source.
- **role/db19_engineering**: `tasks/rollback.yml` plus `make cpu-lab-rollback` -
  flashes the database back to the pre-patch restore point and restarts it from
  the base home, asserting that it reports the base Release Update again.
  Deliberately opt-in and outside the standard run: it adds about half an hour
  and makes the cycle more fragile, but "can we get back?" is the question
  customers actually ask.
- **role/db19_engineering**: `tasks/push_gold_image.yml` plus
  `make cpu-lab-goldimage-push` / `cpu-lab-goldimage-list`. Uploads the artifact
  and a manifest from the lab host, which sits in the same region as the bucket,
  using a write pre-authenticated request that the target mints and revokes
  around the upload. The manifest carries the resolved patch set, the artifact
  checksum, the AutoUpgrade build and the requested patch list - without it a
  gold image is an opaque zip whose content nobody can state a quarter later.
- **docs/runbook**: sections on what the verification checks and produces, and on
  building, naming and publishing gold images, including the quarterly loop -
  the gold image is built from the *validated target* home after a green test and
  becomes the next quarter's base.
- **role/db19_engineering**: self-made gold images. `db19_gold_image_create`
  adds `create_gold_image` to a `create_home` job, and `db19_gold_image_file`
  plus `db19_gold_image_url` build a home from `patch=GOLDIMAGE:<file>` staged
  from a bucket. This is the only gold-image route that works for 19c today - it
  does not touch the broken Oracle Update Advisor. A create_home run applies
  every patch and took 13 minutes on 8 OCPU; an install from a gold image takes
  about two minutes and needs no MOS access, which is what makes
  `lab_count > 1` practical. The produced artifact is reported by name, size and
  SHA-256 rather than left to be found in the stage directory. The
  pre-authenticated request is still needed: the first gold image has to be
  created from the 19.3.0.0 base image, after which the bucket serves the gold
  image instead.
- **role/db19_engineering**: `tasks/report_patchset.yml` - records which patches
  AutoUpgrade actually resolved per Release Update. Writes
  `patchset-<RU>.json` (verbatim manifest incl. SHA-1/SHA-256) and
  `patchset-<RU>.txt` (one line per patch, plus an explicit MRP yes/no) into the
  stage directory and prints the summary. Required because the target home is
  requested via `RECOMMENDED`, so whether the quarter carries a Monitored
  Recommended Patch is a test result rather than an input. The report is scoped
  to the RU of its own download job: AutoUpgrade accumulates
  `patches_info.json` when several jobs share a folder, so the manifest is
  filtered by the files the job itself fetched.
- **env/cpu-patch-test**: `enable_bastion = true`. The OCI Bastion reaches the
  host through the OCI control plane and is independent of inbound connectivity
  to the public IP - which is what made the 2026-08-21 rebuild possible at all
  (see Fixed).

### Verified

- **rollback**: `rollback.yml` was written carefully and never exercised. It is
  now proven against a real guaranteed restore point - flashback, home switch
  and self-assertion all green, `snapshot-rolledback` written.
- **reboot**: `oradba-services.service` had been enabled since the lab was
  built and had never once started. It now brings the listener and the database
  up unattended in 17 seconds. This needed four oradba releases; see below.

### Fixed

- **Makefile**: the Bastion tunnel now passes `IdentitiesOnly=yes`. A Bastion
  session accepts exactly the key it was created with and drops the connection
  after the first key that does not match, so ssh offering agent identities
  first made the tunnel fail with `Permission denied (publickey)` even with the
  correct `-i`. It worked until now only because the agent happened to offer
  the lab key second.
- **Makefile**: `lint-markdown` lets markdownlint expand the glob so that
  `.markdownlintignore` applies. The previous find/xargs pipeline passed
  explicit paths, which an ignore file cannot override, and linted generated
  reports that are git-ignored.
- **lint**: the whole suite passes - Terraform, Ansible, YAML, Markdown, Shell.
  14 `enable` markers replaced with `restore`, since `enable`
  reactivates rules with default parameters and ignores `.markdownlint.json`.
  45 further markdown findings, the ansible-lint backlog at profile production,
  and two 0-byte shell scripts that shellcheck could not assign a shell to.

- **role/db19_engineering**: the database registers with the listener again
  after an out-of-place move. Two defects, both silent - the database was open
  and healthy while `lsnrctl status` reported "The listener supports no
  services" and nothing could connect over TNS. First, `tnsnames.ora.j2` never
  defined `LISTENER_<SID>`, the alias dbca puts into `local_listener`, so
  rendering the template into the target home removed it. Second, the alias must
  not use the short host name: `getent hosts oradb01` answers with the IPv6
  link-local address first and the instance then rejects the parameter with
  ORA-00141 / ORA-00132, so `db19_net_host` is the FQDN the listener itself binds
  to. The registration task also re-sets `local_listener` in memory, because
  `alter system register` reuses the address resolved at startup. Both files now
  carry the `netconfig` tag so the network configuration can be repaired without
  repeating the patch. This also took the Data Pump smoke test down with it,
  which connects through the PDB service - that now passes too.
- **role/db19_engineering**: `datapatch -prereq` is classified by what it
  actually prints. The check looked for "nothing to apply" and failed a clean
  run whose output read "No interim patches need to be applied". It now collects
  every "need to be" line and drops the ones starting with "No".
- **role/db19_engineering**: the sqlpatch gate is scoped to the patches of the
  test. A `WITH ERRORS (PREV PATCH)` row left in the registry by the base
  installation turned an otherwise clean 19.32 run red. Historical failures are
  still reported, as `sqlpatch_historical_errors`, but they are no longer a
  statement about the patch under test.
- **role/db19_engineering**: the binary comparison ignores entries that cannot
  appear in `opatch lsinventory`. OPatch (p6880880) is the tool itself, and an
  MRP is a bundle whose members are registered individually - MRP 39834034
  showed up as 39661089, 39750798 and 39779336. Both were reported as
  permanently missing. Bundles are now listed by name instead.
- **role/db19_engineering**: `patchset-<RU>.json` holds that RU's patches only.
  It used to be a verbatim copy of `patches_info.json`, which AutoUpgrade
  accumulates across jobs sharing a folder, so the target manifest carried the
  base RU's patches and the verification reported them as missing from the
  target home.
- **role/db19_engineering**: the Data Pump smoke test is diagnosable. Export and
  import output went to `/dev/null` and the logs were deleted moments later, so
  a failed round trip left nothing but `ORA-00942`. The output is kept, the logs
  are printed on failure, and the working directory survives when a check fails.
- **playbook/lab-cpu-patch**: added `UserKnownHostsFile=/dev/null` to the SSH
  arguments. With a Bastion port-forwarding tunnel every lab host answers on the
  same `127.0.0.1:2222`, so a recorded host key belongs to whichever instance
  came first and every replacement then failed with "REMOTE HOST IDENTIFICATION
  HAS CHANGED". `StrictHostKeyChecking=no` alone does not help, because a
  conflicting entry is refused regardless. Pinning a host key to a reused local
  port carries no security value - the identity that matters is enforced by the
  Bastion session and the lab keypair.
- **role/db19_engineering**: the gold-image file name is dot-free. AutoUpgrade
  26.5.260807 rejects the parameter with "The CREATE_GOLD_IMAGE parameter must
  resolve to a file name containing only letters, numbers, underscores, hyphens,
  and the .zip suffix", so the version is written with underscores
  (`19_31_0_0_0`). Measured 2026-08-21 - the failure aborts `create_home` after
  four seconds, at config-parse time.
- **Makefile**: Ansible secrets no longer travel on the command line. The MOS
  credentials, the database SYS password and the AutoUpgrade keystore password
  went to `ansible-playbook` as `-e key=value`, which puts them in an argv that
  any local user can read with `ps` - for the full hour an AutoUpgrade run lasts.
  `cpu-lab-install`, `cpu-lab-patch` and `cpu-lab-step` now build a `0600` JSON
  file via `mktemp` and pass `-e @<file>`, with a `trap` that removes it on
  success, error and interrupt alike. The values reach `python3` through the
  environment rather than argv for the same reason: `/proc/<pid>/environ` and
  `ps -E` are owner-restricted, argv is not.
- **playbook/lab-cpu-patch**: added a `raw`-based SSH wait as the first task. A
  freshly applied instance is `RUNNING` before sshd accepts logins, so
  `make cpu-lab-cycle` died on "Connection refused" straight after
  `terraform apply`. Deliberately not `wait_for_connection`: that runs the ping
  module, which needs the Python interpreter the *next* task installs, so on a
  fresh host it can never succeed. `raw` also rides out the window in which sshd
  answers but `pam_nologin` still rejects the login.
- **docs/runbook**: corrected the 19c gold-image diagnosis. It is not that
  "gold_image is rejected on download jobs" - `target_version=19` is the only
  release whose gold-image resolution goes through the Oracle Update Advisor
  (`ValidateGoldImage.isGoldImageServiceTargetRelease`), and
  `POST transport.oracle.com/v2/patchplanner/requests` answers HTTP 500.
  AutoUpgrade cannot parse the plain-text body as JSON ("Unexpected char 73")
  and surfaces the outage as `Failed to process the gold_image parameter`.
  `gold_image=YES` takes the same path; `target_version=19.32` is rejected as
  not being a single version. 21 and 23 log "The Oracle Update Advisor service
  is not used for target release 23" and work. Reproduced on the lab host and on
  macOS with AutoUpgrade 26.5.260807 and the same keystore.

- **Makefile**: new at the repository root. Lint targets (`lint-terraform`,
  `lint-ansible`, `lint-yaml`, `lint-markdown`, `lint-shell`, `check-version`),
  the cpu-patch-test lab lifecycle (`cpu-lab-init/plan/apply/install/patch/
  verify/destroy/cycle`), plus `cpu-lab-step TAG=<tag>` for single-step runs on a
  test VM. Version and release targets follow the OraDBA standard. Each lab
  target auto-sources `terraform/envs/cpu-patch-test/.env`; `op read` is called
  inside recipe bodies only, never at parse time.
- **env/cpu-patch-test**: new Terraform stack for quarterly Oracle CPU patch
  testing. Oracle Linux 8 hosts, `lab_count`-parametrised, deploys into an
  existing base compartment (resolvable by OCID or by name plus `tenancy_ocid`).
  Generates the Ansible inventory into `ansible/inventories/generated/` so host
  IPs stay out of git, generates the database SYS password (`random_password`)
  and a dedicated lab SSH keypair (`tls_private_key`), and authorises the
  operator's own key from `~/.ssh/id_ed25519.pub` alongside it.
- **module/oracle_db_host**: new module for N identical Oracle Linux 8 database
  hosts. Enforces the Accenture standards unconditionally
  (`is_pv_encryption_in_transit_enabled`, `are_legacy_imds_endpoints_disabled`)
  on instances and volume attachments. Instance NSG allows SSH from the VCN CIDR
  plus opt-in external CIDRs, and the Oracle Net listener intra-VCN only.
  Optional data volume per host. Minimal cloud-init - Ansible does the rest.
- **role/db19_engineering**: implemented (was an empty stub). Native Ansible OS
  prerequisites built on `oracle-database-preinstall-19c`, then AutoUpgrade for
  every software operation: `-mode download`, `-mode create_home` for both the
  base and target ORACLE_HOME, and `-mode deploy` for the out-of-place move.
  Split into a generic phase (reusable for any 19c lab) and the quarterly CPU
  phase, with a tag per step so the flow can be driven one step at a time.
  The legacy `oradba_init` scripts are deliberately not invoked; `oradba` is
  installed as the runtime/environment layer only.
- **playbook/lab-cpu-patch.yml**: entry point for the lab, targets the
  `cpu_patch_hosts` group from the generated inventory.
- **ansible/requirements.yml**: collection requirements (`ansible.posix` for
  `selinux` and `firewalld`, `ansible.windows` for the AD lab).
- **ansible/.ansible-lint**: skips `var-naming[no-role-prefix]` with the
  reasoning documented in the file - a deliberate subset of role variables
  (`oracle_sid`, `db_base_ru`, `db_target_ru`, `oracle_home_base`,
  `oracle_home_target`) is the Terraform-to-Ansible contract and must not carry
  a role-name prefix.
- **.markdownlint.json**: OraDBA markdown standard (line length 120, MD033 off,
  MD024 siblings only).
- **docs/runbook-cpu-patch-lab.md**: runbook for a full CPU quarter cycle -
  architecture, prerequisites, the six steps, variable and secret reference, and
  a troubleshooting section.
- **env/ad-cmu-test**: Ansible inventory (`hosts.yml`) is now written immediately at
  the start of `null_resource.wait_for_winrm` provisioner, before the WinRM polling
  loop. Previously the IP was only written after WinRM became reachable, leaving the
  inventory stale when apply was interrupted or run without VPN connectivity.
- **env/ad-cmu-test**: Inventory path uses `abspath(path.root)` instead of `path.root`
  so the path resolves correctly regardless of the working directory terraform is
  invoked from.
- **env/ad-cmu-test**: Inventory `hosts.yml` added to version control with current
  private IP (`10.19.50.93`) for the `windc01` host.

### Notes

- **oradba 1.0.4 or later is now a hard requirement.** The reboot test exposed
  six defects in oradba, all pre-existing in v1.0.0 and all of one class: a
  bare `${VAR}` under `set -euo pipefail` aborts the script when the caller's
  environment does not define it. An interactive shell has the oradba profile
  loaded and never triggers it; systemd starts through `su - oracle` with no
  profile. Earlier versions cannot complete an unattended start. Analysis:
  `oradba/tasks/review-brief-boot-path-2026-08-23.md`.
- Five findings in this repository remain open and are tracked in
  `tasks/roadmap-cpu-lab.md` section 4, the most consequential being that
  `rollback.yml` leaves `oratab` at `:N` - which would turn any later reboot
  test into a false green.

### Changed

- **role/db19_engineering**: OJVM added to `db19_patch_list_base`
  (`RU:<base>,JDK,OPATCH,OJVM,DPBP`). A production 19.31 home carries OJVM
  19.31; without it the base home keeps the OJVM that shipped inside the
  19.3.0.0 base image from 2019, and the CPU test measures a six-year OJVM jump
  on top of the quarterly delta instead of a clean 19.31 -> 19.32 across every
  component. Verified 2026-08-21: the list resolves to RU 39034528, JDK BP
  39791916, OPatch 6880880, OJVM 19.31, DPBP 39196236.
- **role/db19_engineering (measured behaviour)**: the role was built and then
  verified end-to-end against a live Oracle Linux 8.10 host with AutoUpgrade
  26.5. Findings encoded as defaults and comments so they are not rediscovered:
  - Oracle Linux 8 ships Python 3.6, which ansible-core 2.18+ rejects on a
    managed node. The playbook bootstraps `python3.11` with `ansible.builtin.raw`
    before gathering facts, and the inventory sets `ansible_python_interpreter`.
  - `ansible.posix.selinux` and `ansible.posix.firewalld` need Python bindings
    that OL8 only ships for its platform Python 3.6. Both replaced with
    `lineinfile` + `setenforce` and `firewall-cmd`, so the role has no collection
    dependency at all.
  - The OCI OL8 image partitions only ~45 GB regardless of boot volume size, so a
    200 GB volume leaves ~23 GB free below ORACLE_BASE. `oci-growfs` now grows it
    to 189 GB before the free-space assertion.
  - AutoUpgrade serves only the current and previous Release Update. `RU:19.26`
    to `RU:19.30` report "Cannot find the latest Release Update"; only 19.31 and
    19.32 resolve. `db_base_ru` therefore defaults to `19.31` (previous), not
    `19.28`, and the lab runs previous RU to current RU.
  - AutoUpgrade cannot download the 19c base image. `gold_image` is rejected
    outright on a download job ("Failed to process the gold_image parameter",
    all prefixes, `AUTO` and `YES`); `gold_image=YES` never contacts Oracle at
    all (it looks for a local image); only `create_home` + `AUTO` queries the
    Oracle Updater, where `/v2/patchplanner/requests` returned HTTP 500 on 6 of
    6 calls while `/registration` succeeded 16 of 16. New variable
    `db_base_image_url` stages `LINUX.X64_193000_db_home.zip` from an OCI
    pre-authenticated request instead; `gold_image` stays `AUTO` so a working
    Updater service is used automatically once available.
  - `-mode analyze` requires a `sid` and cannot be used to pre-check a
    `create_home` config; it is used only for the deploy step.
  - `-load_password` needs a real TTY (piped stdin hits EOF at the command loop)
    and prompts for a keystore password first, then the MOS secret twice. Driven
    with `expect`; the keystore password is generated by Terraform.
  - `oradba` installs from its GitHub release asset (`oradba_install.sh
    --prefix`), not from a git clone - the repository is a source tree whose
    installer is built, not committed. Installed to `$ORACLE_BASE/local/oradba`.
- **env/cpu-patch-test**: filesystem roots split into `db_oracle_root` (`/u00`,
  binaries), `db_oracle_data` (`/u01`) and `db_oracle_arch` (`/u02`). Separate
  directories on one filesystem for now, so any of them can be moved onto a
  dedicated volume later without changing a path. Generates the AutoUpgrade
  keystore password alongside the database SYS password, and hands the lab SSH
  private key to Ansible through the generated inventory.

- **role/db19_engineering**: passwordless sudo for `oracle` and `opc` via
  `/etc/sudoers.d/99-oradba-lab`, validated with `visudo -cf` before install.
  AutoUpgrade's ROOTSH stage then runs `root.sh` and `orainstRoot.sh` itself
  instead of printing them for a follow-up task.
- **role/db19_engineering**: new systemd unit `oradba-services.service` starting
  listeners and every database flagged `:Y` in `/etc/oratab` on boot, delegating
  to oradba's own `oradba_services_root.sh` rather than reimplementing dbstart.
  Without it the database stayed down after a reboot - `oratab :Y` alone starts
  nothing. TODO: belongs upstream in oradba next to the wrapper, same as the
  response-file templates.
- **role/db19_engineering**: gold-image path is attempted first and falls back
  automatically. `download.yml` runs a config shaped like the known-good 26ai one
  (job-level `folder`, no `gold_image`, no `global.download_folder`); on failure
  it reports the reason and falls back to individual patches plus a base image
  staged from `db19_base_image_url`. Once the Oracle Updater service serves 19c
  gold images again this needs no code change.
- **role/db19_engineering (fixed)**: `db19_autoupgrade_download` was used both as
  a config variable and as a `register:` target. A registered result is a host
  fact and outranks a role default, so the whole module result dict was written
  into the generated AutoUpgrade config:
  `patch1.download={'changed': False, 'msg': 'HTTP Error 304: Not Modified', ...}`
  Register renamed to `db19_autoupgrade_jar_dl`; the hazard is documented at the
  variable and the defaults were audited for further collisions (none).
- **role/db19_engineering (fixed)**: the deploy config now pins
  `patch1.gold_image=NO`. Without an explicit value AutoUpgrade resolves it
  internally and fails on the broken 19c path with "Failed to process the
  gold_image parameter for prefix patch1".
- **role/db19_engineering (fixed)**: `verify.yml` queried a non-existent column.
  `dba_registry_sqlpatch_ru_info` has PATCH_ID, PATCH_UID, PATCH_DESCRIPTOR,
  RU_VERSION, RU_BUILD_DESCRIPTION, RU_BUILD_TIMESTAMP, PATCH_DIRECTORY - there is
  no VERSION_FULL. Would have failed at the end of a 40-minute patch run.
- **Makefile**: `cpu-lab-par` / `cpu-lab-par-list` / `cpu-lab-par-revoke` manage a
  short-lived single-object pre-authenticated request for the 19c base image
  (`ObjectRead`, `PAR_DAYS ?= 7`), verifying `HTTP 200` and the content length
  before writing anything to `.env`.
- **Makefile**: `cpu-lab-progress` / `cpu-lab-watch` / `cpu-lab-logs` report the
  running step via `tools/cpu-lab-progress.sh`, run with `--become` because the
  Oracle directories are unreadable by `opc` and `find`/`du` otherwise return
  nothing - which looks exactly like a stalled job.
- **Makefile**: `cpu-lab-allow-ip` re-points the SSH allow-list at the current
  egress IP using `-target` on the NSG rules only, so it cannot trigger the
  pending shape resize (and its reboot) as a side effect.
- **Makefile**: `cpu-lab-bastion-session` / `-tunnel` / `-list` for OCI Bastion
  port-forwarding sessions, plus `ANSIBLE_EXTRA` on every Ansible target so the
  playbooks can be pointed at a forwarded local port.
- **env/cpu-patch-test**: optional OCI Bastion (`enable_bastion`, default false).
  IAM-authorised sessions instead of a source-IP allow-list, which also allows
  running the host with no public IP at all.
- **env/cpu-patch-test**: `db_host_ocpus` 2 -> 8 and `db_host_memory_gbs` 16 -> 32.
  Database creation took ~38 minutes on 2 OCPUs; the dominant cost is datapatch
  across CDB$ROOT, PDB$SEED and each PDB, which is CPU-bound.

- **role/db19_engineering (fixed)**: re-running the install phase after a patch
  rewrote `/etc/oratab` from the target home back to the base home
  (`19.32` -> `19.31`). The autostart unit would then have opened the database
  from the old ORACLE_HOME and `verify` would have failed. The oratab task now
  runs only on first creation; from the out-of-place move onwards `patch.yml`
  owns the entry.
- **role/db19_engineering (fixed)**: `download` is skipped entirely when
  `.download-complete-<RU>` exists in the staging directory. Besides avoiding a
  pointless 4.7 GB re-download, this is required for idempotency: AutoUpgrade
  keeps job state under `global_log_dir`, and after a deploy that deliberately
  keeps its Guaranteed Restore Point (`drop_grp_after_patching=no`) the job stays
  open, so any further invocation aborts with "There is an unfinished execution
  of a deploy mode".
- **role/db19_engineering (fixed)**: `root.sh` and `orainstRoot.sh` now run only
  for a home created in the same play, and the oradba installer only when
  `bin/oradba_dbctl.sh` is absent (or `db19_oradba_force_install=true`). Both
  previously reported `changed` on every run, masking real drift.

- **module/network**: App and Windows AD subnets are now optional, via
  `create_app_subnet` and `create_windows_subnet` (both default `true`, so
  existing stacks are unaffected). Their route table, security list, subnet, and
  flow log are all gated, and `flow_log_targets` is built with `merge()` so only
  existing subnets get a log. `app_subnet_id` and `windows_subnet_id` use
  `one(...)` and return `null` when the subnet is not created.
  Reason: the module previously created all five subnets unconditionally, so a
  stack that did not override `app_subnet_cidr` / `windows_subnet_cidr` silently
  inherited the `10.19.x` defaults. In a VCN with a different CIDR that fails at
  apply time with `400-InvalidParameter, Specified CIDR block ... is not
  contained in its respective VCN CIDR blocks`.
- **env/ad-cmu-test**: Resource Scheduler switched from fixed `resources { id = instance_id }`
  to `resource_filters { RESOURCE_TYPE=instance }`. Scheduler now targets all compute
  instances in the compartment by type, not by OCID, so it survives instance replacement
  without requiring a `terraform apply` to re-sync. Note: `FREEFORM_TAG` is not supported
  by the OCI provider; tag-based filtering requires defined tags.
- **module/windows_ad (cloudinit)**: `27_config_cmu.ps1` removed from the automatic
  phase-2 script list. CMU/Kerberos configuration is now a manual post-deploy step
  (run via Ansible or RDP after AD is up). This prevents phase-2 from aborting when
  the CMU script fails due to missing prerequisites.

- **role/db19_engineering**: split the single patch list into two strategies.
  `db19_patch_list_base` is explicit (`RU:<base>,JDK,OPATCH,DPBP`) so the base
  home stays a reproducible control group; `db19_patch_list_target` is
  `RECOMMENDED:<target>,JDK` so the test sees what Oracle recommends for the
  quarter - the RU set alone in a plain quarter, RU plus MRP when there is one.
  `db19_patch_list` resolves per invocation. Verified 2026-08-21 with full
  downloads: the base pulled RU 39034528, JDK BP 39791916, OPatch 6880880, DPBP
  39196236; `RECOMMENDED:19.32,JDK` pulled RU 39472050, OJVM 39222882, MRP
  39834034, DPBP 39657094, OPatch 6880880, JDK BP 39791916. `RECOMMENDED` does
  not include the JDK bundle patch, hence the explicit `,JDK`; the version is
  mandatory, because a bare `RECOMMENDED` silently resolves to the latest RU and
  `RU:19.32,RECOMMENDED` is rejected outright.
- **role/db19_engineering**: `db19_try_gold_image` now defaults to `false`. For
  19c the gold-image download cannot succeed (see Fixed), so the attempt only
  cost a failed run and filled the log with a misleading configuration error.
- **env/cpu-patch-test**: `db_host_ocpus` 2 -> 8 and `db_host_memory_gbs`
  16 -> 32 in `terraform.tfvars`, which previously overrode the raised defaults.

## [0.2.1] - 2026-06-26

### Changed

- **module/windows_ad**: Shape default changed to `VM.Standard.E4.Flex` (AMD, more available
  in eu-zurich-1), memory_gbs default reduced to 8 GB, `domain_name` is now a required
  variable (no default - must be set per env). Instance and NSG names shortened to
  `*-dc-01` (was `*-windc-01`).
- **module/windows_ad (cloudinit)**: Removed incorrect `$$` escaping from PowerShell
  variables in `.tftpl` template - bare `$var` does not need escaping, only `${...}`
  Terraform interpolations are special. Added RDP firewall rule to bootstrap script.
- **env/ad-cmu-test**: OCI provider profile changed to `ACE`; `hashicorp/null >= 3.0`
  added for WinRM readiness probe. Added `null_resource.wait_for_winrm` (polls port
  5985 via `nc` after instance create). Added `oci_resource_scheduler_schedule` for
  daily auto-stop at 18:00 UTC. Added `drg_id` + `home_cidrs` variables for
  site-to-site VPN (UDM home lab → OCI via DRG). Domain set to `oradba.ch`.
- **docs**: Architecture overview and runbook updated with corrections.

### Added

- **module/windows_ad/versions.tf**: Explicit OCI provider source declaration for module.
- **module/network/versions.tf**: Explicit OCI provider source declaration for module.

## [0.2.0] - 2026-06-26

### Added

- **module/windows_ad**: New Terraform module for Windows Server 2022 AD instance
  (Oracle CMU + Kerberos lab). Shape VM.Standard3.Flex (x86), cloudbase-init
  PowerShell bootstrap for WinRM, instance-level NSG with all AD/Kerberos ports.
  Mandatory: legacy IMDS disabled, PV encryption in transit, lifecycle ignore_changes.
- **module/network**: Windows AD subnet (`sn-*-windows-01`, default 10.19.50.0/24)
  with dedicated route table (IGW), security list covering RDP/WinRM/LDAP/Kerberos/
  DNS/Global Catalog ports from VCN CIDR, optional external RDP via `allowed_rdp_cidrs`,
  and flow log entry.
- **env/ad-cmu-test**: New lab stack composing naming + network + windows_ad modules.
  Stack-code `windc`, domain `oradba.ch`. Windows Server 2022 image lookup via
  `data.oci_core_images`. No secrets in tfvars; `admin_password_secret` via TF_VAR.
- **ansible/role/windows_ad**: Ansible role for full AD deployment: copies ad-lab
  scripts, renders `00_init_environment.ps1` from Jinja2 template, installs AD DS with
  explicit reboot, waits on LDAP 389, then runs company/SPN/DNS/CA/CMU setup scripts.
  FQCN `ansible.windows.*` and `ansible.builtin.*` throughout.
- **ansible/playbooks/lab-ad-cmu.yml**: Playbook targeting `windows_dc` hosts via
  WinRM (HTTP 5985) using the `windows_ad` role.

## [0.1.0] - 2026-05-18

### Added

- **module/iam_mfa_oma**: Terraform module and stack for Oracle DB Native MFA with
  OMA Push. Includes email domain resource and wallet setup.
- **module/network**: Core VCN module with public/private/db/app subnets, Internet
  and NAT gateways, route tables, security lists (dynamic blocks), and VCN flow logs.
- **module/naming**: Naming helper module generating consistent `lab_name_core` and
  `base_freeform_tags` from region/environment/stack/instance inputs.
- **module/jumphost_gateway**: Jumphost/gateway instance with cloud-init bootstrap
  (Ansible pull via git clone), WireGuard support, SSH hardening.
- **module/db19_engineering**: Oracle DB 19c engineering instance module.
- **env/odb19eng-single**: Lab stack for single Oracle DB 19c engineering instance.
- **env/odb19sec-dg**: Lab stack for Oracle DB 19c security DataGuard setup.
- **ansible/roles**: base_ssh, common, common_hardening, crowdsec, db19_engineering,
  fail2ban, firewall, jumphost_base, wireguard_gateway.
- **ansible/playbooks**: full-lab-bootstrap, lab-db19eng, lab-jumphost, lab-oudeng,
  lab-wlseng.

### Changed

- Merged oci-labs-infra and oci-labs-config repositories into oci-labs monorepo.
- Removed legacy `infra/` folder in favour of `terraform/` layout.
