# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Assemble the lab-db19c-baseline stack (network, bastion, compute)
#              using reusable OCI modules.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

locals {
  lab     = yamldecode(file("${path.module}/lab.yaml"))
  db_host = local.lab.db_hosts[0]
}

# 1) Network
module "network" {
  source = "../../modules/network"

  compartment_ocid    = var.compartment_ocid
  vcn_cidr            = var.cidr_vcn
  private_subnet_cidr = var.cidr_private_subnet
  lab_name            = local.lab.lab_name
}

# 2) Bastion
module "bastion" {
  source = "../../modules/bastion_native"

  compartment_ocid = var.compartment_ocid
  target_subnet_id = module.network.private_subnet_id

  bastion_name = "db19c-baseline-bastion"
  # client_cidr_block_allow_list nutzen wir aus dem Default
}


# 3) user_data für Compute erzeugen
locals {
  db_user_data = base64encode(
    templatefile("${path.module}/cloudinit_db_host.yaml.tftpl", {
      bootstrap_url = var.bootstrap_url
      profile_type  = var.profile_type
      profile_name  = var.profile_name
    })
  )
}

# 4) Compute-Host
module "db1" {
  source = "../../modules/compute_linux"

  tenancy_ocid         = var.tenancy_ocid
  compartment_ocid     = var.compartment_ocid
  subnet_id            = module.network.private_subnet_id
  instance_name        = local.db_host.name
  shape                = local.db_host.shape
  ocpus                = local.db_host.ocpus
  memory_gbs           = local.db_host.memory_gbs
  boot_volume_size_gbs = local.db_host.boot_volume_size_gbs
  data_volume_size_gbs = local.db_host.data_volume_size_gbs
  enable_data_volume   = local.lab.enable_data_volume
  ssh_public_key       = var.ssh_public_key
  bootstrap_url        = var.bootstrap_url
  profile_type         = var.profile_type
  profile_name         = var.profile_name
  user_data            = local.db_user_data
}

# --- EOF ----------------------------------------------------------------------
