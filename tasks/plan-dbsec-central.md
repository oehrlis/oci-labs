# Plan - Oracle Database Security Central lab on OCI (2026-11-17)

## Goal

A disposable Oracle Database Security Central (DBSecCentral, successor of AVDF) lab on OCI, built from the
Marketplace image with the same lab pattern as `envs/datasafe-demo`: own core (VCN + Bastion), no public IP,
access by Bastion port forwarding, start/stop schedules, `make dbsec-*` targets. Infrastructure only - demos and
lab content belong to oradba-labs.

## Research result (verified 2026-11-17)

Marketplace, read with the OCI CLI (`oci marketplace listing list --name "Security Central"`):

| Item | Value |
| --- | --- |
| Listing | `Oracle Database Security Central`, package type IMAGE, listing version 2.26.0.0.0 |
| Packages | `Oracle_Database_Security_Central_v2.26_AVS` (Audit Vault Server), `..._v2.26_FW` (Database Firewall), both 2026-07-31 |
| Region | eu-zurich-1 is in the package region list |
| Shapes | E3/E4/E5/E6.Flex, Standard3.Flex, Optimized3.Flex and older fixed shapes - x86 only, no Ampere |
| Minimum | 2 OCPU, 8 GB, 220 GB block storage (listing system requirements) |

