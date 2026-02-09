# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: outputs.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Expose compute_linux module outputs (instance and data volume).
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

output "instance_id" {
  value = oci_core_instance.this.id
}

output "private_ip" {
  value = oci_core_instance.this.private_ip
}

output "data_volume_id" {
  value = try(oci_core_volume.data[0].id, null)
}

# --- EOF ----------------------------------------------------------------------
