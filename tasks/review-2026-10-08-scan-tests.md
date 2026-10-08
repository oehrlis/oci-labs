# Test Inventory - oci-labs (2026-10-08)

<!-- markdownlint-disable MD013 MD032 MD037 MD060 -->

## Framework Detection Summary

| Framework | Discovery Command | Files Found |
|-----------|------------------|-------------|
| Terraform test files (*.tftest.hcl) | `find . -name "*.tftest.hcl"` | 0 |
| pytest (test_*.py, *_test.py) | `find . -name "test_*.py" -o -name "*_test.py"` | 0 (main repo; vendored ansible tests excluded) |
| Jest/Mocha (*.test.js, *.spec.js) | `find . -name "*.test.js" -o -name "*.spec.js"` | 0 |
| Bats (*.bats) | `find . -name "*.bats"` | 0 |
| Go tests (*_test.go) | `find . -name "*_test.go"` | 0 |
| Ansible molecule | `find . -name "molecule.yml"` | 0 |
| terraform validate/fmt | Makefile lint-terraform target | N/A (validation, not test files) |
| ansible-lint | Makefile lint-ansible target | N/A (linter, not test files) |
| yamllint | Makefile lint-yaml target | N/A (linter, not test files) |
| markdownlint | Makefile lint-markdown target | N/A (linter, not test files) |
| shellcheck | Makefile lint-shell target | N/A (linter, not test files) |
| gitleaks | Makefile lint-secrets + CI workflow | N/A (secret scan, not test files) |

## Validation/Lint Mechanisms (Not Traditional Test Frameworks)

### Terraform Validation

**Mechanism:** `terraform fmt -check` and `terraform validate` per environment

| Component | Path | Type | Status | Notes |
|-----------|------|------|--------|-------|
| core | terraform/envs/core | Environment | Validates | Has provider.tf |
| cpu-patch-test | terraform/envs/cpu-patch-test | Environment | Validates | Has provider.tf |
| ad-cmu-test | terraform/envs/ad-cmu-test | Environment | Validates | Has provider.tf |
| mfa_oma_setup | terraform/envs/mfa_oma_setup | Environment | Validates | Has provider.tf |
| site2site-udm | terraform/envs/site2site-udm | Environment | SKIPPED | No provider.tf - will skip validation |
| core | terraform/modules/core | Module | Validates | Has main.tf, used by envs |
| network | terraform/modules/network | Module | Validates | Has main.tf, used by envs |
| oracle_db_host | terraform/modules/oracle_db_host | Module | Validates | Has main.tf, used by envs |
| windows_ad | terraform/modules/windows_ad | Module | Validates | Has main.tf, used by envs |
| iam_mfa_oma | terraform/modules/iam_mfa_oma | Module | Validates | Has main.tf, used by envs |
| naming | terraform/modules/naming | Module | Validates | Has main.tf, used by envs |

**Run context:**
- **Local:** `make lint-terraform` (part of `make lint`)
- **CI:** Not in GitHub Actions - only gitleaks.yml runs on push/PR

### Ansible Validation

**Mechanisms:** `ansible-lint`, Ansible playbook syntax check (requires inventory)

| Component | Path | Type | Scope | Notes |
|-----------|------|------|-------|-------|
| base_ssh | ansible/roles/base_ssh | Role | Linted | Has tasks/main.yml |
| common | ansible/roles/common | Role | Linted | Has tasks/main.yml |
| common_hardening | ansible/roles/common_hardening | Role | Linted | Has tasks/main.yml |
| crowdsec | ansible/roles/crowdsec | Role | Linted | Has tasks/main.yml |
| db19_engineering | ansible/roles/db19_engineering | Role | Linted | Has tasks/main.yml; tags: install, patch, verify, goldimage_push |
| fail2ban | ansible/roles/fail2ban | Role | Linted | Has tasks/main.yml |
| firewall | ansible/roles/firewall | Role | Linted | Has tasks/main.yml |
| jumphost_base | ansible/roles/jumphost_base | Role | Linted | Has tasks/main.yml |
| windows_ad | ansible/roles/windows_ad | Role | Linted | Has tasks/main.yml |
| wireguard_gateway | ansible/roles/wireguard_gateway | Role | Linted | Has tasks/main.yml |
| lab-cpu-patch | ansible/playbooks/lab-cpu-patch.yml | Playbook | Syntax-check only (requires inventory) | Main CPU patch cycle |
| full-lab-bootstrap | ansible/playbooks/full-lab-bootstrap.yml | Playbook | Linted (part of ansible/) | |
| lab-ad-cmu | ansible/playbooks/lab-ad-cmu.yml | Playbook | Linted (part of ansible/) | |
| lab-db19eng | ansible/playbooks/lab-db19eng.yml | Playbook | Linted (part of ansible/) | |
| lab-jumphost | ansible/playbooks/lab-jumphost.yml | Playbook | Linted (part of ansible/) | |
| lab-oudeng | ansible/playbooks/lab-oudeng.yml | Playbook | Linted (part of ansible/) | |
| lab-wlseng | ansible/playbooks/lab-wlseng.yml | Playbook | Linted (part of ansible/) | |

