# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: outputs.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.08.19
# Version....: v0.2.0
# Purpose....: Module outputs for the Oracle DB lab hosts.
# Notes......: Maps are keyed by host index ("01", "02", ...).
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.08.19 oehrli - initial version
# 2026.11.05 oehrli - values from compute_host
# ------------------------------------------------------------------------------

output "instance_ids" {
  description = "OCIDs of the Oracle DB hosts, keyed by host index."
  value       = module.host.instance_ids
}

output "instance_names" {
  description = "Display names of the Oracle DB hosts, keyed by host index."
  value       = module.host.instance_names
}

output "private_ips" {
  description = "Private IPs of the Oracle DB hosts, keyed by host index."
  value       = module.host.private_ips
}

output "public_ips" {
  description = "Public IPs of the Oracle DB hosts, keyed by host index (empty when assign_public_ip = false)."
  value       = module.host.public_ips
}

output "hostnames" {
  description = "Short hostnames of the Oracle DB hosts, keyed by host index."
  value       = module.host.hostnames
}

output "nsg_id" {
  description = "OCID of the Oracle DB host NSG."
  value       = module.host.nsg_id
}

output "data_volume_ids" {
  description = "OCIDs of the optional data volumes, keyed by host index (empty when attach_data_volume = false)."
  value       = module.host.data_volume_ids
}

# --- EOF ----------------------------------------------------------------------
