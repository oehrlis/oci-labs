# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: variables.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Define inputs for the compute_linux module (shape, storage,
#              bootstrap, and lookup settings).
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

variable "compartment_ocid" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "instance_name" {
  type = string
}

variable "shape" {
  type = string
}

variable "ocpus" {
  type = number
}

variable "memory_gbs" {
  type = number
}

variable "boot_volume_size_gbs" {
  type = number
}

variable "data_volume_size_gbs" {
  type    = number
  default = 50
}

variable "enable_data_volume" {
  type    = bool
  default = false
}

variable "ssh_public_key" {
  type = string
}

# optional: OS selection
variable "os_name" {
  type    = string
  default = "Oracle Linux"
}

variable "os_version" {
  type    = string
  default = "9"
}

# base64-encoded cloud-init user_data (wird im Stack mit base64encode(templatefile()) erzeugt)
variable "user_data" {
  type        = string
  description = "Base64-encoded user_data for the instance (cloud-init)"
}

# aktuell nicht verwendet, aber vom Stack übergeben – drinlassen, damit kein 'unsupported argument' entsteht
variable "bootstrap_url" {
  type        = string
  description = "Bootstrap URL (currently unused in the module, kept for future use)"
}

variable "profile_type" {
  type        = string
  description = "Profile type used by bootstrap (e.g. db19c)"
}

variable "profile_name" {
  type        = string
  description = "Profile name used by bootstrap (e.g. baseline)"
}

variable "tenancy_ocid" {
  type        = string
  description = "Tenancy OCID (used for identity availability domains lookup)"
}

# --- EOF ----------------------------------------------------------------------
