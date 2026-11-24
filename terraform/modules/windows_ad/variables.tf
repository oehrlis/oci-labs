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
# 2026.11.24 oehrli - vcn_cidr, allowed_cidrs, ad_lab_scripts_ref/_sha256
# ------------------------------------------------------------------------------

variable "compartment_ocid" {
  type        = string
  description = "Compartment OCID where the Windows AD instance will be created."
}

variable "vcn_id" {
  type        = string
  description = "VCN OCID - required for creating the instance-level NSG."
}

variable "vcn_cidr" {
  type        = string
  description = "VCN CIDR block. When set, the NSG allows all AD and management ports from inside the VCN."
  default     = null

  validation {
    condition     = var.vcn_cidr == null || can(cidrnetmask(var.vcn_cidr))
    error_message = "vcn_cidr must be a valid IPv4 CIDR block, e.g. 10.19.0.0/16."
  }
}

variable "allowed_cidrs" {
  type        = list(string)
  description = "Additional CIDRs allowed to reach RDP, WinRM, LDAP, Kerberos, DNS and GC. Default: empty (no ingress from outside the VCN)."
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for c in var.allowed_cidrs : can(cidrnetmask(c)) && c != "0.0.0.0/0"])
    error_message = "allowed_cidrs must contain valid IPv4 CIDR blocks (e.g. 203.0.113.10/32); 0.0.0.0/0 is not allowed."
  }
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

variable "company_name" {
  type        = string
  description = "Company name for AD lab (used in OU and user creation)."
  default     = "OraDBA Labs"
}

variable "ad_lab_scripts_ref" {
  type        = string
  description = "Full 40-character commit SHA of github.com/oehrlis/ad-lab to download. A branch name is not accepted: it would run moving code as Administrator."
  default     = "3b152c02c12a5d0b9c94f0cef98e877d616c1d54"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9a-f]{40}$", var.ad_lab_scripts_ref))
    error_message = "ad_lab_scripts_ref must be a full 40-character lowercase commit SHA."
  }
}

variable "ad_lab_scripts_sha256" {
  type        = string
  description = "Expected SHA-256 of the ad-lab archive for ad_lab_scripts_ref. Empty string skips the check. Update together with ad_lab_scripts_ref."
  default     = "8d7ebbf3855e83341aa7cd498185f1396ac1f96afd6dc057c0ab5d19bd2e5c8f"
  nullable    = false

  validation {
    condition     = var.ad_lab_scripts_sha256 == "" || can(regex("^[0-9a-f]{64}$", var.ad_lab_scripts_sha256))
    error_message = "ad_lab_scripts_sha256 must be empty or a 64-character lowercase hex SHA-256."
  }
}

variable "admin_password_secret" {
  type        = string
  sensitive   = true
  description = "Administrator password for the Windows instance. Pass via TF_VAR or op run -- terraform apply."
}

# --- EOF ----------------------------------------------------------------------
