# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: variables.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Define input variables for the lab-db19c-baseline stack.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

variable "tenancy_ocid" {
  description = "Tenancy OCID (home tenancy, not just the target compartment)"
  type        = string
}

variable "user_ocid" {
  description = "User OCID for API signing"
  type        = string
}

variable "fingerprint" {
  description = "API key fingerprint"
  type        = string
}

variable "private_key_path" {
  description = "Path to API private key"
  type        = string
}

variable "region" {
  description = "The OCI region where resources will be created"
  type        = string
}

variable "compartment_ocid" {
  description = "Target compartment for the lab"
  type        = string
}


variable "cidr_vcn" {
  type    = string
  default = "10.0.0.0/16"
}

variable "cidr_private_subnet" {
  type    = string
  default = "10.0.1.0/24"
}

variable "ssh_public_key" {
  type = string
}

variable "bootstrap_url" {
  type = string
}

variable "profile_type" {
  type    = string
  default = "db19c"
}

variable "profile_name" {
  type    = string
  default = "baseline"
}

# --- EOF ----------------------------------------------------------------------
