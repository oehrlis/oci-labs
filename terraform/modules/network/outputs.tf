# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: outputs.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Module outputs for created network resources.
# Notes......: Exposes OCIDs for VCN, subnets, and logging.
# Reference..: https://github.com/oehrlis/oci-labs-infra
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

output "vcn_id" {
  description = "OCID of the created VCN."
  value       = oci_core_vcn.this.id
}

output "public_subnet_id" {
  description = "OCID of the public subnet."
  value       = oci_core_subnet.public.id
}

output "private_subnet_id" {
  description = "OCID of the private subnet."
  value       = oci_core_subnet.private.id
}

output "db_subnet_id" {
  description = "OCID of the DB subnet."
  value       = oci_core_subnet.db.id
}

output "app_subnet_id" {
  description = "OCID of the App subnet."
  value       = oci_core_subnet.app.id
}

output "log_group_id" {
  description = "OCID of the network log group."
  value       = oci_logging_log_group.net.id
}

# --- EOF ----------------------------------------------------------------------
