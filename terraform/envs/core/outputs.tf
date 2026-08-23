# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: outputs.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Date.......: 2026.08.23
# Version....: v0.1.0
# Purpose....: What a lab stack consumes from the shared core.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------

output "vcn_id" {
  description = "OCID of the shared VCN."
  value       = module.core.vcn_id
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
  description = "OCID of the database subnet."
  value       = module.core.db_subnet_id
}

output "bastion_id" {
  description = "OCID of the shared Bastion, null when disabled."
  value       = module.core.bastion_id
}

output "artifact_bucket_name" {
  description = "Artifact bucket for gold images and staged patch media."
  value       = module.core.artifact_bucket_name
}

output "artifact_namespace" {
  description = "Object Storage namespace of the tenancy."
  value       = module.core.artifact_namespace
}

output "lab_name_core" {
  description = "Naming core segment, so a consumer can find these resources by convention."
  value       = module.naming.lab_name_core
}

# --- EOF ----------------------------------------------------------------------
