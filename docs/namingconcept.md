# OCI Resource Naming Concept - OraDBA Labs

This document defines the consistent and scalable naming scheme for all resources in the OraDBA Lab framework.
The schema is optimized for repeatable, isolated, and automatically deployable lab environments and works for both single labs and workshop scenarios with multiple identical lab instances (via Terraform `count`).

## Goals of the Naming Concept

- Provide consistent and unambiguous names for all OCI resources
- Enable easy filtering, search, and cleanup in OCI (UI, CLI, API)
- Support fully automated lab deployments (Terraform, Resource Manager, CI/CD)
- Make region, environment, lab type, component, and instance visible in the name
- Ensure modularity and reusability across different lab scenarios

## General Structure

The resource name follows this pattern:

```text
{resource}-{region}-{env}-{stack}-{component}-{instance}
```

Optionally, an additional field can be inserted:

```text
{resource}-{region}-{env}-{stack}-{component}-{additional}-{instance}
```

### Field Definitions

| Field        | Description                                                                     |
| ------------ | ------------------------------------------------------------------------------- |
| `resource`   | Abbreviation for the resource type (e.g. `ci`, `vcn`, `sn`, `bv`)               |
| `region`     | Official OCI region key, e.g. `chzh`, `eu-frn`, `uk-lon`                        |
| `env`        | Environment code: `l` (lab), `ws` (workshop), `d` (dev), `t` (test), `p` (prod) |
| `stack`      | Lab or project type, e.g. `odb19eng`, `odb21eng`, `odb26ai`, `odbaud`, `odbwls` |
| `component`  | Function or role within the stack, e.g. `gw`, `db`, `pri`, `stb`, `oud`         |
| `additional` | Optional qualifier, e.g. `sec`, `ro`, `ha`, `demo`                              |
| `instance`   | Running number, two digits: `01`, `02`, `03`, …                                 |

## Resource Codes

These short codes are used as the leading part of each resource name:

| Resource               | Code  |
| ---------------------- | ----- |
| Compute Instance       | `ci`  |
| Block Volume           | `bv`  |
| VCN                    | `vcn` |
| Subnet                 | `sn`  |
| Route Table            | `rtb` |
| Internet Gateway       | `igw` |
| NAT Gateway            | `ngw` |
| Network Security Group | `nsg` |
| Load Balancer          | `lb`  |
| Object Storage Bucket  | `bkt` |
| Autonomous Database    | `adb` |

## Component Codes

Component codes distinguish roles within a given lab or stack:

| Component               | Code  |
| ----------------------- | ----- |
| Jumphost / Gateway      | `gw`  |
| DB Host                 | `db`  |
| Primary DB Host         | `pri` |
| Standby DB Host         | `stb` |
| OUD Host                | `oud` |
| WebLogic Server         | `wls` |
| Monitoring / Tools      | `mon` |
| WireGuard (if separate) | `wg`  |

## Environment Codes

Standardized codes for different environments:

| Environment | Code |
| ----------- | ---- |
| Lab         | `l`  |
| Workshop    | `ws` |
| Development | `d`  |
| Test        | `t`  |
| Production  | `p`  |

## Stack Codes (Lab / Project Types)

Stack codes identify the lab or project type. They use a consistent prefix for OraDBA-related projects:

| Lab Type                   | Stack Code |
| -------------------------- | ---------- |
| Oracle DB 19c Engineering  | `odb19eng` |
| Oracle DB 21c Engineering  | `odb21eng` |
| Oracle DB 26ai Engineering | `odb26ai`  |
| Oracle DB Security Labs    | `odbsec`   |
| Oracle OUD Engineering     | `odbaud`   |
| Oracle WLS Engineering     | `odbwls`   |
| Autonomous Database Labs   | `odbadb`   |

## Name Examples

### Network Resources

```text
vcn-chzh-l-odb19eng-net-01
sn-chzh-l-odb19eng-public-01
sn-chzh-l-odb19eng-private-01
rtb-chzh-l-odb19eng-core-01
nsg-chzh-l-odb19eng-gw-01
```

### Jumphost / Gateway

```text
ci-chzh-l-odb19eng-gw-01
bv-chzh-l-odb19eng-gw-01
```

### DB Hosts

Primary:

```text
ci-chzh-l-odb19eng-pri-01
```

Standby:

```text
ci-chzh-l-odb19eng-stb-01
```

Single engineering DB host:

```text
ci-chzh-l-odb19eng-db-01
```

### OUD & WLS

```text
ci-chzh-l-odbaud-oud-01
ci-chzh-l-odbwls-wls-01
```

### Autonomous Database

```text
adb-chzh-l-odbadb-core-01
```

## Tagging Recommendations

In addition to the resource name, tags should be used for lifecycle management and governance.

### Freeform Tags

Example:

```text
project = "oradba-labs"
stack   = "<stack>"
env     = "<env>"
index   = "<instance>"
region  = "<region>"
```

### Defined Tags

If defined tags are available in the tenancy, the same keys and values should be used there as well.
Tags allow easy filtering, inventory, cost allocation, and cleanup across multiple labs and environments.

## Terraform Integration (Example Snippet)

The following `locals` block can be reused in each lab stack to build consistent names:

```hcl
locals {
  instance_padded = format("%02d", var.instance)

  name = "${var.resource}-${var.region}-${var.env}-${var.stack}-${var.component}-${local.instance_padded}"
}
```

Usage example:

```hcl
resource "oci_core_instance" "jumphost" {
  display_name = local.name
  # ...
}
```

You can extend this pattern with an optional `additional` field if needed:

```hcl
locals {
  instance_padded = format("%02d", var.instance)

  # optional additional field, empty by default
  additional_part = var.additional != "" ? "-${var.additional}" : ""

  name = "${var.resource}-${var.region}-${var.env}-${var.stack}-${var.component}${local.additional_part}-${local.instance_padded}"
}
```

## 10. References

- Oracle Cloud Resource Naming Guidelines
  [https://docs.oracle.com/en/cloud/foundation/cloud_architecture/governance/naming.html#subnet-resources---naming-convention](https://docs.oracle.com/en/cloud/foundation/cloud_architecture/governance/naming.html#subnet-resources---naming-convention)

- OCI Resource Naming Conventions (example)
  [https://www.martinberger.com/2021/11/oracle-cloud-infrastructure-resource-naming-conventions-a-short-friday-blog-post/](https://www.martinberger.com/2021/11/oracle-cloud-infrastructure-resource-naming-conventions-a-short-friday-blog-post/)

- Azure Resource Naming Recommendations
  [https://www.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming](https://www.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)

- AWS VPC Naming Conventions
  [https://www.trendmicro.com/cloudoneconformity/knowledge-base/aws/VPC/vpc-naming-conventions.html](https://www.trendmicro.com/cloudoneconformity/knowledge-base/aws/VPC/vpc-naming-conventions.html)
