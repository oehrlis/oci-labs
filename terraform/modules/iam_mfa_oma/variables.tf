# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: variables.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-05-14
# Version....: v0.1.0
# Purpose....: Input variables for iam_mfa_oma module
# Notes......: Provisions OCI prerequisites for Oracle Database Native MFA
#              with OMA Push (OAuth App, SMTP User, Email Sender, IAM Policy).
#              DB-side configuration is out of scope.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------

# -- OCI Identity / scope ------------------------------------------------------

variable "tenancy_ocid" {
  description = "Tenancy OCID. IAM users and policies are created at the tenancy root."
  type        = string
}

variable "compartment_ocid" {
  description = "Compartment OCID for Email Delivery resources and the SMTP policy."
  type        = string
}

variable "identity_domain_ocid" {
  description = "OCID of the OCI Identity Domain used for the OAuth Confidential Application."
  type        = string
}

variable "region" {
  description = "OCI region identifier, e.g. eu-zurich-1. Used to build the SMTP endpoint hostname."
  type        = string
  default     = "eu-zurich-1"
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
  description = "Stack code used in resource names, e.g. mfaoma."
  type        = string
  default     = "mfaoma"
}

variable "lab_instance" {
  description = "Numeric instance index used to build zero-padded suffix (1 -> 01)."
  type        = number
  default     = 1
}

variable "project_tag" {
  description = "Value for the 'project' freeform tag applied to all resources."
  type        = string
  default     = "oradba-labs"
}

variable "freeform_tags" {
  description = "Additional freeform tags merged with the base tags on every resource."
  type        = map(string)
  default     = {}
}

# -- Email Delivery ------------------------------------------------------------

variable "smtp_sender_email" {
  description = "Email address registered as Approved Sender, e.g. labdb@oradba.ch."
  type        = string
}

variable "smtp_sender_name" {
  description = "Display name for the SMTP sender shown in email headers."
  type        = string
  default     = "Oracle DB MFA"
}

# -- OAuth Application ---------------------------------------------------------

variable "app_name" {
  description = "Override for the OAuth Confidential Application display name. Empty = derived from naming convention."
  type        = string
  default     = ""
}

# -- Email Domain (optional) ---------------------------------------------------

variable "create_email_domain" {
  description = "Create the OCI Email Delivery domain. After apply, add the output TXT record to your DNS zone to verify the domain. Required before create_dkim = true can be used."
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
  description = "Create a DKIM record for the email domain. Requires a verified domain (create_email_domain = true or email_domain_ocid provided)."
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
