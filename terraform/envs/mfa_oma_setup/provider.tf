# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: provider.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-05-14
# Version....: v0.1.0
# Purpose....: Terraform and OCI provider configuration for mfa_oma_setup stack
# Notes......: OCI CLI profile set via var.oci_profile (default: DEFAULT).
#              Identity Domain resources require OCI Provider >= 5.0.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.3"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0"
    }
  }
}

provider "oci" {
  region              = var.region
  config_file_profile = var.oci_profile
}

# ------------------------------------------------------------------------------
# EOF
# ------------------------------------------------------------------------------
