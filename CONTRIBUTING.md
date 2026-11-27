# Contributing to oci-labs

oci-labs is a one-person lab repository: Terraform building blocks and lab stacks for disposable Oracle lab
environments on OCI. Issues and pull requests are welcome, but the scope stays narrow - infrastructure only, lab
content belongs to [oradba-labs](https://github.com/oehrlis/oradba-labs).

## Before a pull request

- Branch from `main` as `type/short-description` (`fix/...`, `feat/...`, `docs/...`)
- Commit messages follow Conventional Commits: `type(scope): description`
- `make lint` is green - the same checks run in CI, without OCI credentials
- `CHANGELOG.md` has an entry under `[Unreleased]`

## Rules that are not negotiable

- Public repository: no customer data, hostnames, IP addresses, OCIDs or tenancy names - examples use placeholders
- No secret in a file, a variable default or an argv: secrets come from 1Password (`op read`) at run time and reach
  tools through 0600 files or stdin
- Ingress is opt-in: no `0.0.0.0/0` default in a module; access goes through the OCI Bastion service
- Every lab can be torn down with one make target, and nothing outside its own compartment depends on it

## Security findings

Do not open a public issue for a vulnerability. Contact the maintainer through the address in the Makefile header.
