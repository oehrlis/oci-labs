# Changelog

All notable changes to this project will be documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

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
  Stack-code `windc`, domain `trivadislabs.com`. Windows Server 2022 image lookup via
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
