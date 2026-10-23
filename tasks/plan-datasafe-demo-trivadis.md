# Plan - LRN6087 demo lab: ACE tenancy -> Trivadis tenancy (2026-10-23)

## Why

ACE tenancy: Data Safe target limit exhausted. With two ACTIVE targets (ATP26AI02, oradb01_CDB19_CDBROOT) any
further `target-database create` returns 400 LimitExceeded "The limit for this tenancy has been exceeded" - even
after deleting the two INACTIVE targets. The demo needs 6 targets (CDB19/CDB26 root + 2 PDBs each) plus the live
PDB `AIPDB1`.

## Target picture (Trivadis tenancy, eu-zurich-1, profile TRIVADIS)

| Item | Value |
| --- | --- |
| Compartment | `comp-oradba-dsdemo`, new, below `Projects_Internal` |
| Naming | same as cpu-lab: `region_key = "chzh"`, `environment_code = "l"`, `stack_code = "dsdemo"`, instance 01 |
| Host | `ci-chzh-l-dsdemo-01-db-01`, VCN `vcn-chzh-l-dsdemo-01-net-01`, private DB subnet |
| Shape | VM.Standard.E5.Flex 4 OCPU / 32 GB (capacity check before apply) |
| Connector | `dsc-chzh-l-dsdemo-01`, port 1561 |
| Tags | namespace `DBSec` at tenancy level (approved 2026-10-23) |
| Media | `orarepo` bucket is in this tenancy already (profile DEFAULT = TRIVADIS) |

Security baseline (unchanged modules, verified in code):

- no public IP on the host (`assign_public_ip = false` in `envs/datasafe-demo/main.tf`)
- `allowed_ssh_cidrs = []` - public and DB security lists have no internet ingress; the public subnet exists in
  the network module but stays empty
- access only via OCI CLI, Bastion port forwarding (managed SSH session), Cloud Console
- IMDSv2 only (`are_legacy_imds_endpoints_disabled = true` in `modules/oracle_db_host`)
- VCN flow logs on all subnets (`enable_flow_logs = true`, logging log group)
- Resource Scheduler start/stop (`schedule_profile`), plus the scheduler policy

## Steps

### 0. Checks before anything is created

- [ ] Data Safe enabled in Trivadis eu-zurich-1 (console or a harmless list call)
- [ ] Rights: create compartment below `Projects_Internal`, tag namespace at root, IAM policy (scheduler),
  Bastion, Data Safe connector and targets
- [ ] Compute capacity E5.Flex 4/32 in eu-zurich-1 (compute-capacity-report)

### 1. ACE cleanup (profile ACE)

- [ ] Data Safe: delete target `oradb01_CDB19_CDBROOT` and connector `dsc-zrh-lab-dsdemo-01`
- [ ] `make dsdemo-destroy` - VM, data volume, VCN, Bastion, logs, scheduler, local inventory and lab key
- [ ] Tag namespace `DBSec` in ACE: retire and delete (unused there afterwards)
- [ ] ATP26AI02 and the RAG schema stay until after the talk (2026-10-27), then `04_reset.sql`
- [ ] Laptop: tunnel on 2223 ends with the destroy; `.env` / `terraform.tfvars` of the ACE stack are rewritten in
  step 3, no separate state (local state, destroyed first)

### 2. Trivadis base

- [ ] Compartment below `Projects_Internal` (OCI CLI, not Terraform - the stack never creates compartments)
- [ ] `ds_tag_namespace.sh -f demos/datasafe-lrn6087/dbsec-tag-namespace.json --oci-profile TRIVADIS` plan, then
  `--apply`
- [ ] 1Password: `datasafe-demo-ds-admin` stays (secret with special character)

### 3. Deploy (oci-labs worktree `oci-labs-datasafe-demo`, branch `feat/datasafe-demo`)

- [ ] `.env`: `TF_VAR_oci_config_profile=TRIVADIS`, compartment OCID, `DSDEMO_PAR_PROFILE=DEFAULT` (same tenancy)
- [ ] `terraform.tfvars`: `region_key = "chzh"`, `environment_code = "l"`, `stack_code = "dsdemo"`,
  `db_host_shape = "VM.Standard.E5.Flex"`, `ds_connector_name = "dsc-chzh-l-dsdemo-01"`,
  `schedule_profile = "off"` during the install, `enable_flow_logs = true`, `allowed_ssh_cidrs = []`
- [ ] `make dsdemo-plan` - review: no public IP, no 0.0.0.0/0 ingress, IMDSv2, flow logs; then `dsdemo-apply`
- [ ] `dsdemo-par`, tunnel on a port other than the cpu-lab (2222 is taken): `DSDEMO_LOCAL_PORT=2223`
- [ ] `dsdemo-install` - all fixes of 2026-10-22/23 are on the branch (getent, 26ai download, connector);
  odb_datasafe 1.3.1 still has the CONTAINER=ALL bug -> copy the fixed SQL before `ds_prereqs` or bump to 1.3.2 if
  released by then
- [ ] Connector: create in OCI, bundle via `--from-json` (password with special character), copy, `TAG=connector`
- [ ] `par-revoke`, `TAG=verify`, schedule `cest`

### 4. Laptop and demo

- [ ] `~/demo/odb_datasafe-1.3.1/.env`: Trivadis compartment, connector `dsc-chzh-l-dsdemo-01`, profile TRIVADIS
- [ ] `demo.env`: `DEMO_OCI_PROFILE="TRIVADIS"`, `DEMO_COMP`, `DEMO_CONNECTOR`
- [ ] `demo.sh check`, `register-base` (6 targets), `demo.sh --dry-run run`, `demo.sh run`, `reset.sh`
- [ ] Probe and recording (fallback)
- [ ] Before the flight: `make dsdemo-schedule PROFILE=pdt && make dsdemo-apply`

### 5. Docs

- [ ] Runbook `docs/datasafe-demo.md`: tenancy, naming, tunnel port, bundle via `--from-json`, secret rules
- [ ] Slides: names on the demo slides (`oradb01`, `CDB19`/`CDB26`, connector name, compartment) - only if the
  compartment or connector name is visible

## Decisions (Stefan, 2026-10-23)

- Compartment `comp-oradba-dsdemo`, `DBSec` at tenancy level ok
- Run without further questions up to `register-base` once step 0 is green; stop on any deviation
- Flight Sunday 2026-10-25: Saturday is the buffer for probe and recording, `pdt` before the flight

## Time

Destroy ACE ~15 min, base ~15 min, apply ~10 min, install 1.5-2.5 h, connector + verify ~20 min, register-base
~15 min. Total about 3-3.5 h, most of it unattended.
