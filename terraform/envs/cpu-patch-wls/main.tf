# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.10.23
# Version....: v0.1.0
# Purpose....: Assemble the cpu-patch-wls stack: naming and one WebLogic host
#              on the shared core (envs/core) - VCN, DB subnet and Bastion.
# Notes......: Stack-code "cpuwl". All WLS versions on one host, side by side. One VCN and one Bastion for the CPU tests,
#              one stack per product/release on top (db19, db26, wlsXX). This
#              stack never creates or destroys a network resource; its destroy
#              removes the host, keys and inventory only.
#              Throw-away lab: build, patch, verify, destroy. The Ansible
#              inventory is generated into ansible/inventories/generated/
#              (git-ignored) so host IPs never reach the repository.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.10.23 oehrli - initial version, derived from cpu-patch-test
# ------------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Base compartment resolution
# ---------------------------------------------------------------------------
# Terraform never creates or deletes a compartment - it only deploys into an
# existing one, so a destroy leaves no compartment behind (OCI deletes
# compartments asynchronously and they linger in DELETED state).
# Supply either compartment_ocid directly, or compartment_name + tenancy_ocid.

data "oci_identity_compartments" "by_name" {
  count = var.compartment_ocid == null && var.compartment_name != null ? 1 : 0

  compartment_id            = var.tenancy_ocid
  compartment_id_in_subtree = true
  access_level              = "ACCESSIBLE"
  name                      = var.compartment_name
  state                     = "ACTIVE"
}

locals {
  # try() keeps a failed lookup as null so the precondition below reports it,
  # instead of coalesce failing first with an opaque function error.
  compartment_ocid = try(coalesce(
    var.compartment_ocid,
    try(one(data.oci_identity_compartments.by_name[0].compartments).id, null),
  ), null)
}

# A "check" block would only warn. A precondition errors, which is what we want
# before a single resource is created.
resource "terraform_data" "compartment_guard" {
  input = local.compartment_ocid

  lifecycle {
    precondition {
      condition = local.compartment_ocid != null
      error_message = join(" ", [
        "No base compartment resolved.",
        "compartment_name \"${coalesce(var.compartment_name, "<unset>")}\" matched",
        "no unique ACTIVE compartment below the given tenancy.",
        "Set compartment_ocid directly, or correct compartment_name.",
      ])
    }
  }
}

# ---------------------------------------------------------------------------
# Naming module
# ---------------------------------------------------------------------------

module "naming" {
  source = "../../modules/naming"

  region_key           = var.region_key
  environment_code     = var.environment_code
  stack_code           = var.stack_code
  lab_instance         = var.lab_instance
  common_freeform_tags = var.common_freeform_tags
}

locals {
  # Repository root. This stack sits three levels down
  # (terraform/envs/cpu-patch-wls), so count carefully - "../.." lands in
  # terraform/ and silently writes files to the wrong place.
  repo_root = abspath("${path.root}/../../..")

  lab_name_core      = module.naming.lab_name_core
  base_freeform_tags = module.naming.base_freeform_tags

  # ORACLE_BASE: an explicit value wins, otherwise derive. The WLS homes per
  # version are derived by the wls_engineering role.
  oracle_base = var.db_oracle_base != "" ? var.db_oracle_base : "${var.db_oracle_root}/app/oracle"
}

# ---------------------------------------------------------------------------
# Availability domain
# ---------------------------------------------------------------------------

data "oci_identity_availability_domains" "ads" {
  compartment_id = local.compartment_ocid
}

locals {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
}

# ---------------------------------------------------------------------------
# Shared core - VCN, DB subnet and Bastion from envs/core
# ---------------------------------------------------------------------------
# Read, never managed: the core carries core_owner = "core" and outlives every
# lab on top of it. The VCN CIDR is not a core output, so it is read from the
# VCN itself - adding an output would need an apply of the core stack.

data "terraform_remote_state" "core" {
  backend = "local"

  config = {
    path = abspath("${path.root}/${var.core_state_path}")
  }
}

locals {
  core_vcn_id       = data.terraform_remote_state.core.outputs.vcn_id
  core_db_subnet_id = data.terraform_remote_state.core.outputs.db_subnet_id
  core_bastion_id   = data.terraform_remote_state.core.outputs.bastion_id
}

data "oci_core_vcn" "core" {
  vcn_id = local.core_vcn_id
}

