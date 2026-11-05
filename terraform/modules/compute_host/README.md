# compute_host module

Provisions *N* identical compute hosts on an existing subnet, each with its own
DNS label, an instance NSG shared by the hosts and an optional data volume per host.
Product-neutral: product modules such as [`oracle_db_host`](../oracle_db_host/README.md)
set the component name, role tags, cloud-init and extra ingress rules.

## Accenture OCI security standards

Enforced unconditionally, not configurable:

- `is_pv_encryption_in_transit_enabled = true` on instances and volume attachments
- `are_legacy_imds_endpoints_disabled = true` (IMDSv2 only)
- External SSH is opt-in - the NSG allows SSH from the VCN CIDR only by default

## Inputs

<!-- markdownlint-disable MD013 -->

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `compartment_ocid` | string | - | Compartment OCID. |
| `vcn_id` | string | - | VCN OCID (for the instance NSG). |
| `vcn_cidr` | string | - | VCN CIDR, intra-VCN NSG source and default rule source. |
| `subnet_id` | string | - | Subnet OCID for the hosts. |
| `availability_domain` | string | - | Availability domain name. |
| `lab_name_core` | string | - | Core name segment from the `naming` module. |
| `freeform_tags` | map(string) | `{}` | Base freeform tags. |
| `component` | string | `host` | Name segment: `ci-<lab_name_core>-<component>-01`. |
| `role_tag` | string | `compute-host` | Tag `role` on the instances. |
| `data_role_tag` | string | `compute-host-data` | Tag `role` on the data volumes. |
| `hostname_prefix` | string | `host` | DNS label prefix, the host key is appended (`host01`). |
| `host_count` | number | `1` | Number of identical hosts (1-20). |
| `instance_image_ocid` | string | - | Image OCID, resolved by the caller. |
| `shape` | string | `VM.Standard.E4.Flex` | Flex shape. |
| `ocpus` | number | `2` | OCPUs per host. |
| `memory_gbs` | number | `16` | Memory in GB per host. |
| `boot_volume_size_gbs` | number | `200` | Boot volume size in GB (min 50). |
| `assign_public_ip` | bool | `false` | Public IP per host (public subnet only). |
| `attach_data_volume` | bool | `false` | Extra block volume per host. |
| `data_volume_size_gbs` | number | `100` | Data volume size in GB. |
| `data_volume_vpus_per_gb` | number | `10` | Block volume performance (VPUs/GB). |
| `ssh_public_keys` | list(string) | - | SSH public keys for `opc` (at least one). |
| `user_data_template` | string | `""` | cloud-init template path, rendered per host. |
| `user_data_vars` | map(string) | `{}` | Template variables; `hostname` is added per host. |
| `ingress_rules` | map(object) | `{}` | Extra ingress rules, see below. |
| `allowed_ssh_cidrs` | list(string) | `[]` | External CIDRs allowed to reach SSH. |
| `ssh_port` | number | `22` | SSH port. |
| `egress_https_only` | bool | `false` | Egress limited to TCP 443 plus intra-VCN. |

<!-- markdownlint-restore -->

### ingress_rules

The map key is the Terraform address of the rule - keep it stable, renaming it recreates
the rule. `protocol` is `tcp`, `udp`, `icmp` or `all`; `source` defaults to the VCN CIDR;
`port_max` defaults to `port_min`.

```hcl
ingress_rules = {
  listener = { protocol = "tcp", port_min = 1521, description = "Oracle Net listener (intra-VCN)" }
  wls_admin = { protocol = "tcp", port_min = 7001, port_max = 7002, description = "WebLogic admin" }
  icmp = { protocol = "icmp", description = "ICMP inside the VCN" }
}
```

## Outputs

All host maps are keyed by the zero-padded host index (`01`, `02`, ...): `instance_ids`,
`instance_names`, `private_ips`, `public_ips`, `hostnames`, `data_volume_ids`; plus `nsg_id`.

## Notes

- `lifecycle.ignore_changes` on the image OCID and `ssh_authorized_keys`: a newer image
  build or a changed workstation key never replaces a running host. Replace on purpose:
  `terraform apply -replace='module.<m>.oci_core_instance.this["01"]'`
- cloud-init runs on the first boot only - a changed template does not reach a running host
