# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: variables.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.06.26
# Version....: v0.1.0
# Purpose....: Input variables for the windows_ad module.
# Notes......: Stack-code "windc". Windows Server 2022 x86 (VM.Standard3.Flex).
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.06.26 oehrli - initial version
# ------------------------------------------------------------------------------

variable "compartment_ocid" {
  type        = string
  description = "Compartment OCID where the Windows AD instance will be created."
}

variable "vcn_id" {
  type        = string
  description = "VCN OCID - required for creating the instance-level NSG."
}

variable "lab_name_core" {
  type        = string
  description = "Core lab name segment used for resource names."
}

variable "freeform_tags" {
  type        = map(string)
  description = "Base freeform tags applied to all Windows AD resources."
  default     = {}
}

variable "subnet_id" {
  type        = string
  description = "Subnet OCID where the Windows AD instance will be placed (windows subnet)."
}

variable "availability_domain" {
  type        = string
  description = "Availability domain name for the Windows AD instance."
}

variable "instance_image_ocid" {
  type        = string
  description = "Image OCID for the Windows Server 2022 instance."
}

variable "ssh_authorized_keys" {
  type        = string
  description = "SSH public key(s) stored in OCI instance metadata (compatibility, not used for WinRM)."
  default     = ""
}

variable "shape" {
  type        = string
  description = "Compute shape for the Windows AD instance. Must be x86 (not ARM)."
  default     = "VM.Standard.E4.Flex"
}

variable "ocpus" {
  type        = number
  description = "Number of OCPUs for the Windows AD instance."
  default     = 2
}

variable "memory_gbs" {
  type        = number
  description = "Memory in GB for the Windows AD instance."
  default     = 8
}

variable "boot_volume_size_gbs" {
  type        = number
  description = "Boot volume size in GB."
  default     = 100
}

variable "assign_public_ip" {
  type        = bool
  description = "Whether to assign a public IP to the Windows AD instance. Requires internet_gateway_enabled on the subnet."
  default     = false
}

variable "domain_name" {
  type        = string
  description = "Active Directory domain name (FQDN). Set in the env, not the module."
}

variable "admin_password_secret" {
  type        = string
  sensitive   = true
  description = "Administrator password for the Windows instance. Pass via TF_VAR or op run -- terraform apply."
}

# --- EOF ----------------------------------------------------------------------
