# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: variables.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-05-14
# Version....: v0.1.0
# Purpose....: Input variables for mfa_oma_setup stack
# Notes......: Copy terraform.tfvars.example to terraform.tfvars and fill values.
#              Sensitive OCIDs: export via .env (TF_VAR_*) - never commit to git.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------

# -- OCI provider --------------------------------------------------------------

variable "oci_profile" {
  description = "OCI CLI config file profile name (~/.oci/config). Use DEFAULT or a named profile."
  type        = string
  default     = "DEFAULT"
}

variable "region" {
  description = "OCI region, e.g. eu-zurich-1. Must match the region where Email Delivery is available."
  type        = string
  default     = "eu-zurich-1"
}

# -- OCI Identity / scope ------------------------------------------------------

variable "tenancy_ocid" {
  description = "Tenancy OCID. Set via TF_VAR_tenancy_ocid in .env."
  type        = string
}

variable "compartment_ocid" {
  description = "Compartment OCID for Email Delivery resources and the SMTP IAM policy."
  type        = string
}

variable "identity_domain_ocid" {
  description = "OCID of the OCI Identity Domain for the OAuth Confidential Application."
  type        = string
}

# -- Naming / tagging ----------------------------------------------------------

variable "region_key" {
  description = "Short region key used in resource names, e.g. zrh, fra, iad."
  type        = string
  default     = "zrh"
}

variable "env" {
  description = "Environment code used in resource names, e.g. lab, dev, prod."
  type        = string
  default     = "lab"
}

variable "stack" {
  description = "Stack code used in resource names."
  type        = string
  default     = "mfaoma"
}

variable "lab_instance" {
  description = "Numeric instance index (1 -> 01)."
  type        = number
  default     = 1
}

variable "project_tag" {
  description = "Value for the 'project' freeform tag on all resources."
  type        = string
  default     = "oradba-labs"
}

# -- Email Delivery ------------------------------------------------------------

variable "smtp_sender_email" {
  description = "Email address to register as Approved Sender, e.g. labdb@oradba.ch."
  type        = string
}

variable "smtp_sender_name" {
  description = "Display name shown in the From header of MFA emails."
  type        = string
  default     = "Oracle DB MFA Demo"
}

# -- OAuth Application ---------------------------------------------------------

variable "app_name" {
  description = "Override for the OAuth App display name. Empty = auto-derived from naming convention."
  type        = string
  default     = ""
}

# -- Email Domain (optional) ---------------------------------------------------

variable "create_email_domain" {
  description = "Create the OCI Email Delivery domain. After apply, add the TXT record output to DNS to verify the domain."
  type        = bool
  default     = false
}

variable "email_domain" {
  description = "Email domain name to register in OCI Email Delivery, e.g. oradba.ch. Required when create_email_domain = true."
  type        = string
  default     = null
}

# -- DKIM (optional) -----------------------------------------------------------

variable "create_dkim" {
  description = "Create a DKIM record. Requires a verified domain (create_email_domain = true or email_domain_ocid provided)."
  type        = bool
  default     = false
}

variable "email_domain_ocid" {
  description = "OCID of an existing OCI Email Delivery domain. Used when create_email_domain = false and create_dkim = true."
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# EOF
# ------------------------------------------------------------------------------
