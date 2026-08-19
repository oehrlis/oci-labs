# cpu-patch-test

Throw-away Oracle Database lab on OCI for quarterly **Critical Patch Update
(CPU)** testing. Terraform builds the VCN and *N* Oracle Linux 8 hosts; Ansible
(`db19_engineering`, Gate 2) installs Oracle 19c at the base RU; AutoUpgrade
(Gate 3) patches out-of-place to the target RU.

This stack is the **infrastructure layer** only. Reporting stays in
[`cpu-patch-tests`](https://github.com/oehrlis/cpu-patch-tests), which is not
modified from here.

- Stack code: `cpupt` - resource names read `chzh-l-cpupt-01`
- OS: Oracle Linux 8 (OL9 cannot run the 19.3.0 base release)
- Lifecycle: build, install, patch, verify, destroy

## Prerequisites

- Terraform >= 1.5
- OCI CLI config `~/.oci/config` with a profile for the lab tenancy
  (default `TRIVADIS`; `DEFAULT` points at the same tenancy `trivadisbdsxsp`)
- Ansible (for Gates 2 and 3)
- Optional: 1Password CLI (`op`) - otherwise use a `.env` file

## Quick start

```bash
cd terraform/envs/cpu-patch-test

# 1. SSH keypair for this lab lifecycle (.ssh/ is git-ignored)
mkdir -p .ssh
ssh-keygen -t ed25519 -f .ssh/cpu-lab -N "" -C "cpu-patch-test lab"

# 2. Variables
cp .env.example .env
$EDITOR .env
source .env

# 3. Plan
terraform init
terraform plan -out=tfplan

# 4. Build
terraform apply tfplan

# 5. Connect
terraform output ssh_commands
```

Tear down when the test cycle is finished:

```bash
terraform destroy
```

## Secrets handling

Precedence, highest first:

1. **1Password** (Stefan's setup) - single-line `op read`, no backslash continuation:

   ```bash
   export TF_VAR_ssh_public_key=$(op read "op://oradba-labs/cpu-lab-ssh/public key")
   ```

2. **`.env` file** (no 1Password available) - copied from `.env.example`, always
   git-ignored:

   ```bash
   export TF_VAR_ssh_public_key=$(cat .ssh/cpu-lab.pub)
   ```

3. `terraform.tfvars` - use for non-secret values only. `ssh_public_key` is
   deliberately absent from `terraform.tfvars.example`.

Nothing secret is committed: `.env`, `.ssh/`, `terraform.tfvars`, and all state
files are covered by `.gitignore` here and at the repository root.

## Access model

<!-- markdownlint-disable MD013 -->

| `assign_public_ip` | Subnet | Reachability |
| --- | --- | --- |
| `true` (default) | public subnet | Public IP, SSH restricted to `allowed_ssh_cidrs` |
| `false` | private DB subnet | Intra-VCN only - needs a jumphost or DRG/VPN |

<!-- markdownlint-restore -->

`allowed_ssh_cidrs` defaults to `[]`, which means **no external SSH**. With
`assign_public_ip = true` and an empty list the host gets a public IP that
nobody can reach - set your own address (`x.x.x.x/32`) before applying. SSH from
inside the VCN CIDR is always permitted.

## Accenture OCI security standards

Enforced by the modules, not optional:

- `is_pv_encryption_in_transit_enabled = true` (instances and volume attachments)
- `are_legacy_imds_endpoints_disabled = true` (IMDSv2 only)
- VCN flow logs on every subnet (`network` module, `enable_flow_logs = true`)
- No `0.0.0.0/0` SSH ingress by default

## Ansible inventory

`terraform apply` writes a ready-to-use inventory to a git-ignored path:

```text
ansible/inventories/generated/cpu-patch-test/hosts.yml
```

It contains the group `cpu_patch_hosts` with one entry per host plus the group
vars `oracle_sid`, `oracle_base`, `db_base_ru`, `db_target_ru`,
`oracle_home_base`, and `oracle_home_target` - so the patch level is described
once, in Terraform, and flows through to AutoUpgrade.

```bash
terraform output ansible_inventory_path

cd ../../ansible
ansible-playbook -i inventories/generated/cpu-patch-test/hosts.yml \
  playbooks/lab-cpu-patch.yml --tags install
```

## Workshops - more than one host

```bash
terraform plan -var="lab_count=4"
```

Each host is identical and gets its own index: `ci-chzh-l-cpupt-01-db-01` …
`-db-04`, hostnames `oradb01` … `oradb04`. The generated inventory grows with
it, no manual editing required.

## Variable reference

<!-- markdownlint-disable MD013 -->

### Provider and naming

| Variable | Type | Default | Description |
| --- | --- | --- | --- |
| `oci_config_profile` | string | `TRIVADIS` | Profile in `~/.oci/config`. |
| `compartment_ocid` | string | - | **Required.** Compartment for all resources. |
| `region_key` | string | `chzh` | Region key used in names. |
| `environment_code` | string | `l` | `l` lab, `ws` workshop, `t` test. |
| `stack_code` | string | `cpupt` | Stack code used in names. |
| `lab_instance` | number | `1` | Index for parallel labs (1 -> `01`). |
| `common_freeform_tags` | map(string) | project/owner | Base freeform tags. |

### Network

| Variable | Type | Default | Description |
| --- | --- | --- | --- |
| `vcn_cidr` | string | `10.29.0.0/16` | VCN CIDR. |
| `public_subnet_cidr` | string | `10.29.10.0/24` | Public subnet. |
| `private_subnet_cidr` | string | `10.29.20.0/24` | Private subnet. |
| `db_subnet_cidr` | string | `10.29.30.0/24` | Private DB subnet. |
| `enable_flow_logs` | bool | `true` | VCN flow logs (Accenture standard). |
| `flow_log_retention_duration` | number | `30` | Retention in days, 30-day steps. |
| `allowed_ssh_cidrs` | list(string) | `[]` | External CIDRs allowed to SSH. |
| `drg_id` | string | `null` | Existing DRG for site-to-site VPN. |
| `home_cidrs` | list(string) | `[]` | CIDRs routed via DRG. |

### DB hosts

| Variable | Type | Default | Description |
| --- | --- | --- | --- |
| `lab_count` | number | `1` | Number of identical DB hosts. |
| `instance_image_ocid` | string | `null` | Explicit OL8 image OCID; skips lookup. |
| `ol_version` | string | `8` | Oracle Linux version for the lookup. |
| `db_host_shape` | string | `VM.Standard.E4.Flex` | Compute shape (x86 only). |
| `db_host_ocpus` | number | `2` | OCPUs per host. |
| `db_host_memory_gbs` | number | `16` | Memory in GB per host. |
| `db_host_boot_volume_size_gbs` | number | `200` | Boot volume in GB (min 100). |
| `assign_public_ip` | bool | `true` | Public subnet + public IP. |
| `attach_data_volume` | bool | `false` | Extra block volume per host. |
| `data_volume_size_gbs` | number | `100` | Data volume size in GB. |
| `ssh_public_key` | string | - | **Required.** Public key for `opc`. |
| `enable_auto_stop` | bool | `false` | Daily auto-stop schedule. |
| `auto_stop_cron` | string | `0 18 * * *` | Auto-stop cron (UTC). |

### Oracle DB and patch level

| Variable | Type | Default | Description |
| --- | --- | --- | --- |
| `oracle_sid` | string | `CPUDB` | ORACLE_SID of the lab database. |
| `db_base_ru` | string | `19.31` | RU the DB is installed with (previous RU). |
| `db_target_ru` | string | `19.32` | RU AutoUpgrade patches to (current RU). |
| `db_oracle_root` | string | `/u00` | ORACLE_BASE and binaries root. |
| `db_oracle_data` | string | `/u01` | Data root - datafiles. |
| `db_oracle_arch` | string | `/u02` | Archive root - archived redo and FRA. |
| `db_oracle_base` | string | `""` | ORACLE_BASE; empty = derived from `db_oracle_root`. |
| `db_base_image_url` | string | `""` | PAR serving `LINUX.X64_193000_db_home.zip`. **Required** - AutoUpgrade cannot fetch it. |
| `ansible_python_interpreter` | string | `/usr/bin/python3.11` | OL8's 3.6 is too old for ansible-core. |
| `db_oracle_home_base` | string | `""` | Base ORACLE_HOME; empty = derived. |
| `db_oracle_home_target` | string | `""` | Target ORACLE_HOME; empty = derived. |

<!-- markdownlint-restore -->

## Outputs

<!-- markdownlint-disable MD013 -->

| Output | Description |
| --- | --- |
| `lab_name_core` | Core name segment, e.g. `chzh-l-cpupt-01`. |
| `vcn_id` | VCN OCID. |
| `db_host_subnet_id` | Subnet OCID actually used by the hosts. |
| `db_instance_ids` / `db_instance_names` | Host OCIDs / display names. |
| `db_private_ips` / `db_public_ips` | Host IPs, keyed by index. |
| `ssh_commands` | Ready-to-paste SSH command per host. |
| `ansible_inventory_path` | Path of the generated inventory. |
| `oracle_base` | Effective ORACLE_BASE. |
| `oracle_home_base` / `oracle_home_target` | Effective ORACLE_HOME paths. |
| `db_sys_password` | Generated SYS/SYSTEM password (sensitive). |
| `autoupgrade_keystore_password` | Generated AutoUpgrade keystore password (sensitive). |
| `ssh_authorized_key_count` / `ssh_authorized_key_comments` | Authorised keys, comments only. |
| `lab_private_key_path` | Path of the generated lab private key. |
| `auto_stop_schedule_id` | Auto-stop schedule OCID, or `null`. |

<!-- markdownlint-restore -->

## Notes and gotchas

- **Release Updates: previous to current only.** AutoUpgrade serves the current
  and the previous RU; `RU:19.26` to `RU:19.30` report "Cannot find the latest
  Release Update". Shift both RUs by one each quarter.
- **The 19c base image must be staged.** AutoUpgrade downloads every patch but
  not `LINUX.X64_193000_db_home.zip`, and the Oracle Updater service currently
  returns HTTP 500 for gold-image lookups. Set `db_base_image_url` to a
  pre-authenticated request. See the runbook for the exact command.

- **Auto-stop is off by default.** A daily `STOP_RESOURCE` in the middle of an
  AutoUpgrade run corrupts the patch attempt. Enable it only for a lab that
  idles between test runs.
- **Boot volume sizing.** Two `ORACLE_HOME`s (base RU + target RU) plus install
  media need real space; do not drop below the 200 GB default without testing.
- **Image OCID drift.** The instance ignores changes to the image OCID
  (`lifecycle.ignore_changes`) so a new OL8 build published by Oracle does not
  replace a running lab host. Destroy and rebuild to pick up a newer image.
- **`CV_ASSUME_DISTID`.** Oracle 19c prerequisite checks fail on OL8 unless
  `CV_ASSUME_DISTID=OEL7.9` is set. That is handled in the Ansible role, not here.
