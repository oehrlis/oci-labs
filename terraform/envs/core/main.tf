# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Date.......: 2026.08.23
# Version....: v0.1.0
# Purpose....: The shared core stack: one network, one artifact bucket, one
#              Bastion, in their own state, outliving every lab that uses them.
# Notes......: Deploying this is optional. A lab env can build its own core when
#              none is found. What this stack adds is ownership: everything it
#              creates carries core_owner = "core", and a lab env never destroys
#              a resource tagged that way. Without it, whichever lab happens to
#              build the network first owns it, and its destroy takes the others
#              with it.
#
#              A new tenancy needs a profile, a .env and one apply here. That is
#              the whole tenancy story - no pre-seeded resources, nothing to
#              migrate except the bucket contents, which are cheaper to rebuild.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------

data "oci_identity_compartments" "by_name" {
  count = var.compartment_ocid == null && var.compartment_name != null ? 1 : 0

  compartment_id            = var.tenancy_ocid
  compartment_id_in_subtree = true
  access_level              = "ACCESSIBLE"
  name                      = var.compartment_name
  state                     = "ACTIVE"
}

locals {
  compartment_ocid = try(coalesce(
    var.compartment_ocid,
    try(one(data.oci_identity_compartments.by_name[0].compartments).id, null),
  ), null)
}

resource "terraform_data" "compartment_guard" {
  input = local.compartment_ocid

  lifecycle {
    precondition {
      condition = local.compartment_ocid != null
      error_message = join(" ", [
        "No compartment resolved.",
        "Set compartment_ocid directly, or correct compartment_name.",
      ])
    }
  }
}

module "naming" {
  source = "../../modules/naming"

  region_key           = var.region_key
  environment_code     = var.environment_code
  stack_code           = var.stack_code
  lab_instance         = var.lab_instance
  common_freeform_tags = var.common_freeform_tags
}

module "core" {
  source = "../../modules/core"

  compartment_ocid = local.compartment_ocid
  lab_name_core    = module.naming.lab_name_core
  freeform_tags    = module.naming.base_freeform_tags

  # The marker that makes this deployment the owner. A lab env instantiating
  # the same module tags itself instead, which is how an orphan stays visible.
  core_owner = "core"

  vcn_cidr          = var.vcn_cidr
  allowed_ssh_cidrs = var.allowed_ssh_cidrs

  manage_artifact_bucket = var.manage_artifact_bucket
  artifact_bucket_name   = var.artifact_bucket_name

  enable_bastion = var.enable_bastion
}

# --- EOF ----------------------------------------------------------------------
