# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: provider.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.10.19
# Version....: v0.1.0
# Purpose....: Configure Terraform and the OCI provider for the datasafe-demo
#              stack (LRN6087, Oracle AI World 2026).
# Notes......: Uses the local OCI CLI config (~/.oci/config). The profile is
#              set via oci_config_profile - for this demo the ACE tenancy.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.10.19 oehrli - initial version
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 6.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}

provider "oci" {
  config_file_profile = var.oci_config_profile
  region              = var.region
}

# IAM writes (policies, dynamic groups) are only accepted in the home region of
# the tenancy - the Trivadis tenancy runs in eu-zurich-1 but its home is FRA
# (403 NotAllowed, 2026-10-23). Empty home_region = same as region.
provider "oci" {
  alias               = "home"
  config_file_profile = var.oci_config_profile
  region              = coalesce(var.home_region, var.region)
}

# --- EOF ----------------------------------------------------------------------
