# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: outputs.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.06.26
# Version....: v0.1.0
# Purpose....: Module outputs for the Windows AD instance.
# Notes......: Exposes instance OCID, IP addresses, and display name.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.06.26 oehrli - initial version
# ------------------------------------------------------------------------------

output "instance_id" {
  description = "OCID of the Windows AD instance."
  value       = oci_core_instance.windows_ad.id
}

output "public_ip" {
  description = "Public IP of the Windows AD instance (empty if assign_public_ip = false)."
  value       = oci_core_instance.windows_ad.public_ip
}

output "private_ip" {
  description = "Private IP of the Windows AD instance."
  value       = oci_core_instance.windows_ad.private_ip
}

output "instance_name" {
  description = "Display name of the Windows AD instance."
  value       = oci_core_instance.windows_ad.display_name
}

output "nsg_id" {
  description = "OCID of the Windows AD NSG."
  value       = oci_core_network_security_group.windows_ad.id
}

# --- EOF ----------------------------------------------------------------------
