# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: outputs.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Module outputs for the jumphost/gateway instance.
# Notes......: Exposes OCIDs and IP addresses.
# Reference..: https://github.com/oehrlis/oci-labs-infra
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

output "instance_id" {
  description = "OCID of the jumphost instance."
  value       = oci_core_instance.jumphost.id
}

output "public_ip" {
  description = "Public IP address of the jumphost (if assigned)."
  value       = oci_core_instance.jumphost.public_ip
}

output "private_ip" {
  description = "Private IP address of the jumphost."
  value       = oci_core_instance.jumphost.private_ip
}

# --- EOF ----------------------------------------------------------------------
