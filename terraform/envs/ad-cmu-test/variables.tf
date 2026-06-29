# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: variables.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.06.26
# Version....: v0.1.0
# Purpose....: Input variables for the ad-cmu-test stack.
# Notes......: Stack-code "windc". admin_password_secret via TF_VAR or op run.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.06.26 oehrli - initial version
# ------------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Core / naming variables
# -----------------------------------------------------------------------------

variable "compartment_ocid" {
  type        = string
  description = "OCI compartment OCID where the lab resources will be created."
}

variable "region_key" {
  type        = string
  description = "OCI region key used in resource names, e.g. chzh, eu-frn."
}

variable "environment_code" {
  type        = string
  description = "Environment code used in resource names, e.g. l (lab), t (test)."
  default     = "l"
}

variable "stack_code" {
  type        = string
  description = "Stack code for Windows DC lab."
  default     = "windc"
}

variable "lab_instance" {
  type        = number
  description = "Numeric index for the lab instance (1 -> 01)."
  default     = 1
}

variable "common_freeform_tags" {
  type        = map(string)
  description = "Base freeform tags applied to all resources of this stack."
  default = {
    project = "oradba-labs"
    owner   = "oehrli"
  }
}

# -----------------------------------------------------------------------------
# Network variables
# -----------------------------------------------------------------------------

variable "vcn_cidr" {
  type        = string
  description = "CIDR block for the lab VCN."
  default     = "10.19.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR block for the public subnet."
  default     = "10.19.10.0/24"
}

variable "private_subnet_cidr" {
  type        = string
  description = "CIDR block for the private subnet."
  default     = "10.19.20.0/24"
}

variable "windows_subnet_cidr" {
  type        = string
  description = "CIDR block for the Windows AD subnet."
  default     = "10.19.50.0/24"
}

variable "allowed_rdp_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach RDP from outside the VCN. Default: empty (no external RDP)."
  default     = []
}

variable "enable_flow_logs" {
  type        = bool
  description = "Enable VCN flow logs."
  default     = true
}

variable "flow_log_retention_duration" {
  type        = number
  description = "Flow log retention in days (30-day increments)."
  default     = 90
}

# -----------------------------------------------------------------------------
# Windows AD instance variables
# -----------------------------------------------------------------------------

variable "instance_image_ocid" {
  type        = string
  description = "Optional: explicit image OCID for Windows AD. When set, skips data source image lookup."
  default     = null
}

variable "windows_shape" {
  type        = string
  description = "Shape for the Windows AD VM. Must be x86 (not ARM)."
  default     = "VM.Standard.E4.Flex"
}

variable "windows_ocpus" {
  type        = number
  description = "Number of OCPUs for the Windows AD instance."
  default     = 2
}

variable "windows_memory_gbs" {
  type        = number
  description = "Memory in GB for the Windows AD instance."
  default     = 16
}

variable "windows_os_version" {
  type        = string
  description = "Windows Server OS version for image lookup."
  default     = "Server 2022 Standard"
}

variable "windows_boot_volume_size_gbs" {
  type        = number
  description = "Boot volume size in GB for the Windows AD instance."
  default     = 100
}

variable "assign_windows_public_ip" {
  type        = bool
  description = "Assign a public IP to the Windows AD instance (needs allowed_rdp_cidrs)."
  default     = false
}

variable "domain_name" {
  type        = string
  description = "Active Directory domain name (FQDN)."
  default     = "oradba.ch"
}

variable "company_name" {
  type        = string
  description = "Company name used in AD OU and user creation."
  default     = "OraDBA Labs"
}

variable "admin_password_secret" {
  type        = string
  sensitive   = true
  description = "Windows Administrator password. Set via TF_VAR_admin_password_secret or op run -- terraform apply."
}

# -----------------------------------------------------------------------------
# VPN / DRG connectivity
# -----------------------------------------------------------------------------

variable "drg_id" {
  type        = string
  description = "OCID of existing DRG for site-to-site VPN connectivity. Set to attach this VCN to the home lab VPN."
  default     = null
}

variable "home_cidrs" {
  type        = list(string)
  description = "Home/VPN CIDRs routed via DRG (home LAN + WireGuard clients). Only effective when drg_id is set."
  default     = []
}

# --- EOF ----------------------------------------------------------------------
