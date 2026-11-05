# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: outputs.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.11.05
# Version....: v0.1.0
# Purpose....: Module outputs for the compute hosts.
# Notes......: Maps are keyed by host index ("01", "02", ...).
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.11.05 oehrli - initial version (extracted from oracle_db_host)
# ------------------------------------------------------------------------------

output "instance_ids" {
  description = "OCIDs of the hosts, keyed by host index."
  value       = { for k, v in oci_core_instance.this : k => v.id }
}

output "instance_names" {
  description = "Display names of the hosts, keyed by host index."
  value       = { for k, v in oci_core_instance.this : k => v.display_name }
}

output "private_ips" {
  description = "Private IPs of the hosts, keyed by host index."
  value       = { for k, v in oci_core_instance.this : k => v.private_ip }
}

output "public_ips" {
  description = "Public IPs of the hosts, keyed by host index (empty when assign_public_ip = false)."
  value       = { for k, v in oci_core_instance.this : k => v.public_ip }
}

output "hostnames" {
  description = "Short hostnames of the hosts, keyed by host index."
  value       = { for k, v in oci_core_instance.this : k => v.create_vnic_details[0].hostname_label }
}

output "nsg_id" {
  description = "OCID of the host NSG."
  value       = oci_core_network_security_group.this.id
}

output "data_volume_ids" {
  description = "OCIDs of the optional data volumes, keyed by host index (empty when attach_data_volume = false)."
  value       = { for k, v in oci_core_volume.data : k => v.id }
}

# --- EOF ----------------------------------------------------------------------
