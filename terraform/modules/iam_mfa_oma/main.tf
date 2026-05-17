# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-05-14
# Version....: v0.1.0
# Purpose....: OCI prerequisites for Oracle Database Native MFA with OMA Push
# Notes......: Creates: OAuth Confidential App in Identity Domain, SMTP user +
#              credential, Approved Email Sender, IAM policy.
#              DB-side configuration (ALTER SYSTEM, wallet) is out of scope.
#              After apply: grant app roles (MFA Client, User Administrator,
#              Identity Domain Administration) via OCI Console or CLI - see README.
# Reference..: https://github.com/oehrlis/oci-labs
#              https://docs.oracle.com/en/learn/mfa-db23ai-oma/
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Locals
# ------------------------------------------------------------------------------

locals {
  lab_instance_padded = format("%02d", var.lab_instance)
  name_prefix         = "${var.region_key}-${var.env}-${var.stack}"

  app_display_name = var.app_name != "" ? var.app_name : "app-${local.name_prefix}-oauth-${local.lab_instance_padded}"
  smtp_user_name   = "usr-${local.name_prefix}-smtp-${local.lab_instance_padded}"
  policy_name      = "pol-${local.name_prefix}-smtp-${local.lab_instance_padded}"
  smtp_host        = "smtp.email.${var.region}.oci.oraclecloud.com"

  base_tags = merge(var.freeform_tags, {
    project = var.project_tag
    env     = var.env
    stack   = var.stack
  })
}

# ------------------------------------------------------------------------------
# Identity Domain lookup
# ------------------------------------------------------------------------------

data "oci_identity_domain" "domain" {
  domain_id = var.identity_domain_ocid
}

# ------------------------------------------------------------------------------
# OAuth Confidential Application
# ------------------------------------------------------------------------------
# After apply: grant roles via OCI Console (Identity & Security -> Domains ->
# <Domain> -> Oracle Cloud Services -> <app> -> Application Roles) or via CLI.
# Required roles: MFA Client, User Administrator, Identity Domain Administration.

resource "oci_identity_domains_application" "oauth_app" {
  idcs_endpoint = data.oci_identity_domain.domain.url
  schemas       = ["urn:ietf:params:scim:schemas:oracle:idcs:App"]
  display_name  = local.app_display_name
  description   = "Oracle Database Native MFA - OMA Push (${local.name_prefix})"

  is_oauth_client = true
  allowed_grants  = ["client_credentials"]
  client_type     = "confidential"

  lifecycle {
    ignore_changes = [urnietfparamsscimschemasoracleidcsextensionrequestableApp]
  }
}

# ------------------------------------------------------------------------------
# SMTP User (tenancy root - IAM users are tenancy-wide)
# ------------------------------------------------------------------------------

resource "oci_identity_user" "smtp_user" {
  compartment_id = var.tenancy_ocid
  name           = local.smtp_user_name
  description    = "Dedicated SMTP user for Oracle DB MFA email delivery"
  email          = var.smtp_sender_email

  freeform_tags = local.base_tags
}

# ------------------------------------------------------------------------------
# SMTP Credential bound to SMTP User
# ------------------------------------------------------------------------------
# The generated username and password are exposed as module outputs.
# The password is shown only once - save it immediately after apply.

resource "oci_identity_smtp_credential" "smtp_cred" {
  description = "SMTP credential for ${local.smtp_user_name}"
  user_id     = oci_identity_user.smtp_user.id
}

# ------------------------------------------------------------------------------
# Approved Sender in OCI Email Delivery
# ------------------------------------------------------------------------------

resource "oci_email_sender" "approved_sender" {
  compartment_id = var.compartment_ocid
  email_address  = var.smtp_sender_email

  freeform_tags = local.base_tags
}

# ------------------------------------------------------------------------------
# DKIM record (optional - only when email domain is already verified)
# ------------------------------------------------------------------------------

resource "oci_email_dkim" "dkim" {
  count           = var.create_dkim ? 1 : 0
  email_domain_id = var.email_domain_ocid
  name            = "dkim-${local.name_prefix}-${local.lab_instance_padded}"

  freeform_tags = local.base_tags
}

# ------------------------------------------------------------------------------
# IAM Policy: allow SMTP user to use email-family in target compartment
# ------------------------------------------------------------------------------

resource "oci_identity_policy" "smtp_policy" {
  compartment_id = var.tenancy_ocid
  name           = local.policy_name
  description    = "Allow ${local.smtp_user_name} to use email-family for Oracle DB MFA"

  statements = [
    "Allow user ${oci_identity_user.smtp_user.name} to use email-family in compartment id ${var.compartment_ocid}",
  ]

  freeform_tags = local.base_tags

  depends_on = [oci_identity_user.smtp_user]
}

# ------------------------------------------------------------------------------
# EOF
# ------------------------------------------------------------------------------
