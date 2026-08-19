# Plan: CPU Patch Test Lab in oci-labs

> Autonomous implementation brief. Run this in a Claude session inside
> `~/Repos/own/oehrlis/oci-labs`. Work gate by gate; present a diff/summary
> at each gate before moving to the next. Stop and ask if a decision is
> ambiguous.

## Context

Stefan runs Oracle Critical Patch Update (CPU) tests quarterly. The current
setup (`~/Repos/accenture/tvd-cpureport/oci/`) uses cloud-init + bash with
manually uploaded OCI bucket patches - too manual, not reusable.

**Goal**: A modular, reusable lab in `oci-labs` that:
- Builds an OL8 OCI compute instance with Oracle DB 19c installed via oradba
- Patches from a configurable base RU to the current target RU using AutoUpgrade
  (out-of-place, new ORACLE_HOME)
- Tears everything down cleanly after tests
- Is count-parametrized (1-N identical instances for workshops)
- Runs on OCI (primary), later Docker (stub only now)
- Is the **infrastructure layer** only; `cpu-patch-tests` remains the
  reporting steuerpult and is **not modified here**

## Repos and References

### Primary (build here)

```
~/Repos/own/oehrlis/oci-labs/
  terraform/
    modules/naming/       - existing naming module (use as-is)
    modules/network/      - existing network module (VCN, subnets, flow logs)
    modules/windows_ad/   - pattern reference for compute module
    envs/ad-cmu-test/     - pattern reference for env assembly
    envs/cpu-patch-test/  - CREATE THIS (new env)
  ansible/
    roles/db19_engineering/ - existing stub (tasks/ only, no content yet)
    roles/common/         - existing base role
    roles/base_ssh/       - existing SSH setup role
    playbooks/            - add lab-cpu-patch.yml here
```

### Reference (read-only, do not modify)

```
~/Repos/accenture/tvd-cpureport/oci/host_db19c/  - old cloud-init pattern
~/Repos/own/oehrlis/cpu-patch-tests/scripts/      - au_*.sh AutoUpgrade scripts
~/Repos/own/oehrlis/cpu-patch-tests/patches/      - patch dir structure (19/21/26)
```

### External References

- oradba environment scripts: https://github.com/oehrlis/oradba
  (environment setup, aliases, config, scripts - replaces old BasEnv)
- oradba_init: https://github.com/oehrlis/oradba_init
  (old init/setup/config scripts - reference only, not used directly)
- Oracle AutoUpgrade docs for out-of-place patching

## Architecture Decisions (final)

| Decision | Choice | Reason |
|---|---|---|
| OS | OL8 | OL9 cannot run native 19.3.0; OL8 is safe baseline |
| DB install method | Ansible + oradba scripts | Replaces cloud-init; reusable |
| Patch method | AutoUpgrade out-of-place | No manual patch download; new ORACLE_HOME per RU |
| Base version | Configurable (default: latest base that supports autoupgrade to target) | 19.3.0 is too old to start with; parametrize base_ru + target_ru |
| Storage CPU tests | Root volume only | No persistent data; throw-away |
| Storage Engineering | Root + optional extra volume | Separate use case, optional flag |
| Access | SSH keypair per env (lifecycle = lab) + Cloud Shell | Public key in Terraform; no hardcoded keys |
| Secrets | 1Password (`op read`) with `.env` fallback | Portability: `op` optional, `.env` for others |
| Count | `lab_count` variable, default=1 | Workshops: `lab_count=4` |
| Accenture OCI standards | Enforced in network module + compute | See constraints below |
| VCN scope | One VCN per env | Build, use, destroy |
| Tenant | trivadisbdsxsp | Stefan's lab tenant |

## Accenture OCI Security Standards (mandatory)

Every resource MUST comply - violations trigger security monitoring alerts:

```hcl
# Compute instance
is_pv_encryption_in_transit_enabled = true
are_legacy_imds_endpoints_disabled  = true   # IMDS v2 only

# VCN
# Flow logging enabled on all subnets (already in network module - verify)
```

Verify these are already enforced in `modules/network/` before creating the
new env. If not, add them there (not just in the new env).

## Parametrization Approach

### `.env` file per env (gitignored)

