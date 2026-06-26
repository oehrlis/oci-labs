# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: provider.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.06.26
# Version....: v0.1.0
# Purpose....: Configure Terraform and OCI provider for the ad-cmu-test stack.
#              Windows AD lab for Oracle CMU + Kerberos testing.
# Notes......: Uses local OCI CLI config (~/.oci/config, profile DEFAULT).
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.06.26 oehrli - initial version
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
}

provider "oci" {
  config_file_profile = "ACE"
}

# --- EOF ----------------------------------------------------------------------
