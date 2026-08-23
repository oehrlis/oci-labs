# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: outputs.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Date.......: 2026.08.23
# Version....: v0.1.0
# Purpose....: What a consuming lab stack needs from the core.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------

output "vcn_id" {
  description = "OCID of the shared VCN."
  value       = module.network.vcn_id
}

output "public_subnet_id" {
  description = "OCID of the public subnet."
  value       = module.network.public_subnet_id
}

output "private_subnet_id" {
  description = "OCID of the private subnet."
  value       = module.network.private_subnet_id
}

output "db_subnet_id" {
  description = "OCID of the database subnet."
  value       = module.network.db_subnet_id
}

output "bastion_id" {
  description = "OCID of the Bastion, null when disabled."
  value       = try(oci_bastion_bastion.core[0].id, null)
}

output "artifact_bucket_name" {
  description = "Artifact bucket name, whether managed here or pre-existing."
  value       = var.artifact_bucket_name
}

output "artifact_namespace" {
  description = "Object Storage namespace of the tenancy."
  value       = data.oci_objectstorage_namespace.ns.namespace
}

output "core_owner" {
  description = "Owner tag on every core resource. A consumer compares this to decide whether it may destroy them."
  value       = var.core_owner
}

# --- EOF ----------------------------------------------------------------------
