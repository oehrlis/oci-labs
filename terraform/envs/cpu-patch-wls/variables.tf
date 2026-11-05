# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: variables.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.10.23
# Version....: v0.1.0
# Purpose....: Input variables for the cpu-patch-wls stack.
# Notes......: Stack-code "cpuwl". Network and Bastion come from envs/core, so
#              this stack has no network variables. ssh_public_key via
#              TF_VAR_ssh_public_key, from 1Password (op read) or a .env file.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.10.23 oehrli - initial version, derived from cpu-patch-test
# ------------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Provider / tenancy
# -----------------------------------------------------------------------------

variable "oci_config_profile" {
  type        = string
  description = "Profile in ~/.oci/config used by the OCI provider."
  default     = "DEFAULT"
}

variable "compartment_ocid" {
  type        = string
  description = <<-EOT
    OCID of the existing compartment where the lab resources will be created.
    This is the base compartment for the whole stack - Terraform never creates
    or deletes a compartment, so a destroy leaves nothing behind.
    Set either this or compartment_name.
  EOT
  default     = null

  validation {
    condition     = var.compartment_ocid != null || var.compartment_name != null
    error_message = "Set compartment_ocid, or set compartment_name together with tenancy_ocid."
  }
}

variable "compartment_name" {
  type        = string
  description = <<-EOT
    Name of an existing compartment, looked up instead of pasting an OCID.
    Requires tenancy_ocid. Ignored when compartment_ocid is set.
  EOT
  default     = null

  validation {
    condition     = var.compartment_name == null || var.tenancy_ocid != null
    error_message = "compartment_name requires tenancy_ocid so the lookup has a root to search from."
  }
}

variable "tenancy_ocid" {
  type        = string
  description = "Tenancy OCID. Required only when resolving compartment_name."
  default     = null
}

# -----------------------------------------------------------------------------
# Core / naming variables
# -----------------------------------------------------------------------------

variable "region_key" {
  type        = string
  description = "OCI region key used in resource names, e.g. chzh, eu-frn."
  default     = "chzh"
}

variable "environment_code" {
  type        = string
  description = "Environment code used in resource names, e.g. l (lab), ws (workshop)."
  default     = "l"
}

variable "stack_code" {
  type        = string
  description = "Stack code for the WebLogic CPU patch test lab."
  default     = "cpuwl"
}

variable "lab_instance" {
  type        = number
  description = "Numeric index for the lab instance (1 -> 01). Distinguishes parallel labs."
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
# Network variables - the network itself comes from envs/core
# -----------------------------------------------------------------------------

variable "allowed_ssh_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach SSH from outside the VCN. Empty = no external SSH. Set to your own IP/32."
  default     = []
}

# -----------------------------------------------------------------------------
# DB host instance variables
# -----------------------------------------------------------------------------

variable "lab_count" {
  type        = number
  description = "Number of identical DB lab hosts. 1 for a CPU test, N for a workshop."
  default     = 1
}

variable "instance_image_ocid" {
  type        = string
  description = "Optional: explicit Oracle Linux image OCID. When set, skips the image lookup."
  default     = null
}

variable "ol_version" {
  type        = string
  description = "Oracle Linux version for the image lookup."
  default     = "9"
}

variable "db_host_shape" {
  type        = string
  description = "Compute shape for the DB hosts. Must be x86 - no ARM release for this flow."
  default     = "VM.Standard.E4.Flex"
}

variable "db_host_ocpus" {
  type        = number
  description = <<-EOT
    OCPUs per DB host. 8 rather than 2 because the slowest part of building the
    lab is CPU-bound and largely serial: dbca's datapatch run against CDB$ROOT,
    PDB$SEED and each user PDB, plus PL/SQL recompilation. Measured on 2 OCPU the
    database creation alone took ~50 minutes.
    Changing this on a running instance triggers a resize and a reboot - do not
    apply it while dbca or AutoUpgrade is running.
  EOT
  default     = 8
}

