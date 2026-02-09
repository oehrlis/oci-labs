# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: variables.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Input variables for DB19 engineering hosts.
# Notes......: Supports multiple hosts, naming via lab_name_core, and DB port options.
# Reference..: https://github.com/oehrlis/oci-labs-infra
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

# OCI compartment
variable "compartment_ocid" {
  type        = string
  description = "Compartment OCID where the DB19 engineering instances will be created."
}

# Availability domain for hosts
variable "availability_domain" {
  type        = string
  description = "Availability domain name for the DB19 engineering instances."
}

# Target subnet (typically DB subnet)
variable "subnet_id" {
  type        = string
  description = "Subnet OCID where the DB19 instances will be placed (typically DB subnet)."
}

# Core naming from naming module
variable "lab_name_core" {
  type        = string
  description = "Core lab name segment used in resource names."
}

# Base freeform tags
variable "freeform_tags" {
  type        = map(string)
  description = "Base freeform tags applied to all DB19 resources."
  default     = {}
}

# Compute shape
variable "shape" {
  type        = string
  description = "Shape for the DB19 instances."
  default     = "VM.Standard.E4.Flex"
}

# vCPU count
variable "ocpus" {
  type        = number
  description = "Number of OCPUs per DB19 instance."
  default     = 2
}

# Memory
variable "memory_gbs" {
  type        = number
  description = "Memory in GB per DB19 instance."
  default     = 16
}

# Public IP assignment (normally false for DB subnets)
variable "assign_public_ip" {
  type        = bool
  description = "Whether to assign a public IP to the DB instances (normally false for DB subnets)."
  default     = false
}

# Base image
variable "instance_image_ocid" {
  type        = string
  description = "Image OCID for the DB19 instances (e.g. Oracle Linux 8/9)."
}

# Boot volume
variable "boot_volume_size_gbs" {
  type        = number
  description = "Boot volume size in GB for DB19 instances."
  default     = 100
}

# Number of hosts
variable "db_host_count" {
  type        = number
  description = "Number of DB19 engineering hosts to create."
  default     = 1
}

# Hostname prefix
variable "hostname_prefix" {
  type        = string
  description = "Hostname prefix for DB19 hosts (used as dns/hostname label)."
  default     = "db19"
}

# SSH keys for opc
variable "ssh_authorized_keys" {
  type        = string
  description = "SSH public key(s) for the opc user."
}

# SSH port
variable "ssh_port" {
  type        = number
  description = "SSH port that the DB hosts listen on (internal, normally 22)."
  default     = 22
}

# Firewalld: open DB listener/OEM
variable "open_db_ports" {
  type        = bool
  description = "If true, open DB listener and OEM ports in firewalld."
  default     = true
}

# Listener port
variable "db_listener_port" {
  type        = number
  description = "TCP port for the Oracle listener."
  default     = 1521
}

# OEM/EM Express port
variable "db_oem_port" {
  type        = number
  description = "TCP port for EM Express / OEM console."
  default     = 5500
}

# --- EOF ----------------------------------------------------------------------
