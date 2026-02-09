# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: variables.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Input variables for the jumphost/gateway module.
# Notes......: Uses naming module outputs and supports SSH/WireGuard settings.
# Reference..: https://github.com/oehrlis/oci-labs-infra
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

# OCI compartment
variable "compartment_ocid" {
  type        = string
  description = "Compartment OCID where the jumphost instance will be created."
}

# Availability domain where the instance is placed
variable "availability_domain" {
  type        = string
  description = "Availability domain name for the jumphost instance."
}

# Target subnet (typically public)
variable "subnet_id" {
  type        = string
  description = "Subnet OCID where the jumphost will be placed (typically public subnet)."
}

# Core naming from naming module
variable "lab_name_core" {
  type        = string
  description = "Core lab name segment used in resource names."
}

# Base freeform tags
variable "freeform_tags" {
  type        = map(string)
  description = "Base freeform tags applied to the jumphost resources."
  default     = {}
}

# Compute shape
variable "shape" {
  type        = string
  description = "Shape for the jumphost instance (e.g. VM.Standard.A1.Flex)."
  default     = "VM.Standard.A1.Flex"
}

# vCPU count
variable "ocpus" {
  type        = number
  description = "Number of OCPUs for the jumphost."
  default     = 1
}

# Memory
variable "memory_gbs" {
  type        = number
  description = "Memory in GB for the jumphost."
  default     = 16
}

# Public IP assignment
variable "assign_public_ip" {
  type        = bool
  description = "Whether to assign a public IP to the jumphost."
  default     = true
}

# SSH keys for opc
variable "ssh_authorized_keys" {
  type        = string
  description = "SSH public key(s) for the jumphost (one or more, separated by newlines)"
}

# SSH port
variable "ssh_port" {
  type        = number
  description = "SSH port that the jumphost listens on."
  default     = 16022
}

# Ansible repository settings
variable "ansible_repo_url" {
  type    = string
  default = "https://github.com/oehrlis/oci-labs-config.git"
}

variable "ansible_branch" {
  type    = string
  default = "main"
}

variable "ansible_playbook" {
  type    = string
  default = "lab-jumphost.yml"
}

# WireGuard enablement
variable "enable_wireguard" {
  type        = bool
  description = "If true, install and prepare WireGuard packages via cloud-init."
  default     = true
}

# Base image
variable "instance_image_ocid" {
  type        = string
  description = "Image OCID for the jumphost instance (e.g. Oracle Linux 9)."
}

# Boot volume
variable "boot_volume_size_gbs" {
  type        = number
  description = "Boot volume size in GB."
  default     = 20
}

# --- EOF ----------------------------------------------------------------------
