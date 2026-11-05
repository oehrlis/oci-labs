# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: variables.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.11.05
# Version....: v0.1.0
# Purpose....: Inputs for the core layer template.
# Notes......: Names follow the OCI naming rule (naming module, scheme oci).
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------

variable "oci_config_profile" {
  type        = string
  description = "Profile in ~/.oci/config that selects the tenancy."
}

variable "region" {
  type        = string
  description = "OCI region name, e.g. eu-zurich-1. Also the region segment of the names (zrh)."
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment of the target. The core, the hosts and the state bucket live here."
}

variable "environment_code" {
  type        = string
  description = "Naming rule environment: lab, dev, test or prod."
  default     = "lab"
}

variable "stack_code" {
  type        = string
  description = "Stack segment of the names, e.g. cpu -> vcn-zrh-lab-cpu-net-01."
}

variable "freeform_tags" {
  type        = map(string)
  description = "Tags on every core resource, merged with the naming tags."
  default     = {}
}

variable "vcn_cidr" {
  type        = string
  description = "VCN CIDR (/16); public, private and DB subnets are its .10, .20 and .30 /24."
  default     = "10.29.0.0/16"

  validation {
    condition     = can(cidrsubnet(var.vcn_cidr, 8, 30)) && endswith(var.vcn_cidr, "/16")
    error_message = "vcn_cidr must be a /16 network, e.g. 10.29.0.0/16."
  }
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  description = "External CIDRs allowed to SSH into the public subnet. Empty = Bastion only."
  default     = []
}

variable "enable_bastion" {
  type        = bool
  description = "OCI Bastion for port forwarding to private hosts (free)."
  default     = true
}

# --- EOF ----------------------------------------------------------------------
