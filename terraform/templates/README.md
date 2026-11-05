# Terraform templates

Starting points for a lab on the building-block pattern: a **core layer** per target (VCN,
subnets, gateways, Bastion - long-lived, free) and one **host layer** per host group on top
of it (built for a test, destroyed afterwards). Copy a template into the consumer repo and
replace the relative module sources with a pinned git reference:

```hcl
source = "git::https://github.com/oehrlis/oci-labs.git//terraform/modules/compute_host?ref=vX.Y.Z"
```

| Template | Layer | State key |
| --- | --- | --- |
| `core/` | VCN, subnets (.10 public, .20 private, .30 DB), IGW, NAT, flow logs, Bastion | `<target>/core/terraform.tfstate` |
| `host-on-core/` | N hosts of one component on a core subnet, NSG, optional lab keypair | `<target>/hosts-<component>/terraform.tfstate` |

## State

Both layers keep their state in the target's own bucket with the native `oci` backend - the
API key profile of `~/.oci/config` is enough, no S3 customer secret key. One bucket per target
(private; versioning suspended - no lock-version noise, labs are short-lived), one key per layer:

```bash
cp backend.hcl.example backend.hcl # git-ignored, fill bucket/namespace/key/profile
cp terraform.tfvars.example terraform.tfvars # git-ignored
make preflight DIR=<layer dir> # read-only: tenancy, compartment, bucket, core, image, shape
terraform init -backend-config=backend.hcl
terraform plan
```

`make preflight` (`tools/lab_preflight.sh`) checks everything the layer needs from its target
before anything is built - also when the same files are pointed at another tenancy (ACE instead
of Trivadis). Each `FAIL` line names the command that fixes it; checks that depend on a failed
one print `SKIP` with the reason. Exit 0 = ready, 1 = not ready.

Locking is a conditional create of `<key>.lock`. A second run while the lock is held fails at
once with `Error acquiring the state lock` and HTTP 412 `IfNoneMatchFailed` - someone else is
running, not a permission problem. With versioning enabled, every run - `plan`
included - leaves versions of the `.lock` object behind; suspended versioning avoids that.

With `generate_lab_keypair = true` the host layer's state contains the private key of the lab
pair. The state bucket must stay private and limited to the lab operators.

## Rules

- The media bucket (`orarepo`) is never part of a state: the core template sets
  `manage_artifact_bucket = false`. A destroy of a layer can never reach it
- Names follow the OCI naming rule (`naming` module, `name_scheme = "oci"`):
  `vcn-zrh-lab-cpu-net-01`, `ci-zrh-lab-cpu-db-01`
- `hostname_prefix` must be unique per subnet across all host layers of a target
- The host layer reads the core through `terraform_remote_state` and never manages it