**Run context:**
- **Local:** `make lint-ansible` (lints roles/ and playbooks/); `make lint-ansible-syntax` (requires `make cpu-lab-apply` to generate inventory)
- **CI:** Not in GitHub Actions - no ansible-lint or playbook syntax check in CI

### Shell Scripts

**Mechanism:** `shellcheck -x -S warning`

| Script | Path | Lines | Coverage |
|--------|------|-------|----------|
| validate.sh | tools/validate.sh | (checked) | Linted |
| build_all.sh | tools/build_all.sh | (checked) | Linted |
| cpu-lab-progress.sh | tools/cpu-lab-progress.sh | (checked) | Linted |
| build_stack_zip.sh | tools/build_stack_zip.sh | (checked) | Linted |
| upload_bootstrap.sh | tools/upload_bootstrap.sh | (checked) | Linted |
| clean.sh | tools/clean.sh | (checked) | Linted |
| pre-commit hook | tools/git-hooks/pre-commit | (checked) | Linted |
| infra-tools scripts | tools/infra-tools/scripts/*.sh | 509 total lines | Linted |

**Run context:**
- **Local:** `make lint-shell` scans `tools/` and `bootstrap/` directories
- **CI:** Not in GitHub Actions

### YAML and Markdown

| Linter | Target | Coverage | CI |
|--------|--------|----------|-----|
| yamllint | ansible/ (recursively) | All YAML files in Ansible | No |
| markdownlint | **/*.md (glob) | All .md files at all levels | No |

**Run context:**
- **Local:** `make lint-yaml`, `make lint-markdown` (part of `make lint`)
- **CI:** Not in GitHub Actions

### Secret Scanning

| Tool | Scope | Config | CI | Pre-commit |
|------|-------|--------|----|----|
| gitleaks | Full git history, all refs | .gitleaks.toml | Yes (GitHub Actions) | Yes (git hook) |

**Mechanism:** `gitleaks git --config .gitleaks.toml --redact --no-banner --log-opts=--all`

**Known Allowlisted Findings:**
- RA-oci-labs-001: OCI PAR URL with token in history (accepted: time-limited)
- RA-oci-labs-002: OCIDs and key fingerprint in history (accepted: identifiers, no credential)
- RA-oci-labs-003: OCIDs in AD/CMU runbook history (accepted: identifiers)

**Run context:**
- **Local:** `make lint-secrets` or via pre-commit hook `tools/git-hooks/pre-commit` (gitleaks on staged changes)
- **CI:** GitHub Actions workflow `.github/workflows/gitleaks.yml` on push/PR

### Version Check

| Target | Mechanism | Format | CI |
|--------|-----------|--------|-----|
| VERSION | Regex validation | SemVer (N.N.N) | No |

**Run context:**
- **Local:** `make check-version` (part of `make lint`)
- **CI:** Not in GitHub Actions

## Comprehensive Validation Coverage Map

