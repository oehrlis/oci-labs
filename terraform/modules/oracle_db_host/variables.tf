# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: variables.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.08.19
# Version....: v0.1.0
# Purpose....: Input variables for the oracle_db_host module.
# Notes......: Oracle Linux 8 compute host(s) for Oracle Database labs.
#              host_count drives for_each; every host is identical.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.08.19 oehrli - initial version
# ------------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Core / placement
# -----------------------------------------------------------------------------

variable "compartment_ocid" {
  type        = string
  description = "Compartment OCID where the Oracle DB host resources will be created."
}

variable "vcn_id" {
  type        = string
  description = "VCN OCID - required for creating the instance-level NSG."
}

variable "vcn_cidr" {
  type        = string
  description = "VCN CIDR block. Used as ingress source for intra-VCN NSG rules."
}

variable "subnet_id" {
  type        = string
  description = "Subnet OCID where the Oracle DB host(s) will be placed."
}

variable "availability_domain" {
  type        = string
  description = "Availability domain name for the Oracle DB host(s)."
}

variable "lab_name_core" {
  type        = string
  description = "Core lab name segment used for resource names, e.g. chzh-l-cpupt-01."
}

variable "freeform_tags" {
  type        = map(string)
  description = "Base freeform tags applied to all resources of this module."
  default     = {}
}

# -----------------------------------------------------------------------------
# Instance sizing and image
# -----------------------------------------------------------------------------

variable "host_count" {
  type        = number
  description = "Number of identical Oracle DB hosts to create (workshops: > 1)."
  default     = 1

  validation {
    condition     = var.host_count >= 1 && var.host_count <= 20
    error_message = "host_count must be between 1 and 20."
  }
}

variable "instance_image_ocid" {
  type        = string
  description = "Image OCID for the Oracle Linux 8 instance. Resolved in the env stack."
}

variable "shape" {
  type        = string
  description = "Compute shape. Must be x86 - Oracle DB 19c has no ARM release."
  default     = "VM.Standard.E4.Flex"
}

variable "ocpus" {
  type        = number
  description = "Number of OCPUs per Oracle DB host."
  default     = 2
}

variable "memory_gbs" {
  type        = number
  description = "Memory in GB per Oracle DB host. 16 GB is the practical minimum for 19c."
  default     = 16
}

variable "boot_volume_size_gbs" {
  type        = number
  description = "Boot volume size in GB. Must hold two ORACLE_HOMEs plus install media."
  default     = 200

  validation {
    condition     = var.boot_volume_size_gbs >= 100
    error_message = "boot_volume_size_gbs must be at least 100 GB for an Oracle DB host."
  }
}

variable "assign_public_ip" {
  type        = bool
  description = "Assign a public IP. Requires a public-capable subnet and allowed_ssh_cidrs."
  default     = true
}

# -----------------------------------------------------------------------------
# Optional data volume (engineering use case, not needed for CPU tests)
# -----------------------------------------------------------------------------

variable "attach_data_volume" {
  type        = bool
  description = "Attach an additional block volume per host (engineering labs)."
  default     = false
}

variable "data_volume_size_gbs" {
  type        = number
  description = "Size in GB of the optional data volume per host."
  default     = 100
}

variable "data_volume_vpus_per_gb" {
  type        = number
  description = "Block volume performance in VPUs/GB (0 = lower cost, 10 = balanced, 20 = high)."
  default     = 10
}

# -----------------------------------------------------------------------------
# Access
# -----------------------------------------------------------------------------

variable "ssh_public_keys" {
  type        = list(string)
  description = <<-EOT
    SSH public keys placed in instance metadata for the opc user. All of them
    are authorised - typically the operator's personal key plus a per-lab
    keypair generated for the stack lifecycle.
  EOT

  validation {
    condition     = length(var.ssh_public_keys) > 0
    error_message = "At least one SSH public key is required, otherwise the host is unreachable."
  }

  validation {
    condition     = alltrue([for k in var.ssh_public_keys : can(regex("^(ssh-(rsa|ed25519)|ecdsa-sha2-)", trimspace(k)))])
    error_message = "Each entry must be an OpenSSH public key (ssh-rsa, ssh-ed25519, or ecdsa-sha2-*)."
  }
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach SSH from outside the VCN. Empty = intra-VCN only."
  default     = []
}

variable "ssh_port" {
  type        = number
  description = "SSH port exposed by the NSG."
  default     = 22
}

variable "listener_port" {
  type        = number
  description = "Oracle Net listener port exposed intra-VCN by the NSG."
  default     = 1521
}

# -----------------------------------------------------------------------------
# Cloud-init / bootstrap
# -----------------------------------------------------------------------------

variable "oradba_repo_url" {
  type        = string
  description = "Git URL of the oradba environment scripts, cloned during cloud-init."
  default     = "https://github.com/oehrlis/oradba.git"
}

variable "oradba_install_dir" {
  type        = string
  description = "Target directory for the oradba clone on the instance."
  default     = "/opt/oradba"
}

# --- EOF ----------------------------------------------------------------------
