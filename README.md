# oci-labs

Disposable Oracle lab environments on Oracle Cloud Infrastructure (OCI): Terraform
modules and lab stacks, Ansible roles for the Oracle software, and a Makefile that
drives the lifecycle (plan, apply, install, patch, verify, destroy).

Labs, not production: every stack is meant to be built, used and torn down again.
No customer data, no long-lived access.

## Layout

- `terraform/modules/` - generic building blocks (network, naming, database host, Windows AD, IAM MFA)
- `terraform/envs/` - lab stacks composed from the modules (`core`, `cpu-patch-test`, `ad-cmu-test`, `mfa_oma_setup`)
- `ansible/` - roles and playbooks that install and configure the lab hosts
- `docs/` - architecture, naming concept and per-lab runbooks
- `tools/` - helper scripts and the git hooks

## Start here

- [Architecture overview](docs/architecture-overview.md)
- [Naming concept](docs/namingconcept.md)
- Runbooks: [CPU patch lab](docs/runbook-cpu-patch-lab.md),
  [AD / CMU lab](docs/runbook-ad-cmu-lab.md), [MFA with OMA](docs/runbook-mfa-oma.md)
- `make help` lists all targets; `make lint` runs every check

## Secrets

Nothing secret belongs in this repository. Credentials come from 1Password at run
time (`op read`), Terraform state, `terraform.tfvars`, `.env` and SSH keys stay local
and gitignored. `make hooks` installs a gitleaks pre-commit hook, and CI scans the full
history on every push. See [SECURITY.md](SECURITY.md) for reporting an issue.

## License

[Apache License 2.0](LICENSE) - Copyright 2026 Stefan Oehrli
