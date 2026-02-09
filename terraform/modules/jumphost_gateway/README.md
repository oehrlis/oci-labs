# Jumphost/Gateway module

Creates a hardened jumphost instance for lab access. Uses `lab_name_core` for naming and accepts SSH/WireGuard settings via variables. Cloud-init provisions SSH hardening, firewall rules, and fail2ban; WireGuard packages are optionally installed for later configuration.

## Inputs
- `compartment_ocid` (string): Compartment OCID for the jumphost.
- `availability_domain` (string): AD where the instance will be placed.
- `subnet_id` (string): Target subnet OCID (typically public).
- `lab_name_core` (string): Core lab name segment for display names.
- `freeform_tags` (map(string)): Base freeform tags applied to resources. Default: `{}`.
- `shape` (string): Compute shape, e.g. `VM.Standard.A1.Flex`. Default: `VM.Standard.A1.Flex`.
- `ocpus` (number): OCPUs. Default: `1`.
- `memory_gbs` (number): Memory in GB. Default: `16`.
- `assign_public_ip` (bool): Assign public IP. Default: `true`.
- `ssh_authorized_keys` (string): SSH public key(s) for `opc`.
- `ssh_port` (number): SSH port. Default: `16022`.
- `enable_wireguard` (bool): Install WireGuard packages via cloud-init. Default: `true`.
- `instance_image_ocid` (string): Image OCID (e.g. Oracle Linux 9).
- `boot_volume_size_gbs` (number): Boot volume size. Default: `20`.

## Outputs
- `instance_id`: OCID of the jumphost instance.
- `public_ip`: Public IP address (if assigned).
- `private_ip`: Private IP address.

## Usage
```hcl
module "jumphost_gateway" {
  source               = "../jumphost_gateway"
  compartment_ocid     = var.compartment_ocid
  availability_domain  = var.availability_domain
  subnet_id            = module.network.public_subnet_id
  lab_name_core        = module.naming.lab_name_core
  freeform_tags        = module.naming.base_freeform_tags
  ssh_authorized_keys  = file("~/.ssh/id_rsa.pub")
  ssh_port             = 16022
  enable_wireguard     = true
  instance_image_ocid  = var.ol9_image_ocid
}
```

## Notes
- Cloud-init template at `templates/jumphost-cloudinit.yaml.tftpl` handles SSH hardening and firewall setup; WireGuard configuration is a placeholder for later automation.
- Hostname label defaults to `gw01`; adjust in `main.tf` if needed.
- Keep `assign_public_ip = true` for public access; set to false for private-only jump hosts.
