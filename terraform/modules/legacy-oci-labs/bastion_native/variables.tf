# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: variables.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Define inputs for the native bastion module.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

variable "compartment_ocid" {
  type = string
}

variable "target_subnet_id" {
  type = string
}

variable "bastion_name" {
  type    = string
  default = "db19c-baseline-bastion"
}

variable "client_cidr_block_allow_list" {
  type        = list(string)
  description = "List of CIDR blocks allowed to reach the bastion"
  default     = ["0.0.0.0/0"] # MVP: offen, später enger machen
}

# --- EOF ----------------------------------------------------------------------
