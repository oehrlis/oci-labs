# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: variables.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.11.05
# Version....: v0.1.0
# Purpose....: Inputs for the host-on-core template.
# Notes......: One layer per host group (component), several layers per target.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------

variable "oci_config_profile" {
  type        = string
  description = "Profile in ~/.oci/config that selects the tenancy (same as the core layer)."
}

variable "region" {
  type        = string
  description = "OCI region name, e.g. eu-zurich-1."
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment of the target."
}

variable "core_state" {
  type = object({
    bucket    = string
    namespace = string
    key       = string
  })
  description = "Where the core layer keeps its state (same bucket as this layer, key <target>/core/terraform.tfstate)."
}

variable "subnet" {
  type        = string
  description = "Core subnet for the hosts: db, private or public."
  default     = "db"

  validation {
    condition     = contains(["db", "private", "public"], var.subnet)
    error_message = "subnet must be db, private or public."
  }
}

variable "component" {
  type        = string
  description = "Component segment of the names, e.g. db -> ci-zrh-lab-cpu-db-01."
}

variable "hostname_prefix" {
  type        = string
  description = "DNS label prefix, unique per subnet across all layers of the target (db19 -> db1901)."
}

variable "host_count" {
  type        = number
  description = "Number of identical hosts."
  default     = 1
}

variable "shape" {
  type        = string
  description = "Flex shape. Oracle DB 19c needs x86."
  default     = "VM.Standard.E5.Flex"
}

variable "ocpus" {
  type        = number
  description = "OCPUs per host."
  default     = 2
}

variable "memory_gbs" {
  type        = number
  description = "Memory in GB per host."
  default     = 16
}

variable "boot_volume_size_gbs" {
  type        = number
  description = "Boot volume size in GB."
  default     = 200
}

variable "ol_version" {
  type        = string
  description = "Oracle Linux major version for the image lookup (8 or 9)."
  default     = "9"
}

variable "instance_image_ocid" {
  type        = string
  description = "Fixed image OCID instead of the lookup (reproducible rebuilds)."
  default     = null
}

variable "ingress_rules" {
  type = map(object({
    protocol    = string
    port_min    = optional(number)
    port_max    = optional(number)
    source      = optional(string)
    description = string
  }))
  description = "Extra NSG ingress rules (see compute_host), e.g. the listener or a WebLogic console."
  default     = {}
}

variable "ssh_public_key_files" {
  type        = list(string)
  description = "Existing public keys on the workstation, e.g. [\"~/.ssh/id_ed25519.pub\"]."
  default     = []
}

variable "generate_lab_keypair" {
  type        = bool
  description = "Generate an ed25519 pair for this layer, written to .ssh/ next to the root."
  default     = true
}

variable "freeform_tags" {
  type        = map(string)
  description = "Tags on every host resource."
  default     = {}
}

# --- EOF ----------------------------------------------------------------------
