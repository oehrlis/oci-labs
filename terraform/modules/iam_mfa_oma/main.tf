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
  smtp_group_name  = "grp-${local.name_prefix}-smtp-${local.lab_instance_padded}"
  policy_name      = "pol-${local.name_prefix}-smtp-${local.lab_instance_padded}"
  smtp_host        = "smtp.email.${var.region}.oci.oraclecloud.com"
  # Identity Domains API rejects explicit :443 in some provider versions
  idcs_endpoint = replace(data.oci_identity_domain.domain.url, ":443", "")

  # Resolve effective email domain OCID: prefer the created domain, fall back to provided OCID
  effective_email_domain_ocid = try(oci_email_email_domain.email_domain[0].id, var.email_domain_ocid)

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

resource "oci_identity_domains_app" "oauth_app" {
  idcs_endpoint = local.idcs_endpoint
  schemas       = ["urn:ietf:params:scim:schemas:oracle:idcs:App"]
  display_name  = local.app_display_name
  description   = "Oracle Database Native MFA - OMA Push (${local.name_prefix})"
  active        = true

  based_on_template {
    value = "CustomWebAppTemplateId"
  }

  is_oauth_client = true
  allowed_grants  = ["client_credentials"]
  client_type     = "confidential"

  lifecycle {
    ignore_changes = [urnietfparamsscimschemasoracleidcsextensionrequestable_app]
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
# Email Domain (optional)
# ------------------------------------------------------------------------------
# After apply: add the domain_verification_token output as a DNS TXT record
# (_email-validation.<domain>) to verify the domain in OCI Email Delivery.
# Domain verification is required before create_dkim = true can be used.

resource "oci_email_email_domain" "email_domain" {
  count          = var.create_email_domain ? 1 : 0
  compartment_id = var.compartment_ocid
  name           = var.email_domain

  freeform_tags = local.base_tags
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
  email_domain_id = local.effective_email_domain_ocid
  name            = "dkim-${local.name_prefix}-${local.lab_instance_padded}"

  freeform_tags = local.base_tags
}

# ------------------------------------------------------------------------------
# IAM Group for SMTP User
# ------------------------------------------------------------------------------
# Identity Domain tenancies do not support "Allow user <name>" policy syntax;
# group-based policies are required.

resource "oci_identity_group" "smtp_group" {
  compartment_id = var.tenancy_ocid
  name           = local.smtp_group_name
  description    = "Group for SMTP user - Oracle DB MFA email delivery"

  freeform_tags = local.base_tags
}

resource "oci_identity_user_group_membership" "smtp_membership" {
  group_id = oci_identity_group.smtp_group.id
  user_id  = oci_identity_user.smtp_user.id
}

# ------------------------------------------------------------------------------
# IAM Policy: allow SMTP group to use email-family in target compartment
# ------------------------------------------------------------------------------

resource "oci_identity_policy" "smtp_policy" {
  compartment_id = var.tenancy_ocid
  name           = local.policy_name
  description    = "Allow ${local.smtp_group_name} to use email-family for Oracle DB MFA"

  statements = [
    "Allow group ${oci_identity_group.smtp_group.name} to use email-family in compartment id ${var.compartment_ocid}",
  ]

  freeform_tags = local.base_tags

  depends_on = [oci_identity_group.smtp_group]
}

# ------------------------------------------------------------------------------
# EOF
# ------------------------------------------------------------------------------
