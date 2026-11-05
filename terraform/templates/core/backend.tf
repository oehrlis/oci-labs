# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: backend.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.11.05
# Version....: v0.1.0
# Purpose....: Remote state for the core layer in an OCI bucket of the target.
# Notes......: Partial configuration - bucket, namespace, key, region and profile
#              come from backend.hcl: terraform init -backend-config=backend.hcl
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------

terraform {
  backend "oci" {}
}

# --- EOF ----------------------------------------------------------------------
