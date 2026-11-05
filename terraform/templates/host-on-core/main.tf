# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.11.05
# Version....: v0.1.0
# Purpose....: Host layer on an existing core: N hosts of one component.
# Notes......: Reads the core by remote state (backend oci), never manages it.
#              With generate_lab_keypair the private key is in this layer's
#              state - the state bucket must stay private.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Core - read only
# ------------------------------------------------------------------------------

data "terraform_remote_state" "core" {
  backend = "oci"

  config = {
    bucket              = var.core_state.bucket
    namespace           = var.core_state.namespace
    key                 = var.core_state.key
    region              = var.region
    config_file_profile = var.oci_config_profile
  }
}

locals {
  core = data.terraform_remote_state.core.outputs
  subnet_ids = {
    db      = local.core.db_subnet_id
    private = local.core.private_subnet_id
    public  = local.core.public_subnet_id
  }
}

# ------------------------------------------------------------------------------
# Placement and image
# ------------------------------------------------------------------------------

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

data "oci_core_images" "ol" {
  count = var.instance_image_ocid == null ? 1 : 0

  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = var.ol_version
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

locals {
  image_id = var.instance_image_ocid != null ? var.instance_image_ocid : data.oci_core_images.ol[0].images[0].id
}

# ------------------------------------------------------------------------------
# SSH keys - workstation keys plus an optional per-layer pair
# ------------------------------------------------------------------------------

resource "tls_private_key" "lab" {
  count     = var.generate_lab_keypair ? 1 : 0
  algorithm = "ED25519"
}

resource "local_sensitive_file" "lab_private_key" {
  count                = var.generate_lab_keypair ? 1 : 0
  filename             = "${abspath(path.root)}/.ssh/${var.component}-lab"
  content              = tls_private_key.lab[0].private_key_openssh
  file_permission      = "0600"
  directory_permission = "0700"
}

locals {
  ssh_key_files         = [for f in var.ssh_public_key_files : pathexpand(f)]
  ssh_key_files_missing = [for f in local.ssh_key_files : f if !fileexists(f)]
  ssh_public_keys = distinct(concat(
    [for f in local.ssh_key_files : trimspace(file(f)) if fileexists(f)],
    var.generate_lab_keypair ? [trimspace(tls_private_key.lab[0].public_key_openssh)] : [],
  ))
}

# A named key file that does not exist is an error, not a silent skip.
resource "terraform_data" "ssh_key_guard" {
  input = length(local.ssh_public_keys)

  lifecycle {
    precondition {
      condition     = length(local.ssh_key_files_missing) == 0
      error_message = "ssh_public_key_files not found: ${join(", ", local.ssh_key_files_missing)}"
    }
  }
}

# ------------------------------------------------------------------------------
# Hosts
# ------------------------------------------------------------------------------

module "host" {
  source = "../../modules/compute_host"

  compartment_ocid    = var.compartment_ocid
  vcn_id              = local.core.vcn_id
  vcn_cidr            = local.core.vcn_cidr
  subnet_id           = local.subnet_ids[var.subnet]
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  lab_name_core       = local.core.lab_name_core
  freeform_tags       = var.freeform_tags

  component            = var.component
  role_tag             = "${var.component}-host"
  data_role_tag        = "${var.component}-data"
  hostname_prefix      = var.hostname_prefix
  host_count           = var.host_count
  instance_image_ocid  = local.image_id
  shape                = var.shape
  ocpus                = var.ocpus
  memory_gbs           = var.memory_gbs
  boot_volume_size_gbs = var.boot_volume_size_gbs

  ssh_public_keys = local.ssh_public_keys
  ingress_rules   = var.ingress_rules
}

# --- EOF ----------------------------------------------------------------------
