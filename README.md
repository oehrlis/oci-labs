# oci-labs

Disposable Oracle lab environments on Oracle Cloud Infrastructure (OCI): Terraform
modules and lab stacks, Ansible roles for the Oracle software, and a Makefile that
drives the lifecycle (plan, apply, install, patch, verify, destroy).

Labs, not production: every stack is meant to be built, used and torn down again.
No customer data, no long-lived access.

## Role in the lab architecture

Terraform building blocks for Oracle Cloud Infrastructure (OCI): network, hosts and targets per tenant.
From milestone M5 it is the OCI target of `make up LAB=<name> TARGET=oci` in
[oradba-labs](https://github.com/oehrlis/oradba-labs): first a container host, then a DB VM configured with
[oradba-ansible](https://github.com/oehrlis/oradba-ansible).

- Is: infrastructure only - VCN, subnets, compute, Bastion, per-tenant targets.
- Is not: lab content. Labs and demos live in oradba-labs; images in oradba-docker (planned).
- Moving out (M4): `ansible/roles` go to oradba-ansible, the CPU lab environments to the patch test catalogue.
- Neighbours: oradba-labs (caller), oradba-ansible (VM configuration), odb_autoupgrade (Oracle Homes),
  oradba (runtime). Binaries come from the orarepo OCI bucket, not from a repo.

See the [lab architecture overview](https://github.com/oehrlis/oradba-labs/blob/main/docs/architecture.md).

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
  [oradba.automation lab test](docs/runbook-oradba-automation-lab.md),
  [AD / CMU lab](docs/runbook-ad-cmu-lab.md), [MFA with OMA](docs/runbook-mfa-oma.md)
- `make help` lists all targets; `make lint` runs every check

## Secrets

Nothing secret belongs in this repository. Credentials come from 1Password at run
time (`op read`), Terraform state, `terraform.tfvars`, `.env` and SSH keys stay local
and gitignored. `make hooks` installs a gitleaks pre-commit hook, and CI scans the full
history on every push. See [SECURITY.md](SECURITY.md) for reporting an issue.

## License

[Apache License 2.0](LICENSE) - Copyright 2026 Stefan Oehrli
