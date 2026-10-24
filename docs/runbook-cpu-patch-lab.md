# Runbook: cpu-patch-test - Oracle CPU Patch Test Lab

Throw-away Oracle Database 19c lab on OCI for quarterly **Critical Patch Update
(CPU)** testing. Terraform builds the network and the Oracle Linux 8 hosts,
Ansible installs Oracle at a base Release Update, and AutoUpgrade patches
out-of-place to the target RU.

This lab is the **infrastructure layer**. Reporting stays in
[`cpu-patch-tests`](https://github.com/oehrlis/cpu-patch-tests), which is not
modified from here.

- Stack code: `cpupt` - resources are named `chzh-l-cpupt-01`
- Filesystem roots: `/u00` binaries, `/u01` data, `/u02` archive
- Tenancy: `<namespace>`, OCI profile `<oci_profile>`, compartment `<compartment_name>`
- OS: Oracle Linux 8 - OL9 cannot run the 19.3.0 base release
- Lifecycle: build, install, patch, verify, destroy

## Architecture

```text
Workstation (macOS)                        OCI - compartment <compartment_name>
+---------------------------+              +-----------------------------------+
| terraform                 |  API         | VCN 10.29.0.0/16                  |
|   envs/cpu-patch-test     |------------->|   public  10.29.10.0/24           |
|                           |              |   private 10.29.20.0/24           |
| ansible-playbook          |  SSH 22      |   db      10.29.30.0/24           |
|   lab-cpu-patch.yml       |------------->|                                   |
|                           |              |  ci-chzh-l-cpupt-01-db-01         |
| op read (1Password)       |              |    OL8, E4.Flex 2 OCPU / 16 GB    |
|   MOS credentials         |              |    200 GB boot volume             |
+---------------------------+              |    NSG: SSH from your IP only     |
                                           +-----------------------------------+
                                                        |
                                                        | AutoUpgrade
                                                        v
                                              updates.oracle.com (MOS)
```

Ansible runs **from the workstation** over SSH. Cloud-init only does the minimum
needed for Ansible to take over: hostname, `python3`, `git`, `unzip`, `tmux`, the
oradba clone, and a marker file at `/var/log/oradba-cloudinit-complete`.

Nothing sensitive goes into cloud-init: `user_data` is readable by any user on
the instance through the metadata service. MOS credentials and the SYS password
are passed per run via `-e`.

## Layout - one CPU network, one stack per product

Since 2026-10-23 the CPU tests grow towards one shared network and one stack per
product or release on top of it:

```text
envs/core            VCN 10.29.0.0/16, DB subnet, NAT, Bastion, bucket orarepo
  |                  core_owner = "core" - outlives every lab, never destroyed by one
  +-- envs/cpu-patch-26ai   26ai host (OL9), reads core via terraform_remote_state
  +-- envs/cpu-patch-wlsXX  WebLogic hosts (planned, same pattern)

envs/cpu-patch-test  19c host - still with its own VCN and Bastion, moves onto
                     the core with the next rebuild (gold image, OL9)
```

Every `cpu-lab-*` target takes `CPU_ENV=<stack>` (default `cpu-patch-test`).
Each stack has its own Bastion tunnel port - `cpu-patch-test` 2222,
`cpu-patch-26ai` 2224, `cpu-patch-wls` 2225 (2223 belongs to the datasafe-demo tunnel) -
so several labs can be driven at the same time:

```bash
make cpu-lab-plan CPU_ENV=cpu-patch-26ai
make cpu-lab-apply CPU_ENV=cpu-patch-26ai
make cpu-lab-install CPU_ENV=cpu-patch-26ai BASTION=1
make cpu-lab-patch CPU_ENV=cpu-patch-26ai BASTION=1
make cpu-lab-stop CPU_ENV=cpu-patch-26ai
```

A host stack never creates or destroys a network resource; its destroy removes
host, NSG, keys and inventory. The role is the same for both releases -
`db_release` 19 | 26 in the inventory selects the release profile
(`db_release_profiles` in the role defaults).

## WebLogic - cpu-patch-wls

One host (OL9, 4 OCPU / 32 GB) carries every WebLogic version side by side, role
`wls_engineering`, playbook `lab-wls-patch.yml`. Versions and their files are listed
in `ansible/playbooks/group_vars/cpu_wls_hosts.yml`.

### Upload to orarepo first

`orarepo` is flat - upload into the bucket root and put the exact object name into
`cpu_wls_hosts.yml`. eDelivery V-numbers are fine. A version with an empty name is
left out and named in the run output.

<!-- markdownlint-disable MD013 MD060 -->
| Version | Installer | JDK (linux-x64 tar.gz) | Baseline SPB | SPB under test |
| --- | --- | --- | --- | --- |
| 14.1.2.0.0 | eDelivery zip with `fmw_14.1.2.0.0_wls.jar` | 17.0.12+ or 21.0.4+ | 2026-07 | 40125898 |
| 15.1.1.0.0 | eDelivery zip with the generic jar | 17.0.16+ or 21.0.8+ | 2026-07 | 40128310 |
| 12.2.1.4.0 | in orarepo: `fmw_12.2.1.4.0_infrastructure_Disk1_1of1.zip` | 8 (1.8.0_211+) | 2026-07 | 40129641 |
| 14.1.1.0.0 | in orarepo: `fmw_14.1.1.0.0_wls_lite_Disk1_1of1.zip` | 11.0.6+ (or 8) | 2026-07 | 40129124 |
<!-- markdownlint-restore -->

The installer jar is found inside the zip by name, or as the only `fmw_*.jar`.

### Run

```bash
make cpu-lab-plan CPU_ENV=cpu-patch-wls
make cpu-lab-apply CPU_ENV=cpu-patch-wls        # Stefan
make cpu-lab-repo-par CPU_ENV=cpu-patch-wls REPO_CHECK=<one uploaded file name>
make cpu-lab-install CPU_ENV=cpu-patch-wls BASTION=1 ANSIBLE_EXTRA="-e wls_only=14.1.2.0.0"
make cpu-lab-patch CPU_ENV=cpu-patch-wls BASTION=1 ANSIBLE_EXTRA="-e wls_only=14.1.2.0.0"
make cpu-lab-verify CPU_ENV=cpu-patch-wls BASTION=1
make cpu-lab-rollback CPU_ENV=cpu-patch-wls BASTION=1 ANSIBLE_EXTRA="-e wls_only=14.1.2.0.0"
make cpu-lab-stop CPU_ENV=cpu-patch-wls
```

Every step prints the full Ansible output. Long steps (installer, SPBAT,
copyBinary/pasteBinary) run async - their output appears when the step ends.

### What the patch does

In place, the way the SPB README documents it (decided 2026-10-24 over an
out-of-place swap at the same path - fewer moving parts, the way customers patch
WebLogic, and the downtime measured is the real one):

1. Archive home and inventory of the version (`backup-home-pre-<cycle>.tgz` in the
   stage) - the servers keep running
2. Stop both servers, `spbat.sh -phase precheck`, `spbat.sh -phase apply`, start -
   this is the downtime that is measured
3. Smoke test and `opatch lspatches`

SPBAT has no rollback phase. `make cpu-lab-rollback` runs `opatch nrollback` with the
bundle's `rollback_patchlist.txt` - Oracle's documented way back; OPatch stays at
the version the SPB brought. `ANSIBLE_EXTRA="-e wls_rollback_restore=true"` restores
the archive instead. 14.1.2 and 15.1.1 run in secured production mode (no Admin
Console): every domain gets a domain-wide administration port and SSL with demo
certificates; checks, deployment and shutdown go through the REST management API.

Ports per version (base + 100 x position in `wls_versions`): administration port
9002 / 9102 / 9202 / 9302, managed server SSL 8002 / 8102 / ...

Reports: `ansible/reports/<host>/cputest-WLS-<version>-<date>-<phase>.json|md`.

## Costs

OCI list prices in USD, checked 2026-10-23. Compute E4.Flex: 0.025 per OCPU-hour,
0.0015 per GB-hour of memory ([Oracle E4 announcement][e4-price]). Block Volume
Balanced (10 VPU): 0.0255 per GB-month storage plus 0.0170 per GB-month
performance = 0.0425 per GB-month ([OCI price list][oci-price]). Object Storage
Standard: 0.0255 per GB-month. A third-party calculator showed a higher E4 OCPU
rate (0.0328) - check the [OCI cost estimator][oci-estimator] before a budget
decision.

Free: VCN, NAT gateway, Internet gateway, Bastion, egress up to 10 TB a month,
Logging (flow logs) within the free 10 GB a month.

<!-- markdownlint-disable MD013 MD060 -->
| Item | Sizing | Running | Stopped |
| --- | --- | --- | --- |
| db19 host (`cpu-patch-test`) | 8 OCPU / 32 GB | 0.248 per hour | 0 |
| db26 host (`cpu-patch-26ai`) | 8 OCPU / 32 GB | 0.248 per hour | 0 |
| WLS host (planned) | 4 OCPU / 32 GB | 0.148 per hour | 0 |
| Boot volume per host | 200 GB, Balanced | included below | 8.50 per month (0.28 per day) |
| Bucket `orarepo` | 314 GB, 594 objects (2026-10-23) | 8.00 per month | 8.00 per month |
<!-- markdownlint-restore -->

What that means:

- **Two DB hosts running at the same time cost 0.50 per hour** - the budget of
  0.5 per hour. A third host on top (WLS) goes to 0.64 per hour: run WLS with one
  DB host stopped, or size it at 4 OCPU / 16 GB (0.124 per hour)
- Compute is only charged while a host runs; `make cpu-lab-stop` after every run
- **Storage runs all the time.** Three hosts parked: 3 x 8.50 = 25.50 per month
  for boot volumes, plus 8.00 for the bucket - about 34 per month without a single
  running hour. The biggest levers are a destroy after the report and a cleanup of
  old media in `orarepo`
- A CPU cycle as run in 2026-10: 19c about 3 h of host time (baseline, patch,
  rollback, retries), 26ai about 3 h, WLS about 4 h per version - roughly
  0.75 + 0.75 + 4 x 0.6 = 3.90 compute, plus about 34 per month storage while
  the hosts are parked

[e4-price]: https://www.dbta.com/Editorial/News-Flashes/Oracle-Announces-Cloud-Compute-E4-Platform-on-Third-Gen-AMD-EPYC-Processors-146040.aspx
[oci-price]: https://www.oracle.com/cloud/price-list/
[oci-estimator]: https://www.oracle.com/cloud/costestimator.html

## Two phases

The Ansible role splits into a generic phase, reusable for any Oracle 19c lab,
and the quarterly CPU phase.

<!-- markdownlint-disable MD013 -->

| Phase | Tag | What it does |
| --- | --- | --- |
| generic | `prereq` | OL8 assert, `oracle-database-preinstall-19c`, Java 11, python3.11, THP off, SELinux permissive, `oci-growfs`, directories, free-space check |
| generic | `oradba` | Clone and install the oradba environment toolset (runtime layer only) |
| generic | `autoupgrade` | Download `autoupgrade.jar`, gate on version >= 25.3 |
| generic | `credentials` | Load MOS credentials into the AutoUpgrade keystore (auto-login) |
| generic | `download` | AutoUpgrade `-mode download` for the base RU media, plus staging the 19c base image |
| generic | `create_home` | AutoUpgrade `-mode create_home` for the base ORACLE_HOME |
| generic | `create_db` | listener.ora / tnsnames.ora, `dbca` via response file, oratab |
| CPU | `patch` | Download the target RU, `create_home` for the target, `-mode deploy` to move the database |
| CPU | `verify` | Confirm oratab, `version_full`, registry state, `datapatch -prereq` |

<!-- markdownlint-restore -->

Coarse tags wrap them: `install` runs the whole generic phase, `patch` the whole
CPU phase.

## How long it takes

Measured on a full reference run, 8 OCPU / 32 GB, Oracle Linux 8, 19.31 to
19.32. The point of this table is predictability, not speed: a build that takes
40 minutes is fine as long as you know it beforehand.

<!-- markdownlint-disable MD013 -->

| Step | Tag | 8 OCPU / 32 GB | 2 OCPU / 16 GB |
| --- | --- | --- | --- |
| Terraform apply, 33 resources | - | ~3 min | ~3 min |
| prereq, oradba, AutoUpgrade, keystore, download base RU | `install` | ~3 min | ~3 min |
| Create the base ORACLE_HOME, incl. gold image | `create_home` | 20 min | 25 min |
| Create the lab database, CDB plus one PDB | `create_db` | 33 min | 38 min |
| Baseline snapshot | `create_db` | seconds | seconds |
| Download the target RU | `patch` | ~3 min | ~3 min |
| Create the target ORACLE_HOME | `patch` | 13 min | - |
| Out-of-place move, AutoUpgrade deploy | `patch` | 12 min | - |
| Smoke test | `smoke` | ~2 min | ~2 min |
| Verification | `verify` | ~2 min | ~2 min |
| Rollback to the restore point, optional | `rollback` | ~5 min | - |
| Reboot, database available again | - | ~2 min | - |

<!-- markdownlint-restore -->

A full build from nothing to a patched, verified database is therefore roughly
**90 minutes** at 8 OCPU and about **100 minutes** at 2 OCPU. The shape is
dominated by `create_home` and `create_db`, and both are CPU-bound only in
part - the difference between the two shapes is around 10 minutes, so the
smaller shape is a reasonable default when nobody is waiting.

Installing from a self-made gold image replaces the 20 minute `create_home`
with about two minutes and needs no MOS access at all.

A reboot brings the listener and the database back on its own, provided oradba
1.0.4 or later is installed - earlier versions fail on the boot path. Measured:
17 seconds from the systemd unit starting to the database being open.

## Prerequisites

```bash
brew install terraform ansible ansible-lint yamllint 1password-cli
npm install -g markdownlint-cli
ansible-galaxy collection install -r ansible/requirements.yml
```

- OCI CLI config `~/.oci/config` with the `<oci_profile>` profile (`DEFAULT` points at
  the same tenancy `<namespace>`)
- 1Password item `secrets/Oracle-MOS` with fields `username` and `password`.
  No `op signin` needed - the desktop app integration prompts on demand.
- An SSH key at `~/.ssh/id_ed25519.pub`. Terraform also generates a dedicated
  lab keypair, so both are authorised.

## The Oracle 19c base image

AutoUpgrade downloads every **patch** automatically, but **not** the 19c base
image, and it cannot obtain a 19c gold image either. Root cause, measured
2026-08-21 with AutoUpgrade 26.5.260807 on the lab host and on macOS, same
keystore, same minute:

<!-- markdownlint-disable MD013 MD060 -->

| `target_version` | Path taken | Result |
| --- | --- | --- |
| `19` | `isGoldImageServiceTargetRelease` -> Oracle Update Advisor -> `POST /v2/patchplanner/requests` | HTTP 500, reported as `Failed to process the gold_image parameter for prefix <p>` |
| `19` with `gold_image=YES` | `allOrYes` -> same Updater call | identical HTTP 500 |
| `19.32` | rejected at parse time | `target_version ... needs to be a single version (i.e. 19)` |
| `21` / `23` | Updater skipped: `The Oracle Update Advisor service is not used for target release 23. The YES setting is used.` | gold image straight from ARU, works |

<!-- markdownlint-restore -->

So 19 is the only release whose gold-image resolution goes through the Update
Advisor, and that endpoint is broken server side - `/v2/patchplanner/registration`
answers normally, only `/v2/patchplanner/requests` returns 500. AutoUpgrade then
fails to parse the plain-text body as JSON (`Unexpected char 73`, the `I` of
`Internal Server Error`) and surfaces a service outage as a configuration error.
The full trace is in `<log_dir>/cfgtoollogs/patch/auto/aru/ous.log`.

Consequences for the lab:

- every **download** job pins `gold_image=NO` - with `AUTO` the job dies at
  config-parse time
- `create_home` keeps `gold_image=AUTO`, which is proven: the Updater returns
  `UpdaterInfoPerPrefix{latestVersion='N/A'}`, AutoUpgrade shrugs and validates
  the staged base image instead
- `db19_try_gold_image` is `false` - for 19c a gold-image download is a
  guaranteed failed run. Flip it to `true` once Oracle fixes the endpoint

Until then, stage `LINUX.X64_193000_db_home.zip` via `db_base_image_url`. The
file already exists in the tenancy - bucket `orarepo`, namespace
`<namespace>`, 3'059'705'302 bytes:

```bash
make cpu-lab-par PAR_DAYS=7
```

Keep the expiry short (7 days) so the pre-authenticated request stays inside
Accenture monitoring thresholds. The target writes the URI into `.env` itself;
by hand it is:

```bash
export TF_VAR_db_base_image_url="https://<namespace>.objectstorage.<region>.oci.customer-oci.com/p/<token>/n/<ns>/b/orarepo/o/LINUX.X64_193000_db_home.zip"
```

Both PAR shapes work: a bucket PAR ending in `/o/` gets the filename appended, a
single-object PAR is used verbatim.

## Patch lists - base versus target

The two homes answer two different questions, so they are requested differently.

<!-- markdownlint-disable MD013 MD060 -->

| Home | Variable | Value | Rationale |
| --- | --- | --- | --- |
| base (control) | `db19_patch_list_base` | `RU:<base_ru>,JDK,OPATCH,OJVM,DPBP` | every component named - the control group must be reproducible. OJVM is included on purpose: without it the base keeps the 2019 OJVM from the base image and the test measures a six-year OJVM jump on top of the quarterly delta |
| target (test) | `db19_patch_list_target` | `RECOMMENDED:<target_ru>,JDK` | what Oracle actually recommends for the quarter: RU set alone in a plain quarter, RU plus MRP when there is one |

<!-- markdownlint-restore -->

Measured on 2026-08-21, both with full downloads:

```text
RU:19.31,JDK,OPATCH,OJVM,DPBP   -> RU 39034528, JDK BP 39791916,
                                   OPatch 6880880, OJVM 19.31,
                                   DPBP 39196236
RECOMMENDED:19.32,JDK           -> RU 39472050, OJVM 39222882,
                                   MRP 39834034, DPBP 39657094,
                                   OPatch 6880880, JDK BP 39791916
```

Two things to know about `RECOMMENDED`:

- it does **not** include the JDK bundle patch, hence the explicit `,JDK` -
  without it the target home would regress against a base built with JDK
- the version is mandatory. `RU:19.32,RECOMMENDED` is rejected ("when the PATCH
  parameter specifies a version for RECOMMENDED, the same version must be
  specified for RU") and a bare `RECOMMENDED` silently resolves to the latest
  RU, which would make the target non-deterministic

And one caveat about the base: the `JDK` keyword resolves to the *current* JDK
bundle patch, not one pinned to the base RU - a 19.31 base pulled JDK BP
`19.0.0.0.260818` on 2026-08-21. The patch labels are fixed, one patch number is
not. That is why every download writes its resolved set out:

```text
/opt/stage/patchset-<RU>.json   verbatim manifest incl. SHA-1 / SHA-256
/opt/stage/patchset-<RU>.txt    one line per patch, plus MRP yes/no
```

The summary is also printed during the run. It is scoped to the RU of that job -
AutoUpgrade accumulates `patches_info.json` when several download jobs share one
folder, so the report filters the manifest by the files the job itself fetched.

## What the verification checks, and what it produces

A patch can fail at four different places, so the verification looks at four
levels. The lab is destroyed after a test, which means an Ansible stdout is not
a result - every level ends up in an artifact.

### Levels and criteria

<!-- markdownlint-disable MD013 MD060 -->

| Level | Check | Source | Pass criterion | Gate |
| --- | --- | --- | --- | --- |
| binary | resolved patches present in the home | `opatch lsinventory` | every patch number from `patchset-<target>.json` is listed | soft |
| sql | version | `v$instance.version_full` | matches the target Release Update | **hard** |
| sql | every applied patch succeeded | `dba_registry_sqlpatch` | no row other than `SUCCESS` | **hard** |
| sql | nothing left to do | `datapatch -prereq` | reports nothing to apply or roll back | **hard** |
| container | every PDB at the root's level | `cdb_registry_sqlpatch` | each container's applied patch set equals the root's | **hard** |
| objects | no new invalid objects | `dba_objects` vs baseline | delta to the pre-patch baseline is not positive | soft |
| components | components valid | `dba_registry` | every component `VALID` or `OPTION OFF` | soft |
| runtime | listener serves the database | `lsnrctl status` | a service for the SID is registered | soft |
| smoke | PL/SQL compiles and runs | throwaway package in the PDB | returns its sentinel value, no invalid objects | soft |
| smoke | OJVM compiles and runs | Java stored procedure | returns its sentinel value | soft |
| smoke | Data Pump round trip | export, drop, import a 100-row table | 100 rows back | soft |
| rollback | a way back exists | `v$restore_point` | a guaranteed restore point is present | reported |

<!-- markdownlint-restore -->

The **hard** criteria fail the play, everything else is collected and reported
even after a hard failure - a red run must still leave a complete report behind.
That is also why the artifacts are written and fetched *before* the gate.

Invalid objects are judged as a **delta**, never as an absolute: an object that
was already invalid before the patch is not a patch defect, and "zero invalid
objects" is not a realistic criterion on a real database. The baseline is taken
at the start of the patch phase, from the source home, with the same query set.

### Artifacts

```text
on the lab host, in the stage directory
  snapshot-baseline-<SID>.json      pre-patch state
  snapshot-post-<SID>.json          post-patch state
  patchset-<RU>.json / .txt         resolved patch set per Release Update
  cputest-<SID>-<base>-to-<target>-<date>.json    machine readable result
  cputest-<SID>-<base>-to-<target>-<date>.md      report to hand on

on the control node
  ansible/reports/<host>/           all of the above, fetched before the gate
```

`ansible/reports/` is git-ignored - a run is output, not source. Commit one
deliberately when it is worth keeping as a reference.

### The smoke test

Registered patches say nothing about whether the patched code still runs, so
each patched component gets one canary in a throwaway schema inside the PDB:
PL/SQL for the Release Update, a Java stored procedure for OJVM, and an
export/import round trip for the Data Pump bundle patch. The schema is dropped
again, so the next baseline is not polluted. Disable with
`db19_run_smoke=false`.

### Rollback

Not part of the standard run - it adds roughly half an hour and makes the cycle
more fragile. The deploy keeps its guaranteed restore point
(`db19_drop_grp_after_patching=false`), and the verification reports that the
restore point exists. Exercising it is a separate, deliberate step:

```bash
make cpu-lab-rollback          # asks for confirmation, YES=1 to skip
```

It shuts the database down from the target home, points `oratab` back at the
base home before anything can start again, flashes back, opens resetlogs, opens
the PDBs, and asserts that the database reports the base Release Update.

## Prerequisites the patch itself depends on

Four things that are not obvious and each of which stopped a run dead on
2026-08-21.

### ARCHIVELOG is mandatory

AutoUpgrade takes a guaranteed restore point before an out-of-place move and
refuses to start without one:

```text
GRP106: AutoUpgrade Patching is unable to proceed because database is not in
ARCHIVE LOG mode and guarantee restore point cannot be taken (default behavior).
```

The deploy dies after 22 seconds in stage GRP. `db19_enable_archivelog` is
therefore `true`, dbca creates the database that way, and `archivelog.yml` is
the idempotent safety net for a database that already exists
(`make cpu-lab-step TAG=archivelog`). The alternative, `restoration=no` in the
deploy config, buys the patch run at the price of the rollback.

### A pending deploy job blocks every later AutoUpgrade job

A deploy that keeps its restore point - which is the default here - leaves its
job open, and *any* AutoUpgrade invocation sharing `global_log_dir` then aborts:

```text
There is an unfinished execution of a deploy mode. Run the AutoUpgrade Patching
in deploy mode to resume from failure point
```

This is not limited to the next deploy. A plain download job hits it too. Two
consequences, both encoded in the role:

- `analyze` tolerates this one message and lets `deploy` resume from the failure
  point. `-clear_recovery_data` does **not** lift the block for analyze - it
  reports "the modified jobs will start from scratch" and analyze still refuses,
  for one job and for all of them. Only deploy can resume.
- any other job after a deploy needs its own log directory, e.g.
  `-e db19_autoupgrade_log_dir=<other path>`. That is what
  `db19_gold_image_log_dir` exists for.

### local_listener has to resolve in the target home

After the move the database runs from the new home and resolves
`local_listener` through that home's `TNS_ADMIN`. Two things went wrong there:

```text
ORA-00141: all addresses specified for parameter LOCAL_LISTENER are invalid
ORA-00132: syntax error or unresolved network name 'LISTENER_CPUDB'
```

- `tnsnames.ora.j2` did not define `LISTENER_<SID>` at all, while dbca had put it
  into the base home. The generated file overwrote the target home's copy
  without it.
- the alias must not use the short host name. On this image
  `getent hosts oradb01` answers with the IPv6 link-local address first, and the
  instance rejects the whole parameter. `db19_net_host` is the FQDN, which maps
  to the IPv4 address and is what the listener binds to.

The symptom is silent: the database is open and healthy, `lsnrctl status` says
"The listener supports no services", and nothing can connect over TNS. It also
takes the Data Pump smoke test down with it, because that connects through the
PDB service. Re-apply the network configuration on its own with
`make cpu-lab-step TAG=netconfig`; the step also re-sets `local_listener` in
memory, because `alter system register` alone reuses the address the instance
resolved at startup.

### An MRP is a bundle, not a patch number

`opatch lsinventory` never shows the MRP number. It registers the bundle's
members: MRP 39834034 appeared in the home as 39661089, 39750798 and 39779336.
The binary comparison therefore excludes MRP entries from the expected list and
reports them by name instead, next to OPatch, which is a tool rather than an
applied patch.

## Gold images - build, name, publish

For 19c a **self-made** gold image is the only gold-image route that works, and
it is unrelated to the broken Oracle Update Advisor. It does not remove the need
for the base-image pre-authenticated request: the first artifact still has to be
built from `LINUX.X64_193000_db_home.zip`. Afterwards the bucket serves the gold
image instead, and a home installs in about two minutes rather than thirteen.

### When to build one

The gold image is produced **after a successful test, from the validated target
home**: quarter N tests base 19.31 against target 19.32, and once that is green,
19.32 becomes the gold image and therefore the base for quarter N+1. The
artifact is only ever built from a Release Update the lab has actually verified.

```bash
# during the initial build of a base home
make cpu-lab-install ANSIBLE_EXTRA="-e db19_gold_image_create=true"

# publish it, then list what is in the bucket
make cpu-lab-goldimage-push
make cpu-lab-goldimage-list
```

`cpu-lab-goldimage-push` mints a short-lived write pre-authenticated request,
uploads from the lab host (same region as the bucket, so the artifact never
travels over the operator's uplink), and revokes the request afterwards.

### Naming

```text
goldimage-db-<version>-<platform>-<edition>-<date>.zip
goldimage-db-<version>-<platform>-<edition>-<date>.patchset.json

e.g. goldimage-db-19_31_0_0_0-linux-x64-ee-20260821.zip
```

The version carries underscores because AutoUpgrade rejects dots outright:
"The CREATE_GOLD_IMAGE parameter must resolve to a file name containing only
letters, numbers, underscores, hyphens, and the .zip suffix". Underscores inside
the version and hyphens between the scheme fields also keep the field boundaries
unambiguous. There is deliberately no `latest` alias - a gold image is always
referenced explicitly.

The manifest next to the artifact carries the resolved patch set of the Release
Update it was built from, the artifact checksum, the AutoUpgrade build and the
requested patch list. Without it a gold image is an opaque zip whose content
nobody can state a quarter later.

### Building a home from one

```bash
make cpu-lab-install ANSIBLE_EXTRA="\
  -e db19_gold_image_file=goldimage-db-19_31_0_0_0-linux-x64-ee-20260821.zip \
  -e db19_gold_image_url=<read PAR for that object>"
```

The role stages the artifact like the base image and hands AutoUpgrade
`patch=GOLDIMAGE:<file>` instead of a patch list.

## Release Update availability

AutoUpgrade serves only the **current and the previous** RU. Measured:

```text
RU:19.26 .. RU:19.30  ->  "Cannot find the latest Release Update"
RU:19.31, RU:19.32    ->  resolved
```

The lab therefore runs **previous RU -> current RU**, which is self-maintaining:
each quarter shift `db_base_ru` and `db_target_ru` by one.

## Step 1 - Configure

```bash
cd terraform/envs/cpu-patch-test
cp .env.example .env
$EDITOR .env
```

The only value that regularly needs changing is your egress address, because the
NSG allows SSH from that CIDR only:

```bash
curl -s -4 https://ifconfig.me      # the VCN is IPv4-only
```

Update `TF_VAR_allowed_ssh_cidrs` accordingly. Every quarter, shift both
`TF_VAR_db_base_ru` and `TF_VAR_db_target_ru` by one RU.

`.env`, `terraform.tfvars`, `.ssh/` and all state files are git-ignored.

## Step 2 - Build the infrastructure

From the repository root:

```bash
make cpu-lab-plan       # dry-run, writes tfplan
make cpu-lab-apply      # applies tfplan
```

Expect roughly 40 resources. `apply` writes the Ansible inventory to
`ansible/inventories/generated/cpu-patch-test/hosts.yml` (git-ignored, so host
IPs never reach the repository) and generates the lab SSH keypair into
`.ssh/cpu-lab`.

```bash
make cpu-lab-output     # all outputs
make cpu-lab-ssh        # ready-to-paste SSH command per host
```

The inventory carries the patch level as group vars - `oracle_sid`,
`db_base_ru`, `db_target_ru`, `oracle_home_base`, `oracle_home_target` - so the
lab is described once, in Terraform, and Ansible inherits it.

Wait for cloud-init before running Ansible:

```bash
ssh -i .ssh/cpu-lab opc@<ip> 'cat /var/log/oradba-cloudinit-complete'
```

## Step 3 - Install Oracle at the base RU

```bash
make cpu-lab-install
```

This reads the MOS credentials from 1Password and the generated SYS password
from the Terraform output, then runs the whole generic phase.

For step-by-step work on a fresh VM, run one tag at a time:

```bash
make cpu-lab-step TAG=prereq
make cpu-lab-step TAG=oradba
make cpu-lab-step TAG=autoupgrade
make cpu-lab-step TAG=credentials
make cpu-lab-step TAG=download
make cpu-lab-step TAG=create_home
make cpu-lab-step TAG=create_db
```

Every step is idempotent, so a failed step can be fixed and re-run without
rebuilding the instance.

Verify by hand:

```bash
ssh -i .ssh/cpu-lab opc@<ip>
sudo su - oracle
. oraenv <<< CPUDB
sqlplus -s / as sysdba <<< "select version_full from v\$instance;"
```

## Step 4 - Patch to the target RU

```bash
make cpu-lab-patch
```

Three AutoUpgrade operations in sequence: download the target RU media,
`create_home` for the target ORACLE_HOME, then `-mode deploy` to move the
database. Each is preceded by `-mode analyze`, which runs prechecks only.

AutoUpgrade does **not** move the listener - the role stops it from the old home
and starts it from the new one, and repoints `/etc/oratab`.

The old ORACLE_HOME is deliberately left in place for rollback testing.

On a host that has been patched before, give the run its own AutoUpgrade log
directory, so an open deploy job of the previous run cannot be resumed by
mistake (see "A pending deploy job blocks every later AutoUpgrade job"):

```bash
make cpu-lab-patch BASTION=1 ANSIBLE_EXTRA="-e db19_autoupgrade_log_dir=/u00/app/oracle/cfgtoollogs/autoupgrade-2026-10"
```

### Fallback - target RU from the bucket instead of MOS

The default stays the MOS download on the host. When that is not wanted or not
possible, `cpu-patch-tests` downloads the patch set (`au-download`) and uploads it
below a prefix of the `orarepo` bucket (`make upload OCI_OBJECT_PREFIX=patches/2026-10/`).
The lab then gets a read PAR on exactly that prefix:

```bash
make cpu-lab-patch-par PATCH_PREFIX=patches/2026-10/   # lists the objects it will stage
make cpu-lab-patch BASTION=1 ANSIBLE_EXTRA="-e db19_autoupgrade_log_dir=/u00/app/oracle/cfgtoollogs/autoupgrade-2026-10"
make cpu-lab-par-revoke                                # after the run
```

- The URL is kept in `terraform/envs/cpu-patch-test/.patch-par` (0600, git-ignored)
  and reaches Ansible in the 0600 vars file of the make targets - no Terraform
  apply, no inventory change. Every make target that uses it prints a line saying so
- The host lists the prefix and pulls the objects itself into `/opt/stage`,
  region-internal; nothing travels through the controller. Sizes are checked
  against the listing
- AutoUpgrade then runs with `download=no` for `create_home` and `deploy`. Only the
  target RU uses the PAR - a `cpu-lab-install` with the file present still builds
  the base RU as before
- The PAR covers only the prefix: an object outside it answers HTTP 401
  (verified 2026-10-22)
- **Not yet proven:** the target list is `RECOMMENDED`. Whether AutoUpgrade
  resolves it from a staged folder without MOS - and whether it needs the
  `patches_info.json` / `bug-map.json` that `make upload` (only `*.zip`) leaves
  out - is checked on the first run. If it refuses, upload those JSON files too,
  or fall back to MOS by revoking the PAR

## Step 5 - Verify

```bash
make cpu-lab-verify
```

Checks that `/etc/oratab` points at the target home, that `version_full` matches
`db_target_ru`, that the registry has no errors, and that `datapatch -prereq`
reports nothing pending. Read-only, safe to re-run.

## Step 6 - Tear down

```bash
make cpu-lab-destroy         # asks for confirmation
make cpu-lab-destroy YES=1   # unattended
```

Terraform never creates or deletes a compartment, so `destroy` leaves nothing
behind. OCI deletes compartments asynchronously, which is precisely why the lab
deploys into an existing one.

## Full cycle

```bash
make cpu-lab-cycle    # apply -> install -> patch -> verify
```

Leaves the lab running so results can be inspected. Tear down separately.

## Workshops - more than one host

```bash
make cpu-lab-plan
# or directly:
cd terraform/envs/cpu-patch-test && terraform plan -var="lab_count=4"
```

Hosts are identical and indexed: `ci-chzh-l-cpupt-01-db-01` … `-db-04`,
hostnames `oradb01` … `oradb04`. The generated inventory grows with it, no
manual editing required.

## Variable reference

Full tables are in
[`terraform/envs/cpu-patch-test/README.md`](../terraform/envs/cpu-patch-test/README.md).
The ones that matter per quarter:

<!-- markdownlint-disable MD013 -->

| Variable | Where | Default | Purpose |
| --- | --- | --- | --- |
| `db_base_ru` | `.env` / tfvars | `19.31` | RU the database is installed with (previous) |
| `db_target_ru` | `.env` / tfvars | `19.32` | RU the CPU test patches to (current) |
| `db_base_image_url` | `.env` | - | PAR serving the 19c base image |
| `db_oracle_root` / `_data` / `_arch` | tfvars | `/u00` `/u01` `/u02` | Filesystem roots |
| `oracle_sid` | `.env` / tfvars | `CPUDB` | Lab database name |
| `lab_count` | `.env` / tfvars | `1` | Number of identical hosts |
| `allowed_ssh_cidrs` | `.env` / tfvars | `[]` | External CIDRs allowed to SSH |
| `compartment_ocid` | `.env` / tfvars | - | Base compartment, never created by Terraform |
| `assign_public_ip` | tfvars | `true` | Public subnet plus public IP |
| `enable_auto_stop` | tfvars | `true` | Daily auto-stop schedule; set `false` for AutoUpgrade runs |

<!-- markdownlint-restore -->

## Secrets

| Secret | Source |
| --- | --- |
| MOS username / password | 1Password `secrets/Oracle-MOS` via `op read` |
| Database SYS / SYSTEM | generated by Terraform, `terraform output -raw db_sys_password` |
| AutoUpgrade keystore | generated by Terraform, `terraform output -raw autoupgrade_keystore_password` |
| Base image PAR | `db_base_image_url` in `.env`, 7-day expiry |
| SSH lab private key | generated by Terraform into `.ssh/cpu-lab` |

The generated password and private key live in `terraform.tfstate`, which is
local and git-ignored. Acceptable for a throw-away lab - remember they are
recoverable from state.

The AutoUpgrade keystore is created once in auto-login mode (`cwallet.sso`), so
every later AutoUpgrade run is fully non-interactive. Loading it requires the
interactive `-load_password` prompt, which the role drives with `expect` because
Oracle exposes no flag, environment variable, or file for MOS credentials.

## Troubleshooting

### terraform plan asks for a variable

Older revisions required `TF_VAR_ssh_public_key`. Current code needs no
environment variable at all - `~/.ssh/id_ed25519.pub` is read from disk and the
lab keypair is generated. If a variable is still prompted, check that
`terraform.tfvars` exists and supplies `compartment_ocid`.

### No base compartment resolved

Set `compartment_ocid`, or set `compartment_name` together with `tenancy_ocid`.
The name must match exactly one ACTIVE compartment.

### Cannot SSH to the host

`allowed_ssh_cidrs` defaults to empty, which means no external SSH at all. With
`assign_public_ip = true` the host then has a public IP nobody can reach. Set
your own address and re-apply:

```bash
curl -s -4 https://ifconfig.me
```

An IPv6 address cannot be used - the VCN is IPv4-only.

### AutoUpgrade cannot find a base image

Oracle states that for 19c and 21c "AutoUpgrade Patching cannot automatically
download this base image". A home could be built media-free only from a gold
image out of the Oracle Update Advisor, and for 19c that service currently
answers HTTP 500 - see "The Oracle 19c base image" above.
`db19_autoupgrade_gold_image` stays at `AUTO` for `create_home` because that path
tolerates the failure; download jobs pin `NO`.

If `download` reports no base or gold image, stage the base zip once:

```bash
scp -i .ssh/cpu-lab LINUX.X64_193000_db_home.zip opc@<ip>:/tmp/
ssh -i .ssh/cpu-lab opc@<ip> 'sudo mv /tmp/LINUX.X64_193000_db_home.zip /opt/stage/ && sudo chown oracle:oinstall /opt/stage/*.zip'
```

Alternatively build the base home once and keep it as a **self-made** gold image
(`install1.create_gold_image=<name>.zip` on a `create_home` run, then
`install1.patch=GOLDIMAGE:<name>.zip` on every later host). That is independent
of the broken Update Advisor - it still needs the base image once to create the
artifact, but afterwards a home installs in about two minutes instead of
twenty-five.

### AutoUpgrade version too old

`create_home` exists from AutoUpgrade 24.7, but the
`home_settings.inventory_location` and `inventory_group` parameters this lab
needs on a host without `/etc/oraInst.loc` only arrived in 25.3.

```bash
make cpu-lab-step TAG=autoupgrade   # after:
# -e db19_autoupgrade_force_download=true
```

### root.sh was not executed

AutoUpgrade runs `root.sh` and `orainstRoot.sh` itself only when the `oracle`
user has passwordless sudo. It does not here, so the role runs them explicitly
afterwards. AutoUpgrade prints them to the console and to
`<global_log_dir>/create_home_1/<job>/rootsh/rootsh.log` rather than blocking.

### Where are the AutoUpgrade logs

```text
/u01/app/oracle/cfgtoollogs/autoupgrade/          global_log_dir
/u01/app/oracle/etc/autoupgrade/                  generated configs
/u01/app/oracle/etc/autoupgrade/keystore/         MOS keystore
/opt/stage/                                       downloaded media
```

### Auto-stop interrupted a patch run

`enable_auto_stop` is `true` by default (nightly `STOP_RESOURCE` at 18:00 UTC).
For AutoUpgrade runs set `enable_auto_stop = false` explicitly in `terraform.tfvars`
or via `TF_VAR_enable_auto_stop=false` before applying - a mid-run stop wrecks the
patch attempt. The default is intentionally safe for idle labs; opt out when you run.

## Related documents

- [`terraform/envs/cpu-patch-test/README.md`](../terraform/envs/cpu-patch-test/README.md) - variable reference
- [`terraform/modules/oracle_db_host/README.md`](../terraform/modules/oracle_db_host/README.md) - compute module
- [`namingconcept.md`](namingconcept.md) - naming convention
- [`runbook-ad-cmu-lab.md`](runbook-ad-cmu-lab.md) - Windows AD lab, same patterns
