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
image. Verified on 2026-08-19 with AutoUpgrade 26.5 and working MOS credentials:

<!-- markdownlint-disable MD013 -->

| Attempt | Result |
| --- | --- |
| `create_home` + `gold_image=AUTO` | `A usable base image file is not found in /opt/stage` |
| `create_home` + `gold_image=YES`/`ALL` | `Unable to find any Gold Image containing the requested patches` |
| any download job with `gold_image` != `NO` | `Failed to process the gold_image parameter for prefix <p>` |

<!-- markdownlint-restore -->

The gold-image route would otherwise be ideal - the AutoUpgrade 26.2 notes state
that 19c gold images "include the base release as well which otherwise you would
need to download separately". It is currently blocked server side, visible only
in `<log_dir>/cfgtoollogs/patch/auto/aru/ous.log`:

```text
transport.oracle.com/v2/patchplanner/registration   16 calls   OK
transport.oracle.com/v2/patchplanner/requests        6 calls   ALL HTTP 500
  -> UpdaterInfoPerPrefix{latestVersion='N/A', versionToUse='N/A'}
```

Until that is resolved, stage `LINUX.X64_193000_db_home.zip` via
`db_base_image_url`. The file already exists in the tenancy - bucket `orarepo`,
namespace `trivadisbdsxsp`, 3'059'705'302 bytes:

```bash
oci --profile TRIVADIS os preauth-request create --bucket-name orarepo \
  --name cpu-lab-base-image-19c --object-name LINUX.X64_193000_db_home.zip \
  --access-type ObjectRead --time-expires 2026-08-26T12:00:00.000Z
```

Keep the expiry short (7 days) so the pre-authenticated request stays inside
Accenture monitoring thresholds. Put the returned URI in `.env`:

```bash
export TF_VAR_db_base_image_url="https://<namespace>.objectstorage.<region>.oci.customer-oci.com/p/<token>/n/<ns>/b/orarepo/o/LINUX.X64_193000_db_home.zip"
```

Both PAR shapes work: a bucket PAR ending in `/o/` gets the filename appended, a
single-object PAR is used verbatim. `gold_image` stays at `AUTO`, so a working
Updater service is picked up automatically with no code change.

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
download this base image". A home can be built media-free only when a gold image
is available from the Oracle Updater service (`LINUX.X64` only), which is why
`db19_autoupgrade_gold_image` defaults to `AUTO`.

If `download` reports no base or gold image, stage the base zip once:

```bash
scp -i .ssh/cpu-lab LINUX.X64_193000_db_home.zip opc@<ip>:/tmp/
ssh -i .ssh/cpu-lab opc@<ip> 'sudo mv /tmp/LINUX.X64_193000_db_home.zip /opt/stage/ && sudo chown oracle:oinstall /opt/stage/*.zip'
```

Alternatively move `db_base_ru` to the oldest RU that has a gold image, which
removes the manual media step entirely.

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
