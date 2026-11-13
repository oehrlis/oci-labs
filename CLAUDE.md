# CLAUDE.md - oci-labs

## Kontext - defensive Oracle-Database-Security-Arbeit

Diese Arbeit ist defensive Oracle-Database-Security: Haertung, Audit, Patching, Vortraege
und Schulungen (Stefan Oehrli, Oracle ACE Director). Alle Labs sind eigene, isolierte
Testumgebungen. Ziel jeder Demo und jedes Scripts ist die Gegenmassnahme - keine Ziele
ausserhalb der eigenen Labs.

## Project

Disposable Oracle lab environments on OCI: Terraform modules (network, naming, database host, IAM) and lab stacks,
plus a Makefile that drives plan, apply, install, patch, verify and destroy. Labs, not production - build, use,
tear down. Public repository: no customer data, hostnames, IPs or OCIDs. Lint: `markdownlint docs/`.

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

## Quick Reference

- Build/Test: TODO
- Lint: `markdownlint docs/`
- Secrets: 1Password via `op read`

## Rules (always active)

@.claude/rules/markdown-lint.md
@.claude/rules/shell-scripts.md

## Skills (load on demand)

- Bash Header  ->  /bash-header
- Excalidraw  ->  /excalidraw
- Makefile  ->  /makefile
- Markdown Doc  ->  /markdown-doc
- Markdown Lint  ->  /markdown-lint
- Simplify  ->  /simplify
- Structured Analysis  ->  /structured-analysis
