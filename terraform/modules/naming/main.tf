# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.2.0
# Purpose....: Core locals for naming and tagging helpers.
# Notes......: Builds consistent lab name core and base freeform tags.
#              name_scheme "oci" follows the OCI naming rule
#              {resource}-{region}-{env}-{stack}-{component}-{nn}; "legacy"
#              keeps the names of existing stacks.
# Reference..: https://github.com/oehrlis/oci-labs-infra
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# 2026.11.05 oehrli - name_scheme oci (region codes, env lab|dev|test|prod)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Locals
# ------------------------------------------------------------------------------

locals {
  # Lab instance as two-digit string, e.g. 01, 02, 03
  lab_instance_padded = format("%02d", var.lab_instance)

  # OCI region name -> three-letter code of the naming rule. A region_key that
  # is not in the map is used as given (it may already be a code). Keep the
  # map in sync with the region_key validation in variables.tf (a validation
  # cannot read locals).
  region_codes = {
    "eu-zurich-1"    = "zrh"
    "eu-frankfurt-1" = "fra"
    "us-ashburn-1"   = "iad"
  }
  region_code = lookup(local.region_codes, var.region_key, var.region_key)

  # Core name segment used inside all resource names. Resources append their
  # component and a two-digit index:
  #   legacy: {region}-{env}-{stack}-{instance}  e.g. chzh-l-odb19eng-01
  #   oci:    {region}-{env}-{stack}             e.g. zrh-lab-cpu
  #           -> vcn-zrh-lab-cpu-net-01, ci-zrh-lab-cpu-db-01
  # The oci scheme has one index slot only (the resource's own), so a second
  # lab of the same kind needs its own stack_code instead of lab_instance.
  lab_name_core = (var.name_scheme == "oci"
    ? "${local.region_code}-${var.environment_code}-${var.stack_code}"
    : "${var.region_key}-${var.environment_code}-${var.stack_code}-${local.lab_instance_padded}"
  )

  # Base freeform tags for this lab / stack. Extend per resource if needed.
  base_freeform_tags = merge(
    var.common_freeform_tags,
    {
      stack   = var.stack_code
      env     = var.environment_code
      region  = var.name_scheme == "oci" ? local.region_code : var.region_key
      lab_idx = local.lab_instance_padded
    }
  )
}

# --- EOF ----------------------------------------------------------------------
