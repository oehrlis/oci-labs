# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Core locals for naming and tagging helpers.
# Notes......: Builds consistent lab name core and base freeform tags.
# Reference..: https://github.com/oehrlis/oci-labs-infra
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Locals
# ------------------------------------------------------------------------------

locals {
  # Lab instance as two-digit string, e.g. 01, 02, 03
  lab_instance_padded = format("%02d", var.lab_instance)

  # Core name segment used inside all resource names:
  # {region}-{env}-{stack}-{instance}
  #
  # Example: chzh-l-odb19eng-01
  lab_name_core = "${var.region_key}-${var.environment_code}-${var.stack_code}-${local.lab_instance_padded}"

  # Base freeform tags for this lab / stack. Extend per resource if needed.
  base_freeform_tags = merge(
    var.common_freeform_tags,
    {
      stack   = var.stack_code
      env     = var.environment_code
      region  = var.region_key
      lab_idx = local.lab_instance_padded # <--- HIER war der Fehler
    }
  )
}

# --- EOF ----------------------------------------------------------------------
