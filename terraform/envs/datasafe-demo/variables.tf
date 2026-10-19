# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: variables.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.10.19
# Version....: v0.1.0
# Purpose....: Input variables for the datasafe-demo stack.
# Notes......: Stack-code "dsdemo". No secret is a variable here: the SYS
#              password is generated, the Data Safe service account secret
#              comes from 1Password at Ansible run time.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.10.19 oehrli - initial version
# ------------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Provider / tenancy
# -----------------------------------------------------------------------------

variable "oci_config_profile" {
  type        = string
  description = "Profile in ~/.oci/config used by the OCI provider (ACE tenancy for LRN6087)."
  default     = "DEFAULT"
}

variable "region" {
  type        = string
  description = "OCI region the stack is deployed to. Data Safe must be enabled in the same region."
  default     = "eu-zurich-1"
}

variable "compartment_ocid" {
  type        = string
  description = <<-EOT
    OCID of the existing compartment for the demo resources. Terraform never
    creates or deletes a compartment. Set either this or compartment_name.
  EOT
  default     = null

  validation {
    condition     = var.compartment_ocid != null || var.compartment_name != null
    error_message = "Set compartment_ocid, or set compartment_name together with tenancy_ocid."
  }
}

variable "compartment_name" {
  type        = string
  description = "Name of an existing compartment, looked up instead of an OCID. Requires tenancy_ocid."
  default     = null

  validation {
    condition     = var.compartment_name == null || var.tenancy_ocid != null
    error_message = "compartment_name requires tenancy_ocid so the lookup has a root to search from."
  }
}

variable "tenancy_ocid" {
  type        = string
  description = "Tenancy OCID. Required for compartment_name and for enable_instance_principal."
  default     = null
}

# -----------------------------------------------------------------------------
# Core / naming
# -----------------------------------------------------------------------------

variable "region_key" {
  type        = string
  description = "Region key used in resource names (zrh = eu-zurich-1)."
  default     = "zrh"
}

variable "environment_code" {
  type        = string
  description = "Environment code used in resource names."
  default     = "lab"
}

variable "stack_code" {
  type        = string
  description = "Stack code of the Data Safe demo."
  default     = "dsdemo"
}

variable "lab_instance" {
  type        = number
  description = "Numeric index of the lab instance (1 -> 01)."
  default     = 1
}

variable "common_freeform_tags" {
  type        = map(string)
  description = "Base freeform tags applied to all resources of this stack."
  default = {
    project = "oradba-labs"
    owner   = "oehrli"
    purpose = "lrn6087-demo"
  }
}

# -----------------------------------------------------------------------------
# Network (own VCN via the core module, core_owner = dsdemo)
# -----------------------------------------------------------------------------

variable "vcn_cidr" {
  type        = string
  description = "CIDR block for the demo VCN."
  default     = "10.31.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR block for the public subnet (unused by the host, required by the network module)."
  default     = "10.31.10.0/24"
}

variable "private_subnet_cidr" {
  type        = string
  description = "CIDR block for the private subnet."
  default     = "10.31.20.0/24"
}

variable "db_subnet_cidr" {
  type        = string
  description = "CIDR block for the private DB subnet - the demo host and the Bastion target live here."
  default     = "10.31.30.0/24"
}

variable "enable_flow_logs" {
  type        = bool
  description = "Enable VCN flow logs on all subnets (Accenture standard)."
  default     = true
}

variable "flow_log_retention_duration" {
  type        = number
  description = "Flow log retention in days (30-day increments)."
  default     = 30
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  description = "External CIDRs allowed to SSH. Empty = Bastion only (default)."
  default     = []
}

variable "egress_https_only" {
  type        = bool
  description = <<-EOT
    Limit the host NSG egress to TCP 443 plus intra-VCN. The on-premises
    connector only needs outbound HTTPS to Data Safe; dnf, the container
    registry and GitHub are HTTPS as well.
  EOT
  default     = true
}

# -----------------------------------------------------------------------------
# Bastion
# -----------------------------------------------------------------------------

variable "enable_bastion" {
  type        = bool
  description = "Create an OCI Bastion for the DB subnet. The host has no public IP."
  default     = true
}

variable "bastion_client_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to open a Bastion session (IAM-authenticated)."
  default     = ["0.0.0.0/0"]
}

variable "bastion_max_session_ttl" {
  type        = number
  description = "Maximum Bastion session lifetime in seconds (1800-10800)."
  default     = 10800
}

# -----------------------------------------------------------------------------
# Demo host
# -----------------------------------------------------------------------------

variable "instance_image_ocid" {
  type        = string
  description = "Optional explicit Oracle Linux 8 image OCID. When set, skips the image lookup."
  default     = null
}

