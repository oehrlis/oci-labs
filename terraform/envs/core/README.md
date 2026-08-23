# core - shared, long-lived lab resources

One network, one artifact bucket, one Bastion, in their own Terraform state.
Everything a lab needs but should not own.

## Why this exists

Two problems with one answer.

Several labs need the same network. Building it per environment means whichever
one applies first owns it, and its `terraform destroy` takes the others down
with it.

A tenancy switch - the ACE tenancy, a customer tenancy for a workshop - should
not require deploying a hundred resources first. It should be a profile, a
`.env` and one apply.

## The ownership rule

Deploying this stack is optional. A lab environment can instantiate
`modules/core` directly when no core is found. What makes that safe is not the
code but the tag:

1. A lookup finds a core: **consume it, never destroy it.**
2. A lookup finds nothing: **build it in the caller's own state and own it.**
3. Resources from this stack carry `core_owner = "core"`. No lab environment
   destroys a resource tagged that way.
4. A lab consuming a core owned by *another lab* is warned at plan time. That is
   a real orphan risk and it should be visible, not silently prevented.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # then edit
terraform init
terraform plan
terraform apply
```

## Switching tenancy

```bash
# 1. a profile in ~/.oci/config
# 2. compartment_ocid or compartment_name in terraform.tfvars
# 3. one apply
terraform apply -var oci_config_profile=ACE -var compartment_name=cmp-labs
```

The only thing that does not travel is the bucket content. A gold image is
rebuilt in about 20 minutes, which is cheaper than any replication mechanism -
see `docs/runbook-cpu-patch-lab.md`.

## Status

Written 2026-08-23, validated with `terraform validate`, **not yet applied**.
The running `cpu-patch-test` stack still builds and owns its own network; it was
deliberately left untouched while a database it needs is live on it. Migrating
it is the remaining part of milestone M2 in `tasks/roadmap-cpu-lab.md`.
