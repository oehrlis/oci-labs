# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: versions.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026-06-26
# Version....: v0.1.0
# Purpose....: Provider requirements for the windows_ad module
# Notes......: Modules using non-HashiCorp providers must declare the source
#              explicitly; without this Terraform defaults to hashicorp/oci.
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

# ------------------------------------------------------------------------------
# EOF
# ------------------------------------------------------------------------------