variable "ol_version" {
  type        = string
  description = "Oracle Linux version for the image lookup."
  default     = "8"
}

variable "db_host_shape" {
  type        = string
  description = "Compute shape. x86 - the on-premises connector is tested on x86-64 only."
  default     = "VM.Standard.E4.Flex"
}

variable "db_host_ocpus" {
  type        = number
  description = "OCPUs of the demo host. Oracle AI Database Free uses at most 2 CPU threads."
  default     = 2
}

variable "db_host_memory_gbs" {
  type        = number
  description = "Memory in GB. Free caps the database at 2 GB RAM; the rest is podman, connector, page cache."
  default     = 16
}

variable "db_host_boot_volume_size_gbs" {
  type        = number
  description = "Boot volume size in GB. Holds the container image, oradata and the connector."
  default     = 100
}

variable "ssh_public_key_files" {
  type        = list(string)
  description = "Existing public key files on the workstation to authorise for opc. \"~\" is expanded."
  default     = ["~/.ssh/id_ed25519.pub"]
}

variable "ssh_public_key" {
  type        = string
  description = <<-EOT
    Optional additional public key as a literal string, e.g. from 1Password:
      export TF_VAR_ssh_public_key=$(op read "op://<vault>/<item>/public key")
  EOT
  default     = null
}

variable "generate_lab_keypair" {
  type        = bool
  description = "Generate a dedicated ed25519 keypair (.ssh/<lab_keypair_name>, git-ignored). The Bastion session uses it."
  default     = true
}

variable "lab_keypair_name" {
  type        = string
  description = "Base filename of the generated keypair below .ssh/ in this directory."
  default     = "dsdemo-lab"
}

variable "enable_auto_stop" {
  type        = bool
  description = <<-EOT
    Create a daily auto-stop schedule for the host. Safe default: true. A
    stopped host costs block storage only; start it before rehearsal,
    recording and the session.
  EOT
  default     = true
}

variable "auto_stop_cron" {
  type        = string
  description = <<-EOT
    Cron expression (UTC) for the auto-stop. 21:00 UTC is 23:00 CEST / 22:00
    CET and 14:00 PDT - after evening recordings in Switzerland and after the
    session on 2026-10-27 (08:00 PDT = 15:00 UTC).
  EOT
  default     = "0 21 * * *"
}

# -----------------------------------------------------------------------------
# Instance principal (optional) - lets ds_connector_create.sh run on the host
# -----------------------------------------------------------------------------

variable "enable_instance_principal" {
  type        = bool
  description = <<-EOT
    Create a dynamic group for the demo host plus a policy that lets it manage
    data-safe-family in the demo compartment. Needed when the connector is
    created on the host with ds_connector_create.sh (OCI create, bundle
    download and setup.py in one go). Requires tenancy_ocid and IAM rights at
    tenancy level. false = create the connector from the laptop and copy the
    bundle (runbook fallback).
  EOT
  default     = false

  validation {
    condition     = !var.enable_instance_principal || var.tenancy_ocid != null
    error_message = "enable_instance_principal requires tenancy_ocid (the dynamic group lives in the tenancy)."
  }
}

# -----------------------------------------------------------------------------
# Ansible layer - consumed via the generated inventory
# -----------------------------------------------------------------------------

variable "ansible_python_interpreter" {
  type        = string
  description = "Python on the host for Ansible and the connector setup.py (OL8 ships 3.6, too old for both)."
  default     = "/usr/bin/python3.11"
}

variable "oracle_sid" {
  type        = string
  description = "ORACLE_SID of the container database. Oracle AI Database Free only allows FREE."
  default     = "FREE"

  validation {
    condition     = var.oracle_sid == "FREE"
    error_message = "Oracle AI Database Free runs with ORACLE_SID FREE only."
  }
}

variable "demo_pdbs" {
  type        = list(string)
  description = "PDBs present at the start state (registered as targets together with CDB$ROOT)."
  default     = ["FREEPDB1", "ODBSEED", "ODBREPO"]
}

variable "demo_new_pdb" {
  type        = string
  description = "PDB created and registered live in demo step 2 (dropped again by reset.sh)."
  default     = "AIPDB1"
}

variable "ds_connector_name" {
  type        = string
  description = "Display name of the Data Safe on-premises connector (also the directory and systemd unit name)."
  default     = "dsc-zrh-lab-dsdemo-01"
}

variable "ds_connector_port" {
  type        = number
  description = "Local port of the connector CMAN. Not 1521 - podman publishes the database listener there."
  default     = 1561
}

# --- EOF ----------------------------------------------------------------------
