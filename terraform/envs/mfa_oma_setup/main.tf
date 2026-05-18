# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrily@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-05-14
# Version....: v0.1.0
# Purpose....: Deployable stack calling the iam_mfa_oma module
# Notes......: Provisions all OCI prerequisites for Oracle Database Native MFA
#              with OMA Push. Run 'terraform output db_mfa_config_commands' after
#              apply to get copy-paste ready ALTER SYSTEM statements.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------

module "iam_mfa_oma" {
  source = "../../modules/iam_mfa_oma"

  # OCI scope
  tenancy_ocid         = var.tenancy_ocid
  compartment_ocid     = var.compartment_ocid
  identity_domain_ocid = var.identity_domain_ocid
  region               = var.region

  # Naming
  region_key   = var.region_key
  env          = var.env
  stack        = var.stack
  lab_instance = var.lab_instance
  project_tag  = var.project_tag

  # Email Delivery
  smtp_sender_email = var.smtp_sender_email
  smtp_sender_name  = var.smtp_sender_name

  # OAuth Application
  app_name = var.app_name

  # Email Domain (optional)
  create_email_domain = var.create_email_domain
  email_domain        = var.email_domain

  # DKIM (optional)
  create_dkim       = var.create_dkim
  email_domain_ocid = var.email_domain_ocid
}

# ------------------------------------------------------------------------------
# EOF
# ------------------------------------------------------------------------------
