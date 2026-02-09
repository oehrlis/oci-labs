# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: provider.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Purpose....: Configure Terraform and OCI provider for the lab-db19c-baseline
#              stack using local OCI CLI config (~/.oci/config).
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }
}

# Wir verwenden dieselbe Auth wie oci-CLI: ~/.oci/config, Profil DEFAULT
provider "oci" {
  config_file_profile = "DEFAULT"
}

# --- EOF ----------------------------------------------------------------------
