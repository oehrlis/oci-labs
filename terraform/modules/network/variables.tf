# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: variables.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Input variables for the network module (VCN, subnets, gateways, flow logs).
# Notes......: Aligns with naming module outputs for consistent resource naming.
# Reference..: https://github.com/oehrlis/oci-labs-infra
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

# OCI compartment
variable "compartment_ocid" {
  type        = string
  description = "Compartment OCID where the network resources will be created."
}

# From naming module: e.g. chzh-l-odb19eng-01
variable "lab_name_core" {
  type        = string
  description = "Core lab name segment used for resource names."
}

variable "freeform_tags" {
  type        = map(string)
  description = "Base freeform tags applied to all network resources."
  default     = {}
}

variable "vcn_cidr" {
  type        = string
  description = "CIDR block for the lab VCN."
  default     = "10.19.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR block for the public subnet (jumphost, bastion, etc.)."
  default     = "10.19.10.0/24"
}

variable "private_subnet_cidr" {
  type        = string
  description = "CIDR block for the private subnet (generic/private hosts)."
  default     = "10.19.20.0/24"
}

variable "db_subnet_cidr" {
  type        = string
  description = "CIDR block for the DB subnet."
  default     = "10.19.30.0/24"
}

variable "app_subnet_cidr" {
  type        = string
  description = "CIDR block for the App subnet."
  default     = "10.19.40.0/24"
}

variable "internet_gateway_enabled" {
  type        = bool
  description = "Whether to create an Internet Gateway for the VCN."
  default     = true
}

variable "nat_gateway_enabled" {
  type        = bool
  description = "Whether to create a NAT Gateway for private subnets."
  default     = true
}

variable "enable_flow_logs" {
  type        = bool
  description = "Enable VCN flow logs via Logging service."
  default     = true
}

variable "flow_log_retention_duration" {
  type        = number
  description = "Log retention duration in days (in 30-day increments: 30, 60, 90, ...)."
  default     = 90
}

# --- Security settings for public subnet ---

variable "allowed_ssh_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to access SSH on the public subnet."
  default     = ["0.0.0.0/0"]
}

variable "ssh_port" {
  type        = number
  description = "SSH port exposed on the jumphost via public subnet."
  default     = 22
}

variable "allowed_wireguard_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to access WireGuard on the public subnet."
  default     = ["0.0.0.0/0"]
}

variable "wireguard_port" {
  type        = number
  description = "WireGuard UDP port exposed on the public subnet."
  default     = 51820
}

variable "allow_public_http_https" {
  type        = bool
  description = "Whether to allow inbound HTTP/HTTPS to the public subnet."
  default     = false
}

# --- EOF ----------------------------------------------------------------------
