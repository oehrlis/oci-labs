# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: variables.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Input variables for naming and tagging helpers.
# Notes......: Mirrors naming inputs used across stacks.
# Reference..: https://github.com/oehrlis/oci-labs-infra
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

# OCI region key, e.g. chzh, eu-frn, uk-lon
variable "region_key" {
  type        = string
  description = "OCI region key used in resource names, e.g. chzh, eu-frn, uk-lon."
}

# Environment code: l (lab), ws (workshop), d (dev), t (test), p (prod)
variable "environment_code" {
  type        = string
  description = "Environment code used in resource names, e.g. l (lab), ws (workshop), d, t, p."
  default     = "l"
}

# Stack / lab type, e.g. odb19eng, odb21eng, odb26ai, odbaud
variable "stack_code" {
  type        = string
  description = "Stack or lab type code, e.g. odb19eng, odb21eng, odb26ai, odbaud."
}

# Lab instance index (for multiple labs of the same type), e.g. 1 -> 01
variable "lab_instance" {
  type        = number
  description = "Numeric index for the lab instance, used to build names (1 -> 01)."
  default     = 1
}

# Common freeform tags applied to all resources, can be extended per resource.
variable "common_freeform_tags" {
  type        = map(string)
  description = "Base freeform tags applied to all resources of this stack; can be extended per resource."
  default = {
    project = "oradba-labs"
    owner   = "oehrli"
  }
}

# --- EOF ----------------------------------------------------------------------
