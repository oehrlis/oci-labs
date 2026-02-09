# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: outputs.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Expose key outputs for the lab-db19c-baseline stack.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

output "bastion_id" {
  value = module.bastion.bastion_id
}

output "db1_private_ip" {
  value = module.db1.private_ip
}

output "ssh_via_bastion_command" {
  description = "SSH command to access DB host through OCI Bastion"
  value       = "oci bastion session connect --bastion-id ${module.bastion.bastion_id} --target-private-ip ${module.db1.private_ip} --region ${var.region} --private-key-file ~/.ssh/id_rsa"
}

output "ssh_direct_command" {
  description = "Final SSH command once a Bastion session (session-id) exists."
  value       = "ssh -i ~/.ssh/id_rsa -o ProxyCommand='oci bastion session connect --session-id <SESSION_ID> --region ${var.region} --target-os-username opc --private-key-file ~/.ssh/id_rsa' opc@${module.db1.private_ip}"
}

output "ssh_db1" {
  description = "Direct SSH via Bastion (session auto-creation)."
  value       = "ssh -i ~/.ssh/id_rsa -o ProxyCommand='oci bastion session connect --bastion-id ${module.bastion.bastion_id} --target-private-ip ${module.db1.private_ip} --region ${var.region} --private-key-file ~/.ssh/id_rsa' opc@${module.db1.private_ip}"
}

# --- EOF ----------------------------------------------------------------------
