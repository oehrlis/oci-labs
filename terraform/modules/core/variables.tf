# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: variables.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Date.......: 2026.08.23
# Version....: v0.1.0
# Purpose....: Inputs for the core module - the long-lived resources several
#              labs share and a tenancy switch has to reproduce.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------

variable "compartment_ocid" {
  description = "Compartment the core resources live in."
  type        = string
}

variable "lab_name_core" {
  description = "Naming core segment from the naming module."
  type        = string
}

variable "freeform_tags" {
  description = "Base freeform tags. core_owner is added by the module."
  type        = map(string)
  default     = {}
}

# Ownership is what makes implicit creation safe. Resources built by envs/core
# carry core_owner = "core" and no lab env ever destroys them. A lab that builds
# its own core tags it with its own stack name, which makes an orphan visible
# instead of surprising.
variable "core_owner" {
  description = "Owner tag value. \"core\" for the shared deployment, otherwise the consuming stack name."
  type        = string
  default     = "core"
}

variable "vcn_cidr" {
  description = "VCN CIDR block."
  type        = string
  default     = "10.29.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR."
  type        = string
  default     = "10.29.10.0/24"
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR."
  type        = string
  default     = "10.29.20.0/24"
}

variable "db_subnet_cidr" {
  description = "Database subnet CIDR."
  type        = string
  default     = "10.29.30.0/24"
}

variable "allowed_ssh_cidrs" {
  description = "Source CIDRs allowed to reach SSH on the public subnet."
  type        = list(string)
  default     = []
}

variable "enable_flow_logs" {
  description = "Enable VCN flow logs. Required by the Accenture OCI standards."
  type        = bool
  default     = true
}

variable "flow_log_retention_duration" {
  description = "Flow log retention in days."
  type        = number
  default     = 30
}

# The artifact bucket holds gold images and staged patch media. It is the one
# core resource that does not travel to another tenancy - a gold image is
# rebuilt in 20 minutes, which is cheaper than any replication mechanism.
variable "manage_artifact_bucket" {
  description = "Create and manage the artifact bucket. Set false when it already exists and is managed elsewhere."
  type        = bool
  default     = true
}

variable "artifact_bucket_name" {
  description = "Name of the artifact bucket for gold images and patch media."
  type        = string
  default     = "orarepo"
}

variable "enable_bastion" {
  description = "Create an OCI Bastion. IAM-authorised access without an IP allow-list."
  type        = bool
  default     = true
}

variable "bastion_client_cidrs" {
  description = "Client CIDRs allowed to open a Bastion session."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "bastion_max_session_ttl" {
  description = "Maximum Bastion session TTL in seconds."
  type        = number
  default     = 10800
}