variable "db_host_memory_gbs" {
  type        = number
  description = "Memory in GB per DB host. Keep at least 2 GB per OCPU for E4.Flex."
  default     = 32
}

variable "db_host_boot_volume_size_gbs" {
  type        = number
  description = "Boot volume size in GB. Holds base + target ORACLE_HOME plus install media."
  default     = 200
}

variable "attach_data_volume" {
  type        = bool
  description = "Attach an extra block volume per host (engineering labs; not needed for CPU tests)."
  default     = false
}

variable "data_volume_size_gbs" {
  type        = number
  description = "Size in GB of the optional data volume per host."
  default     = 100
}

variable "ssh_public_key_files" {
  type        = list(string)
  description = <<-EOT
    Existing public key files on the workstation to authorise for the opc user.
    "~" is expanded. Default is the personal default key, so a plain
    "terraform plan" needs no environment variables at all.
  EOT
  default     = ["~/.ssh/id_ed25519.pub"]
}

variable "ssh_public_key" {
  type        = string
  description = <<-EOT
    Optional additional public key as a literal string, for a key that is not
    on disk - for example from 1Password:
      export TF_VAR_ssh_public_key=$(op read "op://secrets/<item>/public key")
  EOT
  default     = null
}

variable "generate_lab_keypair" {
  type        = bool
  description = <<-EOT
    Generate a dedicated ed25519 keypair for this lab lifecycle. The private key
    is written to .ssh/cpu-lab (mode 0600, git-ignored) and the public key is
    authorised alongside the personal key. The private key is also kept in the
    Terraform state, which is local and git-ignored.
  EOT
  default     = true
}

variable "lab_keypair_name" {
  type        = string
  description = "Base filename of the generated keypair below .ssh/ in this directory."
  default     = "cpu-lab"
}

variable "enable_auto_stop" {
  type        = bool
  description = "Create a daily auto-stop schedule. Safe default: true (nightly STOP_RESOURCE at 18:00 UTC). AutoUpgrade runs must set enable_auto_stop = false explicitly - a mid-run stop corrupts the patch attempt."
  default     = true
}

variable "auto_stop_cron" {
  type        = string
  description = "Cron expression (UTC) for the auto-stop schedule. Only used when enable_auto_stop = true."
  default     = "0 18 * * *"
}

# -----------------------------------------------------------------------------
# Filesystem layout on the WebLogic host
# -----------------------------------------------------------------------------
# Consumed by the wls_engineering role via the generated inventory.
# Kept in Terraform so a lab is described by exactly one set of variables.

variable "ansible_python_interpreter" {
  type        = string
  description = <<-EOT
    Python interpreter Ansible uses on the lab host. Oracle Linux 8 ships 3.6,
    which ansible-core 2.18+ rejects on a managed node, so the playbook
    bootstraps python3.11 from ol8_appstream.
  EOT
  default     = "/usr/bin/python3.11"
}




variable "db_oracle_root" {
  type        = string
  description = <<-EOT
    ORACLE_ROOT - holds ORACLE_BASE and the Oracle binaries. Kept separate from
    the data and archive roots so any of them can be moved onto a dedicated
    volume later without changing a single path.
  EOT
  default     = "/u00"
}

variable "db_oracle_data" {
  type        = string
  description = "Data root - datafiles live below this."
  default     = "/u01"
}

variable "db_oracle_arch" {
  type        = string
  description = "Archive root - archived redo and the fast recovery area."
  default     = "/u02"
}

variable "db_oracle_base" {
  type        = string
  description = "ORACLE_BASE on the lab host. Empty = derived from db_oracle_root."
  default     = ""
}



# -----------------------------------------------------------------------------
# Shared core (envs/core)
# -----------------------------------------------------------------------------

variable "core_state_path" {
  type        = string
  description = <<-EOT
    Path to the terraform.tfstate of envs/core. VCN, DB subnet and Bastion are
    read from there - this stack never creates or destroys network resources.
    Relative paths resolve from this directory.
  EOT
  default     = "../core/terraform.tfstate"
}


# --- EOF ----------------------------------------------------------------------
