# oracle_db_host module

Provisions *N* identical Oracle Linux 8 compute hosts intended to run Oracle
Database software installed by Ansible (role `db19_engineering`). Used by the
`cpu-patch-test` environment for quarterly Critical Patch Update (CPU) testing
and reusable for engineering / workshop labs.

Cloud-init is deliberately minimal - it sets the hostname, installs `git`,
`python3`, `unzip`, `tmux`, and clones the
[oradba](https://github.com/oehrlis/oradba) scripts. Everything else (kernel
parameters, users, Oracle install, patching) is Ansible's job.

## Accenture OCI security standards

Enforced unconditionally, not configurable:

- `is_pv_encryption_in_transit_enabled = true` on instances and volume attachments
- `are_legacy_imds_endpoints_disabled = true` (IMDSv2 only)
- External SSH is opt-in - the NSG default allows SSH from the VCN CIDR only

Subnet flow logging is provided by the `network` module.

## Inputs

<!-- markdownlint-disable MD013 -->

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `compartment_ocid` | string | - | Compartment OCID. |
| `vcn_id` | string | - | VCN OCID (for the instance NSG). |
| `vcn_cidr` | string | - | VCN CIDR, used as intra-VCN NSG ingress source. |
| `subnet_id` | string | - | Subnet OCID for the hosts. |
| `availability_domain` | string | - | Availability domain name. |
| `lab_name_core` | string | - | Core name segment from the `naming` module. |
| `freeform_tags` | map(string) | `{}` | Base freeform tags. |
| `host_count` | number | `1` | Number of identical hosts (1-20). |
| `instance_image_ocid` | string | - | Oracle Linux 8 image OCID. |
| `shape` | string | `VM.Standard.E4.Flex` | Compute shape - must be x86. |
| `ocpus` | number | `2` | OCPUs per host. |
| `memory_gbs` | number | `16` | Memory in GB per host. |
| `boot_volume_size_gbs` | number | `200` | Boot volume size in GB (min 100). |
| `assign_public_ip` | bool | `true` | Assign a public IP per host. |
| `attach_data_volume` | bool | `false` | Attach an extra block volume per host. |
| `data_volume_size_gbs` | number | `100` | Data volume size in GB. |
| `data_volume_vpus_per_gb` | number | `10` | Block volume performance (VPUs/GB). |
| `ssh_public_key` | string | - | SSH public key for the `opc` user. |
| `allowed_ssh_cidrs` | list(string) | `[]` | External CIDRs allowed to reach SSH. |
| `ssh_port` | number | `22` | SSH port. |
| `listener_port` | number | `1521` | Oracle Net listener port (intra-VCN). |
| `oradba_repo_url` | string | `https://github.com/oehrlis/oradba.git` | oradba git URL. |
| `oradba_install_dir` | string | `/opt/oradba` | oradba clone target on the host. |

<!-- markdownlint-restore -->

## Outputs

All host maps are keyed by the zero-padded host index (`01`, `02`, ...).

<!-- markdownlint-disable MD013 -->

| Name | Description |
| --- | --- |
| `instance_ids` | Instance OCIDs. |
| `instance_names` | Instance display names. |
| `private_ips` | Private IPs. |
| `public_ips` | Public IPs (empty when `assign_public_ip = false`). |
| `hostnames` | Short hostnames (`oradb01`, ...). |
| `nsg_id` | OCID of the host NSG. |
| `data_volume_ids` | Data volume OCIDs (empty when `attach_data_volume = false`). |

<!-- markdownlint-restore -->

## Naming

Derived from `lab_name_core` (see the `naming` module):

```text
ci-chzh-l-cpupt-01-db-01    instance
nsg-chzh-l-cpupt-01-db-01   NSG
bv-chzh-l-cpupt-01-db-01-data-01   optional data volume
```

## Usage

```hcl
module "oracle_db_host" {
  source = "../../modules/oracle_db_host"

  compartment_ocid    = var.compartment_ocid
  vcn_id              = module.network.vcn_id
  vcn_cidr            = var.vcn_cidr
  subnet_id           = module.network.public_subnet_id
  availability_domain = local.availability_domain

  lab_name_core = module.naming.lab_name_core
  freeform_tags = module.naming.base_freeform_tags

  host_count          = 1
  instance_image_ocid = local.ol8_image_id
  ssh_public_key      = var.ssh_public_key
  allowed_ssh_cidrs   = ["203.0.113.10/32"]
}
```

## Notes

- Oracle Database 19c has no ARM release for this lab flow - keep an x86 shape.
- `boot_volume_size_gbs` must hold two `ORACLE_HOME`s (base RU + target RU) plus
  the install media; 200 GB is the tested default.
- `lifecycle.ignore_changes` on the image OCID prevents a running lab host from
  being replaced when Oracle publishes a newer OL8 build.
