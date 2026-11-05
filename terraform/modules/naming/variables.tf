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
variable "name_scheme" {
  type        = string
  description = "legacy (default, names of existing stacks) or oci ({resource}-{region}-{env}-{stack}-{component}-{nn})."
  default     = "legacy"

  validation {
    condition     = contains(["legacy", "oci"], var.name_scheme)
    error_message = "name_scheme must be legacy or oci."
  }
}

variable "region_key" {
  type        = string
  description = "Region in resource names. legacy: as given (chzh). oci: OCI region name (eu-zurich-1 -> zrh) or the code itself."

  validation {
    condition = var.name_scheme != "oci" || can(regex("^[a-z]{3}$", lookup({
      "eu-zurich-1" = "zrh", "eu-frankfurt-1" = "fra", "us-ashburn-1" = "iad"
    }, var.region_key, var.region_key)))
    error_message = "name_scheme oci: region_key must be a mapped OCI region (eu-zurich-1, eu-frankfurt-1, us-ashburn-1) or a three-letter code - add new regions to region_codes in main.tf."
  }
}

# Environment code: l (lab), ws (workshop), d (dev), t (test), p (prod)
variable "environment_code" {
  type        = string
  description = "Environment code. legacy: e.g. l, ws, d, t, p. oci: lab, dev, test or prod."
  default     = "l"

  validation {
    condition     = var.name_scheme != "oci" || contains(["lab", "dev", "test", "prod"], var.environment_code)
    error_message = "name_scheme oci: environment_code must be lab, dev, test or prod."
  }
}

# Stack / lab type, e.g. odb19eng, odb21eng, odb26ai, odbaud
variable "stack_code" {
  type        = string
  description = "Stack or lab type code, e.g. odb19eng, odb21eng, odb26ai, odbaud, cpu."

  validation {
    condition     = var.name_scheme != "oci" || can(regex("^[a-z][a-z0-9]{1,15}$", var.stack_code))
    error_message = "name_scheme oci: stack_code must be lowercase alphanumeric (no hyphens), 2-16 characters."
  }
}

# Lab instance index (for multiple labs of the same type), e.g. 1 -> 01
variable "lab_instance" {
  type        = number
  description = "Numeric index for the lab instance, used to build names (1 -> 01). legacy only."
  default     = 1

  validation {
    condition     = var.name_scheme != "oci" || var.lab_instance == 1
    error_message = "name_scheme oci has one index slot (the resource's own) - give a second lab its own stack_code instead of lab_instance."
  }
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