resource "terraform_data" "core_guard" {
  input = local.core_db_subnet_id

  lifecycle {
    precondition {
      condition     = local.core_db_subnet_id != null && local.core_bastion_id != null
      error_message = "envs/core has no DB subnet or no Bastion - apply envs/core with enable_bastion = true first."
    }
  }
}

# ---------------------------------------------------------------------------
# Oracle Linux image lookup (skipped when instance_image_ocid is set)
# ---------------------------------------------------------------------------

data "oci_core_images" "ol" {
  count = var.instance_image_ocid == null ? 1 : 0

  compartment_id           = local.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = var.ol_version
  shape                    = var.db_host_shape

  sort_by    = "TIMECREATED"
  sort_order = "DESC"
}

locals {
  ol_image_id = var.instance_image_ocid != null ? var.instance_image_ocid : data.oci_core_images.ol[0].images[0].id
}

# ---------------------------------------------------------------------------
# SSH keys
# ---------------------------------------------------------------------------
# Two sources are combined so the lab is reachable both with the operator's
# everyday key and with a throw-away keypair tied to this stack lifecycle:
#   1. ssh_public_key_files - existing keys on the workstation
#   2. generate_lab_keypair - an ed25519 pair created and written by Terraform
# An optional literal key (ssh_public_key) can be added on top.

resource "tls_private_key" "lab" {
  count = var.generate_lab_keypair ? 1 : 0

  algorithm = "ED25519"
}

resource "local_sensitive_file" "lab_private_key" {
  count = var.generate_lab_keypair ? 1 : 0

  filename             = "${abspath(path.root)}/.ssh/${var.lab_keypair_name}"
  content              = tls_private_key.lab[0].private_key_openssh
  file_permission      = "0600"
  directory_permission = "0700"
}

resource "local_file" "lab_public_key" {
  count = var.generate_lab_keypair ? 1 : 0

  filename             = "${abspath(path.root)}/.ssh/${var.lab_keypair_name}.pub"
  content              = "${trimspace(tls_private_key.lab[0].public_key_openssh)} ${local.lab_name_core}\n"
  file_permission      = "0644"
  directory_permission = "0700"
}

locals {
  ssh_key_files_expanded = [for f in var.ssh_public_key_files : pathexpand(f)]
  ssh_key_files_missing  = [for f in local.ssh_key_files_expanded : f if !fileexists(f)]

  ssh_keys_from_files = [
    for f in local.ssh_key_files_expanded : trimspace(file(f)) if fileexists(f)
  ]
  ssh_key_literal = var.ssh_public_key != null ? [trimspace(var.ssh_public_key)] : []
  # NOTE: do not add a comment to this key. Any change to the instance metadata
  # forces a replacement of the running host - a cosmetic comment is not worth
  # rebuilding the lab for. The .pub file written below does carry a comment.
  ssh_key_generated = var.generate_lab_keypair ? [trimspace(tls_private_key.lab[0].public_key_openssh)] : []

  ssh_public_keys = distinct(concat(
    local.ssh_keys_from_files,
    local.ssh_key_literal,
    local.ssh_key_generated,
  ))
}

# Do not silently drop a key file that was named but does not exist.
resource "terraform_data" "ssh_key_guard" {
  input = length(local.ssh_public_keys)

  lifecycle {
    precondition {
      condition = length(local.ssh_key_files_missing) == 0
      error_message = join(" ", [
        "These ssh_public_key_files do not exist:",
        join(", ", local.ssh_key_files_missing),
        "- correct the path, or remove the entry from ssh_public_key_files.",
      ])
    }

    precondition {
      condition = length(local.ssh_public_keys) > 0
      error_message = join(" ", [
        "No SSH public key resolved, the host would be unreachable.",
        "Set ssh_public_key_files, or set generate_lab_keypair = true.",
      ])
    }
  }
}

# ---------------------------------------------------------------------------
# WebLogic admin password (output db_sys_password, the name the make
# targets pass on as db19_sys_password)
# ---------------------------------------------------------------------------
# Generated here so no secret has to be managed for a throw-away lab. It lives
# in the Terraform state, which is git-ignored and local only. Oracle password
# rules: start with a letter, then letters, digits, and # _ $ only.

