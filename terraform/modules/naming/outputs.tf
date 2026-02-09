# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: outputs.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Module outputs for naming and tagging helpers.
# Notes......: Exposes lab name core and base freeform tags.
# Reference..: https://github.com/oehrlis/oci-labs-infra
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

# Lab name core string, e.g. chzh-l-odb19eng-01
output "lab_name_core" {
  value = local.lab_name_core
}

# Base freeform tags map for this stack
output "base_freeform_tags" {
  value = local.base_freeform_tags
}

# --- EOF ----------------------------------------------------------------------