```bash
# terraform/envs/cpu-patch-test/.env
export TF_VAR_compartment_ocid="ocid1.compartment..."
export TF_VAR_region_key="chzh"
export TF_VAR_lab_count=1
export TF_VAR_db_base_ru="19.22"        # April 2026 RU
export TF_VAR_db_target_ru="19.28"      # July 2026 RU (current CPU)
export TF_VAR_db_oracle_home_base="/u01/app/oracle/product/19.22/dbhome_1"
export TF_VAR_db_oracle_home_target="/u01/app/oracle/product/19.28/dbhome_1"
# Secrets via 1Password (preferred):
# export TF_VAR_ssh_public_key=$(op read "op://Lab/cpu-lab-ssh/public_key")
# Or plain text fallback:
# export TF_VAR_ssh_public_key="ssh-rsa AAAA..."
```

### SSH Keypair

- Generate one keypair per env lifecycle: `ssh-keygen -t ed25519 -f .ssh/cpu-lab`
- Public key -> Terraform variable `ssh_public_key`
- Private key -> local only, gitignored
- Add `.ssh/` to `.gitignore` in the env folder

### Secrets precedence

1. `op read "op://..."` (Stefan's setup)
2. `.env` file (others without 1Password)
3. Document both in README

## Gates and Done Criteria

Work gate by gate. Present output and ask for go/no-go before next gate.

---

### Gate 1: Terraform - VCN + Compute (OL8)

**Scope**: `terraform/envs/cpu-patch-test/`

Files to create:
- `provider.tf` - OCI provider, use ACE profile pattern from `ad-cmu-test`
- `variables.tf` - all inputs (see parametrization above)
- `main.tf` - assemble: naming + network + compute module(s)
- `outputs.tf` - instance IPs, SSH command
- `terraform.tfvars.example` - documented example, no real values
- `.gitignore` - ignore `.env`, `.ssh/`, `*.tfstate*`, `.terraform/`
- `README.md` - quick start, variable reference

New module to create: `terraform/modules/oracle_db_host/`
- OL8 compute instance
- Shape variable (default: `VM.Standard.E4.Flex`, 2 OCPU, 16GB for CPU tests)
- `is_pv_encryption_in_transit_enabled = true`
- `are_legacy_imds_endpoints_disabled = true`
- SSH keypair input (public key variable)
- Cloud-init: minimal (hostname, opc user, oradba clone from GitHub)
- Count support: `for_each` over a `lab_count`-sized set
- Optional extra block volume (flag `attach_data_volume`, default false)

**Done when**: `terraform plan` shows correct resources; dry-run documented.
Do NOT apply yet - present plan output for review.

---

### Gate 2: Ansible - Oracle 19c Install via oradba

**Scope**: `ansible/roles/db19_engineering/` + new role `oracle_db_install/`

Context on oradba:
- Clone `https://github.com/oehrlis/oradba` to `/opt/oradba` on the host
- oradba provides: environment config, aliases, helper scripts for Oracle DBs
- DB software install: use oradba scripts OR Oracle response file method
- Do NOT use the old `oradba_init` scripts directly; they are reference only

Tasks:
1. Flesh out `roles/db19_engineering/` with:
   - OS prerequisites (kernel params, limits, packages for OL8)
   - oradba installation from GitHub
   - Oracle user/groups (oracle/oinstall/dba/oper)
   - Directory structure: `/u01/app/oracle`, `/u01/app/oraInventory`
   - Oracle DB software install (19c base via response file or oradba method)
   - Listener config
2. Create playbook `playbooks/lab-cpu-patch.yml`:
   - Targets: `cpu_patch_hosts` inventory group
   - Roles: `common`, `base_ssh`, `db19_engineering`
   - Tags: `install`, `patch`, `verify`, `teardown`
3. Inventory template: `ansible/inventories/cpu-patch-test/hosts.yml.example`
   - Populate from Terraform outputs (document how)

**Done when**: Playbook runs `--tags install` on a fresh OL8 host and
`sqlplus / as sysdba` responds with the DB version. Show sample output.

---

### Gate 3: AutoUpgrade - Base RU to Target RU (out-of-place)

**Scope**: `ansible/roles/db19_engineering/` (patch tasks) + config

AutoUpgrade approach:
- AutoUpgrade downloads patches from Oracle (no manual MOS download needed)
- Run out-of-place: new `ORACLE_HOME` per target RU
- Config file generated from template (Jinja2 in Ansible)
- Parameters driven by `db_base_ru` and `db_target_ru` variables
- Key autoupgrade config options:
  ```
  global.autoupg_log_dir=/u01/app/oracle/cfgtoollogs/autoupgrade
  upg1.source_home={{ db_oracle_home_base }}
  upg1.target_home={{ db_oracle_home_target }}
  upg1.sid={{ oracle_sid }}
  upg1.mode=upgrade          # or 'patch' for same-version RU patching
  upg1.upgrade_node=localhost
  ```
- After patch: verify new home active, old home can remain for rollback testing

Add Makefile target in `cpu-patch-tests` for documentation (not code):
- Document: "to run lab, source `.env` then `ansible-playbook ... --tags patch`"

**Done when**: AutoUpgrade completes on the lab instance, new ORACLE_HOME
active, `SELECT version_full FROM v$instance` shows target RU. Show output.

---

### Gate 4: Workflow - Build / Patch / Verify / Destroy

**Scope**: `Makefile` in `oci-labs/` + runbook doc

Makefile targets (add to existing or create if absent):

```makefile
# CPU Patch Lab targets
cpu-lab-init:    ## Init terraform for cpu-patch-test env
cpu-lab-plan:    ## Plan cpu-patch-test (dry-run, no apply)
cpu-lab-apply:   ## Build cpu-patch-test lab (terraform apply + ansible install)
cpu-lab-patch:   ## Run AutoUpgrade patch (ansible --tags patch)
cpu-lab-verify:  ## Run post-patch verification (ansible --tags verify)
cpu-lab-destroy: ## Tear down cpu-patch-test (terraform destroy)
cpu-lab-cycle:   ## Full cycle: apply → patch → verify → destroy
```

Each target sources `.env` if present, otherwise expects TF_VARs set.

Runbook: `docs/runbook-cpu-patch-lab.md`
- Prerequisites (OCI CLI, Terraform, Ansible, op or .env)
- Step-by-step for a CPU quarter cycle
- Variable reference table
- Troubleshooting section

**Done when**: `make cpu-lab-plan` runs cleanly; runbook is accurate.

---

### Gate 5: Count + Documentation

**Scope**: `lab_count` wiring + README + quick-reference

- Verify `lab_count` works: `terraform plan -var="lab_count=2"` shows 2 instances
- Ansible inventory auto-generation or note for manual adjustment
- `README.md` at repo root updated with cpu-patch-test env entry
- `terraform/envs/cpu-patch-test/README.md`: full variable reference,
  secrets handling (op vs .env), example commands
- Quick-reference card: one-pager with all commands for a CPU test cycle

**Done when**: README and quick-ref are accurate and complete.

---

### Gate 6+ (future, do not implement now)

- Docker variant: stub `docker/cpu-patch-test/` with `README.md` placeholder
- OCI Resource Manager Stack: package env as `.zip` for OCI console deployment
- 26ai golden image: separate env `envs/cpu-patch-26ai/` - different flow

---

## Non-Goals (do not touch)

- `cpu-patch-tests/` source code - read for reference, do not modify
- `tvd-cpureport/` - read for reference, do not modify
- Global Ansible roles that other envs depend on (only extend, don't break)
- Existing `ad-cmu-test` and `mfa_oma_setup` envs

## Style and Standards

- All Terraform files: OraDBA file header (see existing files for pattern)
- All shell scripts: `set -euo pipefail` + OraDBA header (`/bash-header` skill)
- Ansible tasks: FQCN module names (e.g. `ansible.builtin.package`)
- Naming convention: follow `modules/naming/` output (`vcn-chzh-l-cpu-net-01`)
- Secrets: never hardcoded; `op read` or `.env` file; `.env` always gitignored
- `op` commands: single line only (no backslash continuation)
- Commits: Conventional Commits `type(scope): description`

## Session Startup

Open the session in the oci-labs repo:

```bash
cd ~/Repos/own/oehrlis/oci-labs
claude
# then: "arbeite tasks/plan-cpu-lab.md ab, starte mit Gate 1"
```

Read these files first (before writing any code):
1. `terraform/envs/ad-cmu-test/` (all files - env pattern reference)
2. `terraform/modules/network/main.tf` (network module, check Accenture standards)
3. `terraform/modules/naming/` (naming convention)
4. `ansible/roles/db19_engineering/` (current state)
5. `ansible/roles/common/tasks/main.yml` (common role pattern)
6. `~/Repos/own/oehrlis/cpu-patch-tests/scripts/au_*.sh` (AutoUpgrade scripts)
