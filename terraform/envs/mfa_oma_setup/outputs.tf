# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: outputs.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-05-14
# Version....: v0.1.0
# Purpose....: Stack outputs for mfa_oma_setup - proxies all module outputs
# Notes......: Sensitive outputs require: terraform output -json
#              or: terraform output db_mfa_config_commands
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------

output "iam_domain_url" {
  description = "Identity Domain URL (MFA_OMA_IAM_DOMAIN_URL)"
  value       = module.iam_mfa_oma.iam_domain_url
}

output "oauth_client_id" {
  description = "OAuth Application client ID"
  value       = module.iam_mfa_oma.oauth_client_id
}

output "oauth_client_secret" {
  description = "OAuth Application client secret (sensitive)"
  sensitive   = true
  value       = module.iam_mfa_oma.oauth_client_secret
}

output "smtp_host" {
  description = "OCI Email Delivery SMTP host"
  value       = module.iam_mfa_oma.smtp_host
}

output "smtp_port" {
  description = "OCI Email Delivery SMTP port"
  value       = module.iam_mfa_oma.smtp_port
}

output "smtp_sender_email" {
  description = "Approved Sender email address"
  value       = module.iam_mfa_oma.smtp_sender_email
}

output "smtp_username" {
  description = "SMTP credential username"
  value       = module.iam_mfa_oma.smtp_username
}

output "smtp_password" {
  description = "SMTP credential password (sensitive - save immediately after apply)"
  sensitive   = true
  value       = module.iam_mfa_oma.smtp_password
}

output "smtp_user_ocid" {
  description = "OCID of the SMTP IAM user"
  value       = module.iam_mfa_oma.smtp_user_ocid
}

output "approved_sender_ocid" {
  description = "OCID of the OCI Email Delivery Approved Sender"
  value       = module.iam_mfa_oma.approved_sender_ocid
}

output "db_mfa_config_commands" {
  description = "ALTER SYSTEM commands for Oracle DB-side MFA setup"
  sensitive   = true
  value       = module.iam_mfa_oma.db_mfa_config_commands
}

# ------------------------------------------------------------------------------
# EOF
# ------------------------------------------------------------------------------
