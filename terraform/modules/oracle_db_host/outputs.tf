# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: outputs.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.08.19
# Version....: v0.1.0
# Purpose....: Module outputs for the Oracle DB lab hosts.
# Notes......: Maps are keyed by host index ("01", "02", ...).
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.08.19 oehrli - initial version
# ------------------------------------------------------------------------------

output "instance_ids" {
  description = "OCIDs of the Oracle DB hosts, keyed by host index."
  value       = { for k, v in oci_core_instance.db_host : k => v.id }
}

output "instance_names" {
  description = "Display names of the Oracle DB hosts, keyed by host index."
  value       = { for k, v in oci_core_instance.db_host : k => v.display_name }
}

output "private_ips" {
  description = "Private IPs of the Oracle DB hosts, keyed by host index."
  value       = { for k, v in oci_core_instance.db_host : k => v.private_ip }
}

output "public_ips" {
  description = "Public IPs of the Oracle DB hosts, keyed by host index (empty when assign_public_ip = false)."
  value       = { for k, v in oci_core_instance.db_host : k => v.public_ip }
}

output "hostnames" {
  description = "Short hostnames of the Oracle DB hosts, keyed by host index."
  value       = { for k, v in oci_core_instance.db_host : k => v.create_vnic_details[0].hostname_label }
}

output "nsg_id" {
  description = "OCID of the Oracle DB host NSG."
  value       = oci_core_network_security_group.db_host.id
}

output "data_volume_ids" {
  description = "OCIDs of the optional data volumes, keyed by host index (empty when attach_data_volume = false)."
  value       = { for k, v in oci_core_volume.data : k => v.id }
}

# --- EOF ----------------------------------------------------------------------
