
# ---------------------------------------------------------------------------
# Naming module
# ---------------------------------------------------------------------------

module "naming" {
  source               = "../../modules/naming"
  region_key           = var.region_key
  environment_code     = var.environment_code
  stack_code           = var.stack_code
  lab_instance         = var.lab_instance
  common_freeform_tags = var.common_freeform_tags
}

# Convenience locals
locals {
  lab_name_core      = module.naming.lab_name_core
  base_freeform_tags = module.naming.base_freeform_tags
}

# ---------------------------------------------------------------------------
# Availability domain
# ---------------------------------------------------------------------------

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

locals {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

module "network" {
  source = "../../modules/network"

  compartment_ocid = var.compartment_ocid

  lab_name_core = local.lab_name_core
  freeform_tags = local.base_freeform_tags

  vcn_cidr            = var.vcn_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  db_subnet_cidr      = var.db_subnet_cidr
  app_subnet_cidr     = var.app_subnet_cidr

  internet_gateway_enabled = true
  nat_gateway_enabled      = true

  enable_flow_logs            = var.enable_flow_logs
  flow_log_retention_duration = var.flow_log_retention_duration
  allowed_ssh_cidrs           = var.allowed_ssh_cidrs
  allowed_wireguard_cidrs     = var.allowed_wireguard_cidrs
  ssh_port                    = var.ssh_port
  wireguard_port              = var.wireguard_port
  allow_public_http_https     = false
}

# ---------------------------------------------------------------------------
# Image lookup for jumphost (Oracle Linux x on matching shape)
# ---------------------------------------------------------------------------

data "oci_core_images" "jumphost_image" {
  compartment_id           = var.compartment_ocid
  operating_system         = var.bastion_os
  operating_system_version = var.bastion_os_version
  shape                    = var.jumphost_shape

  sort_by    = "TIMECREATED"
  sort_order = "DESC"
}

# ---------------------------------------------------------------------------
# Jumphost / Gateway
# ---------------------------------------------------------------------------
module "jumphost_gateway" {
  source = "../../modules/jumphost_gateway"

  compartment_ocid    = var.compartment_ocid
  availability_domain = local.availability_domain
  subnet_id           = module.network.public_subnet_id

  lab_name_core = local.lab_name_core
  freeform_tags = local.base_freeform_tags

  shape      = var.jumphost_shape
  ocpus      = var.jumphost_ocpus
  memory_gbs = var.jumphost_memory_gbs

  assign_public_ip = true

  ssh_authorized_keys = var.ssh_authorized_keys
  ssh_port            = var.ssh_port

  ansible_repo_url = "https://github.com/oehrlis/oci-labs-config.git"
  ansible_branch   = "main"
  ansible_playbook = "lab-jumphost.yml"

  enable_wireguard = var.enable_wireguard

  instance_image_ocid = data.oci_core_images.jumphost_image.images[0].id

  boot_volume_size_gbs = 50
}

# ---------------------------------------------------------------------------
# DB19 Engineering - vorerst für den Test *deaktiviert*
# ---------------------------------------------------------------------------

# module "db19_engineering" {
#   source = "../../modules/db19_engineering"
#
#   compartment_ocid    = var.compartment_ocid
#   availability_domain = local.availability_domain
#   subnet_id           = module.network.db_subnet_id
#
#   lab_name_core = local.lab_name_core
#   freeform_tags = local.base_freeform_tags
#
#   instance_image_ocid = var.db19_image_ocid
#   db_host_count       = var.db_host_count
#
#   hostname_prefix      = "db19"
#   ssh_authorized_keys  = var.ssh_authorized_keys
#   ssh_port             = 22
#   open_db_ports        = true
#   db_listener_port     = 1521
#   db_oem_port          = 5500
# }
