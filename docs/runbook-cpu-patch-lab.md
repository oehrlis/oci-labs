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
- Tenancy: `trivadisbdsxsp`, OCI profile `TRIVADIS`, compartment `cpureport`
- OS: Oracle Linux 8 - OL9 cannot run the 19.3.0 base release
- Lifecycle: build, install, patch, verify, destroy

## Architecture

```text
Workstation (macOS)                        OCI - compartment cpureport
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

## Prerequisites

```bash
brew install terraform ansible ansible-lint yamllint 1password-cli
npm install -g markdownlint-cli
ansible-galaxy collection install -r ansible/requirements.yml
```

- OCI CLI config `~/.oci/config` with the `TRIVADIS` profile (`DEFAULT` points at
  the same tenancy `trivadisbdsxsp`)
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
`trivadisbdsxsp`, 3'059'705'302 bytes:

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
| `enable_auto_stop` | tfvars | `false` | Daily auto-stop schedule |

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

`enable_auto_stop` is `false` by default precisely because a daily
`STOP_RESOURCE` in the middle of an AutoUpgrade run wrecks the attempt. Enable
it only for a lab that idles between test runs.

## Related documents

- [`terraform/envs/cpu-patch-test/README.md`](../terraform/envs/cpu-patch-test/README.md) - variable reference
- [`terraform/modules/oracle_db_host/README.md`](../terraform/modules/oracle_db_host/README.md) - compute module
- [`namingconcept.md`](namingconcept.md) - naming convention
- [`runbook-ad-cmu-lab.md`](runbook-ad-cmu-lab.md) - Windows AD lab, same patterns
