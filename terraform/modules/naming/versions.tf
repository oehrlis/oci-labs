# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: versions.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.11.05
# Version....: v0.2.0
# Purpose....: Terraform version requirement for the naming module.
# Notes......: 1.9 for input validations that reference name_scheme.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.9"
}

# --- EOF ----------------------------------------------------------------------
