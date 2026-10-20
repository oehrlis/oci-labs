# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: outputs.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.10.19
# Version....: v0.1.0
# Purpose....: Stack outputs for the datasafe-demo environment.
# Notes......: Bastion, SSH and inventory paths for the operator; instance OCID
#              and private IP for the Data Safe target registration (demo.sh).
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.10.19 oehrli - initial version
# ------------------------------------------------------------------------------

output "lab_name_core" {
  description = "Core lab name segment used in all resource names."
  value       = local.lab_name_core
}

output "compartment_ocid" {
  description = "OCID of the base compartment the stack deployed into (DS_ROOT_COMP for odb_datasafe)."
  value       = local.compartment_ocid
}

output "region" {
  description = "Region of the stack - Data Safe must be enabled here."
  value       = var.region
}

output "db_sys_password" {
  description = "Generated SYS, SYSTEM and PDBADMIN password of CDB19 and CDB26. Used by make/Ansible only."
  value       = local.db_sys_password
  sensitive   = true
}

output "autoupgrade_keystore_password" {
  description = "Generated password of the AutoUpgrade keystore (MOS credentials). Used by make/Ansible only."
  value       = local.autoupgrade_keystore_password
  sensitive   = true
}

output "vcn_id" {
  description = "OCID of the demo VCN."
  value       = module.core.vcn_id
}

output "db_host_subnet_id" {
  description = "OCID of the DB subnet hosting the demo instance."
  value       = module.core.db_subnet_id
}

output "db_instance_ids" {
  description = "OCIDs of the demo host, keyed by host index (Makefile-compatible shape)."
  value       = module.oracle_db_host.instance_ids
}

output "db_instance_id" {
  description = "OCID of the demo host - instanceId in the Data Safe target registration."
  value       = local.db_host_id
}

output "db_instance_name" {
  description = "Display name of the demo host."
  value       = module.oracle_db_host.instance_names["01"]
}

output "db_hostname" {
  description = "Short hostname of the demo host."
  value       = local.db_host_hostname
}

output "db_private_ips" {
  description = "Private IP of the demo host, keyed by host index (Makefile-compatible shape)."
  value       = module.oracle_db_host.private_ips
}

output "db_private_ip" {
  description = "Private IP of the demo host - listener address the connector uses (both CDBs, port 1521)."
  value       = local.db_host_private_ip
}

output "lab_private_key_path" {
  description = "Path of the generated lab private key (null when generate_lab_keypair = false)."
  value       = var.generate_lab_keypair ? local_sensitive_file.lab_private_key[0].filename : null
}

output "ssh_command_via_tunnel" {
  description = "SSH command once the Bastion tunnel listens on 127.0.0.1:2222 (demos/datasafe-lrn6087/tunnel.sh)."
  value       = var.generate_lab_keypair ? "ssh -i ${local_sensitive_file.lab_private_key[0].filename} -o IdentitiesOnly=yes -p 2222 opc@127.0.0.1" : "ssh -p 2222 opc@127.0.0.1"
}

output "ansible_inventory_path" {
  description = "Path of the generated (git-ignored) Ansible inventory."
  value       = local_file.ansible_inventory.filename
}

output "bastion_id" {
  description = "OCID of the Bastion (null when enable_bastion = false)."
  value       = module.core.bastion_id
}

output "data_volume_id" {
  description = "OCID of the data volume mounted on /u01 (null when attach_data_volume = false)."
  value       = try(module.oracle_db_host.data_volume_ids["01"], null)
}

output "schedule" {
  description = "Active start/stop profile and its UTC cron expressions (null crons when schedule_profile = off)."
  value = {
    profile    = var.schedule_profile
    start_cron = local.schedule_start_cron
    stop_cron  = local.schedule_stop_cron
    start_id   = one(oci_resource_scheduler_schedule.db_host_start[*].id)
    stop_id    = one(oci_resource_scheduler_schedule.db_host_stop[*].id)
  }
}

output "instance_principal_dynamic_group" {
  description = "Name of the dynamic group for the host (null when enable_instance_principal = false)."
  value       = one(oci_identity_dynamic_group.db_host[*].name)
}

output "ds_connector_name" {
  description = "Display name of the Data Safe on-premises connector the Ansible run creates."
  value       = var.ds_connector_name
}

# --- EOF ----------------------------------------------------------------------
