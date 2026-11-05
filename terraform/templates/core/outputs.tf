# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: outputs.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.11.05
# Version....: v0.1.0
# Purpose....: Outputs of the core layer, read by host layers via remote state.
# Notes......: Host layers use terraform_remote_state with backend oci and
#              the same bucket; vcn_cidr saves them a lookup.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------

output "lab_name_core" {
  description = "Name segment of the target, e.g. zrh-lab-cpu."
  value       = module.naming.lab_name_core
}

output "vcn_id" {
  description = "OCID of the core VCN."
  value       = module.core.vcn_id
}

output "vcn_cidr" {
  description = "CIDR of the core VCN (intra-VCN NSG rules of the hosts)."
  value       = var.vcn_cidr
}

output "public_subnet_id" {
  description = "OCID of the public subnet."
  value       = module.core.public_subnet_id
}

output "private_subnet_id" {
  description = "OCID of the private subnet."
  value       = module.core.private_subnet_id
}

output "db_subnet_id" {
  description = "OCID of the DB subnet."
  value       = module.core.db_subnet_id
}

output "bastion_id" {
  description = "OCID of the Bastion (null when enable_bastion = false)."
  value       = module.core.bastion_id
}

# --- EOF ----------------------------------------------------------------------
