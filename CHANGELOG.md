# Changelog

All notable changes to this project will be documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
