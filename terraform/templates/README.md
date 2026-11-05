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
(versioned, private), one key per layer:

```bash
cp backend.hcl.example backend.hcl            # git-ignored, fill bucket/namespace/key/profile
cp terraform.tfvars.example terraform.tfvars  # git-ignored
terraform init -backend-config=backend.hcl
terraform plan
```

Locking is a conditional create of `<key>.lock`. A second run while the lock is held fails at
once with `Error acquiring the state lock` and HTTP 412 `IfNoneMatchFailed` - someone else is
running, not a permission problem. Every run, `plan` included, leaves versions of the `.lock`
object in a versioned bucket.

With `generate_lab_keypair = true` the host layer's state contains the private key of the lab
pair. The state bucket must stay private and limited to the lab operators.

## Rules

- The media bucket (`orarepo`) is never part of a state: the core template sets
  `manage_artifact_bucket = false`. A destroy of a layer can never reach it
- Names follow the OCI naming rule (`naming` module, `name_scheme = "oci"`):
  `vcn-zrh-lab-cpu-net-01`, `ci-zrh-lab-cpu-db-01`
- `hostname_prefix` must be unique per subnet across all host layers of a target
- The host layer reads the core through `terraform_remote_state` and never manages it
