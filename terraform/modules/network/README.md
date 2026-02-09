# Network module

Provision an Oracle Cloud VCN with public/private/DB/App subnets, security lists, gateways, and flow logs. Resource names use `lab_name_core` from the naming module so stacks stay consistent.

## Inputs
- `compartment_ocid` (string): Compartment OCID for all network resources.
- `lab_name_core` (string): Core name segment (from naming module), e.g. `chzh-l-odb19eng-01`.
- `freeform_tags` (map(string)): Base freeform tags applied to all network resources. Default: `{}`.
- `vcn_cidr` (string): VCN CIDR. Default: `10.19.0.0/16`.
- `public_subnet_cidr` (string): Public subnet CIDR. Default: `10.19.10.0/24`.
- `private_subnet_cidr` (string): Private subnet CIDR. Default: `10.19.20.0/24`.
- `db_subnet_cidr` (string): DB subnet CIDR. Default: `10.19.30.0/24`.
- `app_subnet_cidr` (string): App subnet CIDR. Default: `10.19.40.0/24`.
- `internet_gateway_enabled` (bool): Create Internet Gateway. Default: `true`.
- `nat_gateway_enabled` (bool): Create NAT Gateway. Default: `true`.
- `enable_flow_logs` (bool): Enable VCN flow logs. Default: `true`.
- `flow_log_retention_duration` (number): Log retention in days (30, 60, 90...). Default: `90`.
- `allowed_ssh_cidrs` (list(string)): CIDRs allowed for SSH. Default: `["0.0.0.0/0"]`.
- `ssh_port` (number): SSH port for public subnet. Default: `16022`.
- `allowed_wireguard_cidrs` (list(string)): CIDRs allowed for WireGuard. Default: `["0.0.0.0/0"]`.
- `wireguard_port` (number): WireGuard UDP port. Default: `51820`.
- `allow_public_http_https` (bool): Allow inbound HTTP/HTTPS on public subnet. Default: `false`.

## Outputs
- `vcn_id`: OCID of the created VCN.
- `public_subnet_id`: OCID of the public subnet.
- `private_subnet_id`: OCID of the private subnet.
- `db_subnet_id`: OCID of the DB subnet.
- `app_subnet_id`: OCID of the App subnet.
- `log_group_id`: OCID of the network log group.

## Usage
```hcl
module "naming" {
  source           = "../naming"
  region_key       = "chzh"
  environment_code = "l"
  stack_code       = "odb19eng"
  lab_instance     = 1
}

module "network" {
  source                 = "../network"
  compartment_ocid       = var.compartment_ocid
  lab_name_core          = module.naming.lab_name_core
  freeform_tags          = module.naming.base_freeform_tags
  vcn_cidr               = "10.19.0.0/16"
  public_subnet_cidr     = "10.19.10.0/24"
  private_subnet_cidr    = "10.19.20.0/24"
  db_subnet_cidr         = "10.19.30.0/24"
  app_subnet_cidr        = "10.19.40.0/24"
  internet_gateway_enabled = true
  nat_gateway_enabled      = true
  enable_flow_logs         = true
}

resource "oci_core_instance" "jumphost" {
  display_name  = "ci-${module.naming.lab_name_core}-gw-01"
  subnet_id     = module.network.public_subnet_id
  freeform_tags = module.naming.base_freeform_tags
}
```

## Notes
- DNS labels are derived from `lab_name_core` and trimmed to 15 characters.
- Flow logs are optional; toggle via `enable_flow_logs` and adjust retention with `flow_log_retention_duration`.
- Security lists allow SSH/WireGuard (and optional HTTP/HTTPS) on the public subnet; private/DB/App subnets trust traffic inside the VCN and egress to the Internet via NAT when enabled.
