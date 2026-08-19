# Changelog

All notable changes to this project will be documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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

### Changed

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

### Fixed

- **env/ad-cmu-test**: Ansible inventory (`hosts.yml`) is now written immediately at
  the start of `null_resource.wait_for_winrm` provisioner, before the WinRM polling
  loop. Previously the IP was only written after WinRM became reachable, leaving the
  inventory stale when apply was interrupted or run without VPN connectivity.
- **env/ad-cmu-test**: Inventory path uses `abspath(path.root)` instead of `path.root`
  so the path resolves correctly regardless of the working directory terraform is
  invoked from.
- **env/ad-cmu-test**: Inventory `hosts.yml` added to version control with current
  private IP (`10.19.50.93`) for the `windc01` host.

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
