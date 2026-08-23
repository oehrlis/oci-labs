# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: provider.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Date.......: 2026.08.23
# Version....: v0.1.0
# Purpose....: Provider configuration for the shared core stack.
# Notes......: Uses the local OCI CLI config. Switching tenancy is a matter of
#              pointing oci_config_profile at another profile and supplying a
#              compartment - nothing else in this stack is tenancy-specific.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 6.0"
    }
  }
}

provider "oci" {
  config_file_profile = var.oci_config_profile
}

# --- EOF ----------------------------------------------------------------------
