# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: outputs.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.11.05
# Version....: v0.1.0
# Purpose....: Outputs of a host layer for inventory and Bastion sessions.
# Notes......: Maps keyed by host index (01, 02, ...).
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------

output "hostnames" {
  description = "Short hostnames of the hosts."
  value       = module.host.hostnames
}

output "private_ips" {
  description = "Private IPs of the hosts."
  value       = module.host.private_ips
}

output "instance_ids" {
  description = "Instance OCIDs (Bastion port-forwarding target)."
  value       = module.host.instance_ids
}

output "bastion_id" {
  description = "Bastion of the core."
  value       = local.core.bastion_id
}

output "lab_private_key_file" {
  description = "Path of the generated private key (null without generate_lab_keypair)."
  value       = try(local_sensitive_file.lab_private_key[0].filename, null)
}

# --- EOF ----------------------------------------------------------------------
