# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: outputs.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Module outputs for DB19 engineering hosts.
# Notes......: Exposes OCIDs, IPs, display names, and hostname labels.
# Reference..: https://github.com/oehrlis/oci-labs-infra
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

output "instance_ids" {
  description = "List of OCIDs of the DB19 instances."
  value       = [for i in oci_core_instance.db19 : i.id]
}

output "private_ips" {
  description = "List of private IPs of the DB19 instances."
  value       = [for i in oci_core_instance.db19 : i.private_ip]
}

output "hostnames" {
  description = "List of hostnames (display names) of the DB19 instances."
  value       = [for i in oci_core_instance.db19 : i.display_name]
}

output "hostname_labels" {
  description = "List of hostname labels (DNS names) of the DB19 instances."
  value       = [for i in oci_core_instance.db19 : i.hostname_label]
}

# --- EOF ----------------------------------------------------------------------