resource "random_password" "db_sys" {
  length           = 24
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  override_special = "#_"

  # Oracle rejects a password that does not start with a letter.
  keepers = {
    stack = var.stack_code
  }
}

# AutoUpgrade keystore password. Only needed when the keystore is created; with
# auto-login enabled (cwallet.sso) every later AutoUpgrade run is unattended.
# Oracle PKI rule: min 8 chars, letters plus digits or specials.
resource "random_password" "autoupgrade_keystore" {
  length           = 20
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  override_special = "#_"
}

locals {
  db_sys_password               = "Ora${random_password.db_sys.result}"
  autoupgrade_keystore_password = "Aup${random_password.autoupgrade_keystore.result}"
}

# ---------------------------------------------------------------------------
# Oracle DB lab hosts
# ---------------------------------------------------------------------------

module "oracle_db_host" {
  source = "../../modules/oracle_db_host"

  compartment_ocid    = local.compartment_ocid
  vcn_id              = local.core_vcn_id
  vcn_cidr            = data.oci_core_vcn.core.cidr_blocks[0]
  subnet_id           = local.core_db_subnet_id
  availability_domain = local.availability_domain

  lab_name_core = local.lab_name_core
  freeform_tags = local.base_freeform_tags

  host_count          = var.lab_count
  instance_image_ocid = local.ol_image_id

  shape                = var.db_host_shape
  ocpus                = var.db_host_ocpus
  memory_gbs           = var.db_host_memory_gbs
  boot_volume_size_gbs = var.db_host_boot_volume_size_gbs
  # The core DB subnet is private - access goes through the core Bastion.
  assign_public_ip = false

  attach_data_volume   = var.attach_data_volume
  data_volume_size_gbs = var.data_volume_size_gbs

  ssh_public_keys   = local.ssh_public_keys
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

# ---------------------------------------------------------------------------
# Resource Scheduler - optional daily auto-stop
# ---------------------------------------------------------------------------
# Off by default: a running AutoUpgrade job must not be interrupted. Enable
# only for a lab that idles overnight between test runs.

resource "oci_resource_scheduler_schedule" "db_host_stop" {
  count = var.enable_auto_stop ? 1 : 0

  compartment_id = local.compartment_ocid
  display_name   = "sched-${local.lab_name_core}-db-stop-01"
  description    = "Daily stop of the CPU patch lab hosts. Start manually before the next test run."
  action         = "STOP_RESOURCE"

  recurrence_type    = "CRON"
  recurrence_details = var.auto_stop_cron

  dynamic "resources" {
    for_each = module.oracle_db_host.instance_ids
    content {
      id = resources.value
    }
  }

  freeform_tags = local.base_freeform_tags
}

# ---------------------------------------------------------------------------
# Ansible inventory (generated, git-ignored)
# ---------------------------------------------------------------------------
# Written to ansible/inventories/generated/ so real host IPs never land in git.
# Consumed by: ansible-playbook -i ../../ansible/inventories/generated/...

locals {
  ansible_host_ips = module.oracle_db_host.private_ips

  ansible_inventory = yamlencode({
    # Own group name: the WLS variables in playbooks/group_vars/cpu_wls_hosts.yml
    # must never reach a database host.
    cpu_wls_hosts = {
      vars = merge({
        ansible_user               = "opc"
        ansible_python_interpreter = var.ansible_python_interpreter
        oracle_base                = local.oracle_base
        oracle_root                = var.db_oracle_root
        oracle_data                = var.db_oracle_data
        oracle_arch                = var.db_oracle_arch
        },
        # Point Ansible at the generated lab key so no --private-key or agent
        # entry is needed. Omitted when the keypair is not generated.
        var.generate_lab_keypair ? {
          ansible_ssh_private_key_file = local_sensitive_file.lab_private_key[0].filename
        } : {},
      )
      hosts = {
        for k, v in local.ansible_host_ips :
        module.oracle_db_host.hostnames[k] => {
          ansible_host = v
          host_index   = k
        }
      }
    }
  })
}

resource "local_file" "ansible_inventory" {
  filename        = "${local.repo_root}/ansible/inventories/generated/cpu-patch-wls/hosts.yml"
  file_permission = "0600"
  content         = "---\n# Generated by terraform/envs/cpu-patch-wls - do not edit by hand.\n${local.ansible_inventory}"
}

# --- EOF ----------------------------------------------------------------------
