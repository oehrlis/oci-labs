# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: outputs.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.06.26
# Version....: v0.1.0
# Purpose....: Stack outputs for the ad-cmu-test environment.
# Notes......: Exposes Windows AD instance IPs, VCN, and subnet OCIDs.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.06.26 oehrli - initial version
# ------------------------------------------------------------------------------

output "lab_name_core" {
  description = "Core lab name segment used in all resource names."
  value       = local.lab_name_core
}

output "vcn_id" {
  description = "OCID of the lab VCN."
  value       = module.network.vcn_id
}

output "windows_subnet_id" {
  description = "OCID of the Windows AD subnet."
  value       = module.network.windows_subnet_id
}

output "windows_instance_id" {
  description = "OCID of the Windows AD instance."
  value       = module.windows_ad.instance_id
}

output "windows_public_ip" {
  description = "Public IP of the Windows AD instance (empty if assign_windows_public_ip = false)."
  value       = module.windows_ad.public_ip
}

output "windows_private_ip" {
  description = "Private IP of the Windows AD instance."
  value       = module.windows_ad.private_ip
}

output "windows_instance_name" {
  description = "Display name of the Windows AD instance."
  value       = module.windows_ad.instance_name
}

# --- EOF ----------------------------------------------------------------------
