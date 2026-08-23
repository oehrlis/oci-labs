# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: variables.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Date.......: 2026.08.23
# Version....: v0.1.0
# Purpose....: Inputs for the shared core stack.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------

variable "oci_config_profile" {
  description = "Profile in ~/.oci/config. The only thing that changes for another tenancy."
  type        = string
  default     = "TRIVADIS"
}

variable "tenancy_ocid" {
  description = "Tenancy OCID, used to resolve compartment_name."
  type        = string
  default     = null
}

variable "compartment_ocid" {
  description = "Compartment OCID. Supply this or compartment_name."
  type        = string
  default     = null
}

variable "compartment_name" {
  description = "Compartment name, resolved below the tenancy when compartment_ocid is unset."
  type        = string
  default     = null
}

variable "region_key" {
  description = "Short region key for the naming module."
  type        = string
  default     = "chzh"
}

variable "environment_code" {
  description = "Environment code for the naming module."
  type        = string
  default     = "l"
}

variable "stack_code" {
  description = "Stack code for the naming module."
  type        = string
  default     = "core"
}

variable "lab_instance" {
  description = "Instance suffix for the naming module."
  type        = string
  default     = "01"
}

variable "common_freeform_tags" {
  description = "Base freeform tags."
  type        = map(string)
  default     = {}
}

variable "vcn_cidr" {
  description = "VCN CIDR block."
  type        = string
  default     = "10.29.0.0/16"
}

variable "allowed_ssh_cidrs" {
  description = "Source CIDRs allowed to reach SSH on the public subnet."
  type        = list(string)
  default     = []
}

variable "manage_artifact_bucket" {
  description = "Create the artifact bucket. False in a tenancy where it predates Terraform."
  type        = bool
  default     = false
}

variable "artifact_bucket_name" {
  description = "Artifact bucket for gold images and staged patch media."
  type        = string
  default     = "orarepo"
}

variable "enable_bastion" {
  description = "Create a shared Bastion."
  type        = bool
  default     = true
}