Documentation (docs.oracle.com, `sigad` Administrator's Guide and `sigig` Installation Guide):

- Provisioning: VM standard shape, min 8 GB, boot volume default 220 GB (max 2 TB), SSH key type ed25519,
  ecdsa-p384 or rsa-sha2-512. "Wait a few minutes" after RUNNING for the services
  (`sigad/provisioning-oracle-avdf-oracle-cloud-marketplace-image.html`)
- Post-install AVS (one time): SSH as `opc`, `sudo passwd root`, then
  `sudo -u oracle /usr/local/dbfw/bin/generate_post_install_passphrase.py`, open `https://<ip>`, enter the
  passphrase, set Super Administrator, Super Auditor, Repository Encryption Keystore passwords. The "AVS IP for
  Agent Communication" cannot be changed afterwards
- Post-install FW: only `sudo passwd root`, then register the firewall in the AVS console
- Verify: `systemctl get-default` = `avdf-runtime.target`, `systemctl is-active avdf-runtime.target`,
  `grep -an "Completed Oracle Database Security Central OCI first boot system setup" /var/log/debug*`
- OCI differences: key-based SSH only, network settings read-only, NTP fixed, DNS 169.254.169.254, no secondary
  VNIC, DB Firewall only Proxy and Host Monitor (no out-of-band), no HA with RAC
  (`sigad/changes-functionality-oracle-avdf-instances-oci.html`)
- AVS ports: 443 console, 1521 agents and reporting, 7447 agent activation and connection, 7443 HA, 22 SSH
  (`sigad/ports.html`). Agent host: 512 MB RAM, supported Java, time drift under 2 s, ports 1521 and 7447 to the
  AVS. Agentless collection: up to 20 Oracle table audit trails without an agent
- Hardware page (on-prem): AVS 370 GB, FW 220 GB disk - the Marketplace default of 220 GB is lower; sizing for
  real use MOS Doc ID 2092683.1

Open in the research (not found, only measurable):

- Duration of first boot and post-install configuration - "a few minutes" is all the doc says
- Marketplace terms: `oci compute pic agreements get` returned no EULA link; the Terraform agreement resource
  shows whether a signature is required
- Free use until 2027-02-28 "for eligible customers" (product page, InfoWorld) - conditions not found
- LiveLabs workshop (wid=4410) - content and duration not checked

## Design

| Item | Proposal |
| --- | --- |
| Env | `terraform/envs/dbsec-central`, stack code `dbsec` |
| Core | `module "core"` with `core_owner = "dbsec"`, Bastion on, no artifact bucket (pattern `datasafe-demo`) |
| Image | data sources `oci_core_app_catalog_listing` / `_resource_version` by name and package version, then `oci_core_app_catalog_listing_resource_version_agreement` + `oci_core_app_catalog_subscription` - no OCID in the repo |
| AVS host | `module "compute_host"`, component `avs`, E5.Flex 2 OCPU / 16 GB, boot 300 GB, no user_data, no public IP |
| FW host | optional (`enable_firewall = false`), component `dbfw`, same shape, 220 GB |
| Target DB | optional, see question 3 |
| NSG | ingress from VCN CIDR: 22, 443, 1521, 7447; FW: proxy port range when enabled |
| Access | Bastion port forwarding to 22 (SSH as `opc`) and 443 (console on `https://127.0.0.1:<port>`) - managed SSH sessions need the Bastion plugin, which the appliance likely lacks |
| Cost | Resource Scheduler start/stop like `datasafe-demo` (`schedule_profile`) |
| Secrets | appliance passwords generated in Terraform state or 1Password - question 4 |

## Steps

### 0. Clarify (one round, see questions below)

- [ ] Tenancy/profile, scope (AVS only or with FW), target DB, password source, autonomy (commit/push/PR)

### 1. Checks before anything is created

- [ ] Compute capacity E5.Flex 2/16 in eu-zurich-1 for the chosen profile
- [ ] Rights: Marketplace subscription (`manage app-catalog-listing`), Bastion, IAM policy for the scheduler
- [ ] Agreement resource in `terraform plan`: EULA link and signature field visible

### 2. Terraform env `envs/dbsec-central`

- [ ] `provider.tf`, `variables.tf`, `terraform.tfvars.example`, `.env.example` from `datasafe-demo`
- [ ] `main.tf`: naming, compartment guard, core, Marketplace lookup + agreement + subscription, AVS host,
  optional FW host, schedules, scheduler policy
- [ ] `outputs.tf`: private IPs, Bastion ID, console URL hint, next steps
- [ ] README with build, post-install, teardown
- [ ] `make lint-terraform` green (fmt + validate of the new env)

### 3. Access

- [ ] Tunnel script `demos/dbsec-central/tunnel.sh` (or generalise `datasafe-lrn6087/tunnel.sh` with
  `--target-port`), ports 22 and 443
- [ ] Makefile: `dbsec-plan`, `dbsec-apply`, `dbsec-tunnel`, `dbsec-console`, `dbsec-postinstall`
  (prints the passphrase via SSH), `dbsec-verify` (read-only checks above), `dbsec-stop`, `dbsec-start`,
  `dbsec-destroy` - all with `--dry-run`/`YES=1` like the dsdemo targets

### 4. Build and measure

- [ ] `make dbsec-plan` -> review -> `make dbsec-apply`, time RUNNING -> first-boot message in `/var/log/debug`
- [ ] Post-install via console, users and keystore password from the chosen secret source
- [ ] `make dbsec-verify` green; record the measured times in the runbook
- [ ] Optional: register a target DB (agentless table audit trail first, then the agent)

### 5. Docs and release

- [ ] `docs/runbook-dbsec-central.md` (build, post-install, verify, stop/start, teardown, measured durations)
- [ ] CHANGELOG `Added`, VERSION 0.5.0, `markdownlint docs/` green
- [ ] Branch `feat/dbsec-central-lab`, PR

## Questions

1. Tenancy and profile: ACE, TRIVADIS (DEFAULT) or another one?
2. Scope: Audit Vault Server only, or with Database Firewall (proxy mode) from the start?
3. Target DB: none at first, reuse the `datasafe-demo` host (19c + 26ai, peering or same VCN), or a new small
   19c/26ai host in this stack?
4. Appliance passwords (Super Admin, Super Auditor, keystore): generated in the Terraform state like the dsdemo
   SYS password, or in 1Password?
5. Autonomy: write code, lint, apply on your go - commit, push and PR also by me?
