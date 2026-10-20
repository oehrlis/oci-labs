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
  description = "OCPUs of the demo host. Two CDBs (19c and 26ai EE) plus connector and AutoUpgrade runs."
  default     = 4
}

variable "db_host_memory_gbs" {
  type        = number
  description = "Memory in GB. Both SGAs plus PGAs take about 9 GB, the rest is connector, OS and page cache."
  default     = 32
}

variable "db_host_boot_volume_size_gbs" {
  type        = number
  description = <<-EOT
    Boot volume size in GB. Holds /u00 (two ORACLE_HOMEs), /u02 (FRA) and the
    staged media in /opt/stage. Ansible grows the root filesystem to fill it.
  EOT
  default     = 150
}

variable "attach_data_volume" {
  type        = bool
  description = "Attach a block volume for the datafiles. Ansible formats it (xfs) and mounts it on /u01."
  default     = true
}

variable "data_volume_size_gbs" {
  type        = number
  description = "Size in GB of the data volume (/u01) - datafiles of CDB19 and CDB26 with all PDBs."
  default     = 100
}

variable "data_volume_vpus_per_gb" {
  type        = number
  description = "Data volume performance in VPUs/GB (0 = lower cost, 10 = balanced, 20 = high)."
  default     = 10
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

# -----------------------------------------------------------------------------
# Resource Scheduler - daily start and stop (cost)
# -----------------------------------------------------------------------------

variable "schedule_profile" {
  type        = string
  description = <<-EOT
    Working-hours profile for the daily START and STOP schedules: start 07:00,
    stop 22:00 local time, translated to UTC in locals (OCI cron is UTC).
      cest - Switzerland until 2026-10-24 (UTC+2): start 05:00, stop 20:00 UTC
      cet  - Switzerland from 2026-10-25 (UTC+1): start 06:00, stop 21:00 UTC
      pdt  - Las Vegas until 2026-11-01 (UTC-7): start 14:00, stop 05:00 UTC
             (the 22:00 PDT stop falls on the next UTC day)
      off  - no schedules, start and stop by hand only
    Switching the profile is a terraform apply (make dsdemo-plan / dsdemo-apply).
  EOT
  default     = "cest"

  validation {
    condition     = contains(["cest", "cet", "pdt", "off"], var.schedule_profile)
    error_message = "schedule_profile must be one of: cest, cet, pdt, off."
  }
}

variable "schedule_start_cron" {
  type        = string
  description = "Optional cron override (UTC) for the daily START. null = derived from schedule_profile."
  default     = null
}

variable "schedule_stop_cron" {
  type        = string
  description = "Optional cron override (UTC) for the daily STOP. null = derived from schedule_profile."
  default     = null
}

variable "create_scheduler_policy" {
  type        = bool
  description = <<-EOT
    Create the IAM policy that lets the two schedules start and stop the demo
    instance. Without such a policy a Resource Scheduler schedule runs but its
    work requests fail. Needs the right to manage policies in the compartment;
    set false when an existing policy already covers resourceschedule.
  EOT
  default     = true
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

variable "cdb19_name" {
  type        = string
  description = "ORACLE_SID / DB_NAME of the 19c EE container database."
  default     = "CDB19"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9]{0,7}$", var.cdb19_name))
    error_message = "cdb19_name must be 1-8 alphanumeric characters starting with a letter (DB_NAME limit)."
  }
}

variable "cdb19_pdbs" {
  type        = list(string)
  description = "PDBs of CDB19 at the start state (registered as targets together with its CDB$ROOT)."
  default     = ["PDB19A", "PDB19B"]
}

variable "cdb26_name" {
  type        = string
  description = "ORACLE_SID / DB_NAME of the 26ai EE container database. The live PDB is created here."
  default     = "CDB26"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9]{0,7}$", var.cdb26_name))
    error_message = "cdb26_name must be 1-8 alphanumeric characters starting with a letter (DB_NAME limit)."
  }
}

variable "cdb26_pdbs" {
  type        = list(string)
  description = "PDBs of CDB26 at the start state (registered as targets together with its CDB$ROOT)."
  default     = ["PDB26A", "PDB26B"]
}

variable "demo_new_pdb" {
  type        = string
  description = "PDB created in CDB26 and registered live in demo step 2 (dropped again by reset.sh)."
  default     = "AIPDB1"
}

variable "db19_ru" {
  type        = string
  description = <<-EOT
    Release Update of the 19c home. AutoUpgrade only downloads the current and
    the previous RU - raise it once a quarter. The 19c base image is never
    downloadable and has to be staged (make dsdemo-par).
  EOT
  default     = "19.32"
}

variable "db26_ru" {
  type        = string
  description = <<-EOT
    Release Update of the 26ai home, e.g. "23.26.2". Empty = the latest RU that
    AutoUpgrade resolves (patch=RU,OPATCH). Pin it after the first download.
  EOT
  default     = ""
}

variable "db26_install_method" {
  type        = string
  description = <<-EOT
    How the 26ai home is built:
      autoupgrade - AutoUpgrade create_home downloads the RU gold image from MOS
      zip         - install a staged OTN/eDelivery image zip (make dsdemo-par DB26_ZIP=1)
  EOT
  default     = "autoupgrade"

  validation {
    condition     = contains(["autoupgrade", "zip"], var.db26_install_method)
    error_message = "db26_install_method must be autoupgrade or zip."
  }
}

variable "ds_connector_name" {
  type        = string
  description = "Display name of the Data Safe on-premises connector (also the directory and systemd unit name)."
  default     = "dsc-zrh-lab-dsdemo-01"
}

variable "ds_connector_port" {
  type        = number
  description = "Local port of the connector CMAN. Not 1521 - the database listener listens there."
  default     = 1561
}

# --- EOF ----------------------------------------------------------------------
