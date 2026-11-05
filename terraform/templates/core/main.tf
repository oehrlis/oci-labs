# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.11.05
# Version....: v0.1.0
# Purpose....: Core layer of a target: VCN, subnets, gateways, Bastion.
# Notes......: Long-lived and free; hosts come and go on top of it. The media
#              bucket (orarepo) is deliberately never part of this state -
#              it is shared across targets and is never destroyed.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------

module "naming" {
  source = "../../modules/naming"

  name_scheme          = "oci"
  region_key           = var.region
  environment_code     = var.environment_code
  stack_code           = var.stack_code
  common_freeform_tags = var.freeform_tags
}

module "core" {
  source = "../../modules/core"

  compartment_ocid = var.compartment_ocid
  lab_name_core    = module.naming.lab_name_core
  freeform_tags    = module.naming.base_freeform_tags
  core_owner       = "core"

  # Subnets derived from the VCN CIDR (/16 -> .10/.20/.30 /24 as before), so a
  # second target only needs another vcn_cidr.
  vcn_cidr            = var.vcn_cidr
  public_subnet_cidr  = cidrsubnet(var.vcn_cidr, 8, 10)
  private_subnet_cidr = cidrsubnet(var.vcn_cidr, 8, 20)
  db_subnet_cidr      = cidrsubnet(var.vcn_cidr, 8, 30)
  allowed_ssh_cidrs   = var.allowed_ssh_cidrs
  enable_bastion      = var.enable_bastion

  # orarepo stays outside every state (rule 2026-11-05): a destroy of the core
  # must never be able to reach the media bucket.
  manage_artifact_bucket = false
}

# --- EOF ----------------------------------------------------------------------
