# DB19 Engineering module

Provisions one or more Oracle DB19 engineering hosts with cloud-init hardening. Uses `lab_name_core` for naming and supports DB listener/OEM firewall openings.

## Inputs
- `compartment_ocid` (string): Compartment OCID for the DB hosts.
- `availability_domain` (string): AD for the instances.
- `subnet_id` (string): Target subnet OCID (typically DB subnet).
- `lab_name_core` (string): Core lab name segment used for display names.
- `freeform_tags` (map(string)): Base freeform tags. Default: `{}`.
- `shape` (string): Compute shape. Default: `VM.Standard.E4.Flex`.
- `ocpus` (number): OCPUs per host. Default: `2`.
- `memory_gbs` (number): Memory per host. Default: `16`.
- `assign_public_ip` (bool): Assign public IP. Default: `false`.
- `instance_image_ocid` (string): Image OCID (OL8/OL9).
- `boot_volume_size_gbs` (number): Boot volume size. Default: `100`.
- `db_host_count` (number): Number of DB hosts. Default: `1`.
- `hostname_prefix` (string): Hostname label prefix. Default: `db19`.
- `ssh_authorized_keys` (string): SSH public key(s) for `opc`.
- `ssh_port` (number): SSH port. Default: `22`.
- `open_db_ports` (bool): Open DB listener/OEM in firewalld. Default: `true`.
- `db_listener_port` (number): Listener port. Default: `1521`.
- `db_oem_port` (number): OEM/EM Express port. Default: `5500`.

## Outputs
- `instance_ids`: OCIDs of the DB hosts.
- `private_ips`: Private IPs of the DB hosts.
- `hostnames`: Display names of the DB hosts.
- `hostname_labels`: DNS hostname labels.

## Usage
```hcl
module "db19_engineering" {
  source               = "../db19_engineering"
  compartment_ocid     = var.compartment_ocid
  availability_domain  = var.availability_domain
  subnet_id            = module.network.db_subnet_id
  lab_name_core        = module.naming.lab_name_core
  freeform_tags        = module.naming.base_freeform_tags
  db_host_count        = 2
  hostname_prefix      = "db19"
  ssh_authorized_keys  = file("~/.ssh/id_rsa.pub")
  instance_image_ocid  = var.ol9_image_ocid
}
```

## Notes
- Cloud-init template `templates/db19-cloudinit.yaml.tftpl` prepares users, directories, kernel params, firewall rules, and placeholders for DB installation via Ansible.
- Hostname labels use `hostname_prefix` plus a two-digit index (e.g., `db19-01`).
- Keep `assign_public_ip` disabled on DB subnets unless explicitly required.
