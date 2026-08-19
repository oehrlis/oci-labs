# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: outputs.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.08.19
# Version....: v0.1.0
# Purpose....: Stack outputs for the cpu-patch-test environment.
# Notes......: Exposes host IPs, ready-to-paste SSH commands, the generated
#              Ansible inventory path, and the effective ORACLE_HOME values.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.08.19 oehrli - initial version
# ------------------------------------------------------------------------------

output "lab_name_core" {
  description = "Core lab name segment used in all resource names."
  value       = local.lab_name_core
}

output "compartment_ocid" {
  description = "OCID of the base compartment the stack deployed into."
  value       = local.compartment_ocid
}

output "db_sys_password" {
  description = <<-EOT
    Generated SYS / SYSTEM password for the lab database. Pass it to Ansible:
      -e db19_sys_password="$(terraform output -raw db_sys_password)"
  EOT
  value       = local.db_sys_password
  sensitive   = true
}

output "autoupgrade_keystore_password" {
  description = <<-EOT
    Generated password for the AutoUpgrade keystore. Pass it to Ansible:
      -e db19_autoupgrade_keystore_password="$(terraform output -raw autoupgrade_keystore_password)"
  EOT
  value       = local.autoupgrade_keystore_password
  sensitive   = true
}

output "vcn_id" {
  description = "OCID of the lab VCN."
  value       = module.network.vcn_id
}

output "db_host_subnet_id" {
  description = "OCID of the subnet hosting the DB instances."
  value       = local.db_host_subnet_id
}

output "db_instance_ids" {
  description = "OCIDs of the DB lab hosts, keyed by host index."
  value       = module.oracle_db_host.instance_ids
}

output "db_instance_names" {
  description = "Display names of the DB lab hosts, keyed by host index."
  value       = module.oracle_db_host.instance_names
}

output "db_private_ips" {
  description = "Private IPs of the DB lab hosts, keyed by host index."
  value       = module.oracle_db_host.private_ips
}

output "db_public_ips" {
  description = "Public IPs of the DB lab hosts, keyed by host index (empty when assign_public_ip = false)."
  value       = module.oracle_db_host.public_ips
}

output "ssh_authorized_key_count" {
  description = "Number of SSH public keys authorised for the opc user."
  value       = length(local.ssh_public_keys)
}

output "ssh_authorized_key_comments" {
  description = "Trailing comment of each authorised key, to identify them without exposing key material."
  value       = [for k in local.ssh_public_keys : try(join(" ", slice(split(" ", trimspace(k)), 2, length(split(" ", trimspace(k))))), "(no comment)")]
}

output "lab_private_key_path" {
  description = "Path of the generated lab private key (null when generate_lab_keypair = false)."
  value       = var.generate_lab_keypair ? local_sensitive_file.lab_private_key[0].filename : null
}

output "ssh_commands" {
  description = "Ready-to-use SSH commands per host index, using the generated lab key when present."
  value = {
    for k, v in local.ansible_host_ips :
    k => var.generate_lab_keypair ? "ssh -i ${local_sensitive_file.lab_private_key[0].filename} opc@${v}" : "ssh opc@${v}"
  }
}

output "ansible_inventory_path" {
  description = "Path of the generated (git-ignored) Ansible inventory."
  value       = local_file.ansible_inventory.filename
}

output "oracle_base" {
  description = "Effective ORACLE_BASE on the lab host."
  value       = local.oracle_base
}

output "oracle_home_base" {
  description = "Effective ORACLE_HOME of the base RU installation."
  value       = local.oracle_home_base
}

output "oracle_home_target" {
  description = "Effective ORACLE_HOME of the target RU installation."
  value       = local.oracle_home_target
}

output "bastion_id" {
  description = "OCID of the Bastion (null when enable_bastion = false)."
  value       = one(oci_bastion_bastion.lab[*].id)
}

output "bastion_name" {
  description = "Name of the Bastion (null when enable_bastion = false)."
  value       = one(oci_bastion_bastion.lab[*].name)
}

output "auto_stop_schedule_id" {
  description = "OCID of the auto-stop schedule (null when enable_auto_stop = false)."
  value       = var.enable_auto_stop ? oci_resource_scheduler_schedule.db_host_stop[0].id : null
}

# --- EOF ----------------------------------------------------------------------