| Component Type | Count | Validated | Skipped | Notes |
|---|---|---|---|---|
| Terraform environments | 5 | 4 (core, cpu-patch-test, ad-cmu-test, mfa_oma_setup) | 1 (site2site-udm: no provider.tf) | fmt + validate |
| Terraform modules | 6 | 6 (all have main.tf) | 0 | Included in `terraform validate` |
| Ansible roles | 10 | 10 | 0 | ansible-lint |
| Ansible playbooks | 7 | 7 (all in ansible/) | 0 | ansible-lint (syntax-check requires inventory) |
| Shell scripts | ~13 files in tools/ | All (509+ lines) | 0 | shellcheck |
| YAML files | All in ansible/ | All | 0 | yamllint |
| Markdown files | All .md | All | 0 | markdownlint |
| VERSION file | 1 | 1 | 0 | Regex check |

## CI Pipeline Status

**Current CI Implementation:**
- **.github/workflows/gitleaks.yml:** Secret scan on push/PR (all refs, history)
- **No additional CI workflows** for terraform validate, ansible-lint, shellcheck, or markdown/yaml linting

**Lint targets defined in Makefile:**
- `make lint` (runs all: terraform, ansible, yaml, markdown, shell, secrets, version)
- `make lint-terraform`
- `make lint-ansible`
- `make lint-ansible-syntax` (requires generated inventory from cpu-lab-apply)
- `make lint-yaml`
- `make lint-markdown`
- `make lint-shell`
- `make lint-secrets`
- `make check-version`

**Gap:** Makefile lint targets are **local-only** - no CI gate runs them on push/PR.

## Test Execution Mechanisms (Integration/Validation)

| Mechanism | Scope | Type | Run Mode | Status |
|-----------|-------|------|----------|--------|
| terraform plan | Terraform IaC | Dry-run validation | Manual: `make core-plan`, `make cpu-lab-plan` | Operational |
| terraform apply | Terraform IaC | Full deployment | Manual: `make core-apply`, `make cpu-lab-apply` | Operational |
| ansible playbook (dry-run) | Ansible roles | Syntax check | Manual: `make lint-ansible-syntax` (requires inventory) | Operational (requires cpu-lab-apply first) |
| ansible playbook (actual run) | Ansible roles | Full execution | Manual: `make cpu-lab-install`, `make cpu-lab-patch`, `make cpu-lab-verify` | Operational (creates live lab environment) |
| Bastion tunnel validation | Network connectivity | Live check | Manual: `make cpu-lab-tunnel-check` | Operational |

## Uncovered Components (No Automated Check)

| Component | Why | Risk Level |
|-----------|-----|-----------|
| site2site-udm Terraform environment | No provider.tf - validation skipped by Makefile lint-terraform logic (line 185: `continue`) | Medium - changes to this env are unvalidated |
| Terraform variable files (*.tfvars) | No linting of variable syntax or required variable presence | Low - caught at plan-time |
| Terraform outputs | No validation of output values or types | Low - caught at apply-time |
| Ansible handlers | No explicit handler validation (included in ansible-lint scope but role-specific) | Low - caught at playbook run-time |
| Bootstrap scripts | bootstrap/ directory scripts are linted (shellcheck) but not unit-tested | Low - functional testing via cpu-lab-apply |
| Runbooks (*.md) | Markdown lint only - no validation of code blocks or command syntax | Low - documentation linting only |

## Summary: Framework and Coverage

**Test Frameworks Present:** NONE (no dedicated test suite files)

**Validation Mechanisms Present:**
1. **Linting & Static Analysis:** terraform fmt/validate, ansible-lint, yamllint, markdownlint, shellcheck, gitleaks
2. **Dry-run Validation:** terraform plan
3. **Integration Testing:** Ansible playbook syntax check (requires live inventory)
4. **Live System Testing:** cpu-lab-* targets (manual deployment + verification)

**Coverage Ratio:**
- All Terraform environments (except site2site-udm): validated
- All Ansible roles: linted
- All shell scripts: linted
- All YAML: linted
- All Markdown: linted
- All git history: secret-scanned

**CI vs Local:**
- Secrets (gitleaks): CI + pre-commit hook
- All other validation: Local only (make lint targets, not run in CI)

## Blockiert Items

BLOCKIERT: terraform/envs/site2site-udm validation - why: Makefile lint-terraform skips envs without provider.tf (line 185: `continue`); fix: Add provider.tf to site2site-udm or modify Makefile to fail on missing provider.tf
