# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.10.19
# Version....: v0.1.0
# Purpose....: Assemble the datasafe-demo stack for LRN6087: naming, own core
#              (network + Bastion), one OL8 x86 host for the Oracle AI
#              Database 26ai Free container and the Data Safe connector.
# Notes......: Stack-code "dsdemo". Pattern follows envs/cpu-patch-test. The
#              core module is instantiated here with core_owner = "dsdemo",
#              so a destroy of this stack removes its own VCN and Bastion and
#              never touches a shared core. No compartment is created.
#              Podman, the container, the PDBs, odb_datasafe and the connector
#              are installed by Ansible (playbooks/lab-datasafe-demo.yml).
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.10.19 oehrli - initial version
# ------------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Base compartment resolution - existing compartment only
# ---------------------------------------------------------------------------

data "oci_identity_compartments" "by_name" {
  count = var.compartment_ocid == null && var.compartment_name != null ? 1 : 0

  compartment_id            = var.tenancy_ocid
  compartment_id_in_subtree = true
  access_level              = "ACCESSIBLE"
  name                      = var.compartment_name
  state                     = "ACTIVE"
}

locals {
  compartment_ocid = try(coalesce(
    var.compartment_ocid,
    try(one(data.oci_identity_compartments.by_name[0].compartments).id, null),
  ), null)
}

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
# Naming
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
  # terraform/envs/datasafe-demo -> three levels below the repository root.
  repo_root = abspath("${path.root}/../../..")

  lab_name_core      = module.naming.lab_name_core
  base_freeform_tags = module.naming.base_freeform_tags
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
# Core - own network and Bastion, owned by this stack
# ---------------------------------------------------------------------------
# A tenancy switch (ACE instead of the lab tenancy) needs no pre-seeded core.
# core_owner = "dsdemo" marks everything as belonging to this stack, so an
# orphan stays visible. The artifact bucket is not needed for this demo.

module "core" {
  source = "../../modules/core"

  compartment_ocid = local.compartment_ocid
  lab_name_core    = local.lab_name_core
  freeform_tags    = local.base_freeform_tags
  core_owner       = var.stack_code

  vcn_cidr            = var.vcn_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  db_subnet_cidr      = var.db_subnet_cidr

  allowed_ssh_cidrs           = var.allowed_ssh_cidrs
  enable_flow_logs            = var.enable_flow_logs
  flow_log_retention_duration = var.flow_log_retention_duration

  manage_artifact_bucket = false

  enable_bastion          = var.enable_bastion
  bastion_client_cidrs    = var.bastion_client_cidrs
  bastion_max_session_ttl = var.bastion_max_session_ttl
}

# ---------------------------------------------------------------------------
# Oracle Linux 8 image lookup (skipped when instance_image_ocid is set)
# ---------------------------------------------------------------------------

data "oci_core_images" "ol8" {
  count = var.instance_image_ocid == null ? 1 : 0

  compartment_id           = local.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = var.ol_version
  shape                    = var.db_host_shape

  sort_by    = "TIMECREATED"
  sort_order = "DESC"
}

locals {
  ol8_image_id = var.instance_image_ocid != null ? var.instance_image_ocid : data.oci_core_images.ol8[0].images[0].id
}

# ---------------------------------------------------------------------------
# SSH keys - personal key files plus a generated lab keypair
# ---------------------------------------------------------------------------

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
  # No comment on the key: a metadata change replaces the running host.
  ssh_key_generated = var.generate_lab_keypair ? [trimspace(tls_private_key.lab[0].public_key_openssh)] : []

  ssh_public_keys = distinct(concat(
    local.ssh_keys_from_files,
    local.ssh_key_literal,
    local.ssh_key_generated,
  ))
}

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
# Database SYS / SYSTEM / PDBADMIN password (ORACLE_PWD of the container)
# ---------------------------------------------------------------------------
# Generated so no secret has to be managed for a throw-away lab. Lives in the
# local, git-ignored state. Oracle rules: start with a letter, then letters,
# digits and # _ only.

resource "random_password" "db_sys" {
  length           = 24
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  override_special = "#_"
}

locals {
  db_sys_password = "Ora${random_password.db_sys.result}"
}

# ---------------------------------------------------------------------------
# Demo host
# ---------------------------------------------------------------------------

module "oracle_db_host" {
  source = "../../modules/oracle_db_host"

  compartment_ocid    = local.compartment_ocid
  vcn_id              = module.core.vcn_id
  vcn_cidr            = var.vcn_cidr
  subnet_id           = module.core.db_subnet_id
  availability_domain = local.availability_domain

  lab_name_core = local.lab_name_core
  freeform_tags = local.base_freeform_tags

  host_count          = 1
  instance_image_ocid = local.ol8_image_id

  shape                = var.db_host_shape
  ocpus                = var.db_host_ocpus
  memory_gbs           = var.db_host_memory_gbs
  boot_volume_size_gbs = var.db_host_boot_volume_size_gbs
  assign_public_ip     = false

  ssh_public_keys   = local.ssh_public_keys
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
  egress_https_only = var.egress_https_only
}

locals {
  db_host_id         = module.oracle_db_host.instance_ids["01"]
  db_host_private_ip = module.oracle_db_host.private_ips["01"]
  db_host_hostname   = module.oracle_db_host.hostnames["01"]
}

# ---------------------------------------------------------------------------
# Resource Scheduler - daily auto-stop (cost)
# ---------------------------------------------------------------------------

resource "oci_resource_scheduler_schedule" "db_host_stop" {
  count = var.enable_auto_stop ? 1 : 0

  compartment_id = local.compartment_ocid
  display_name   = "sched-${local.lab_name_core}-db-stop-01"
  description    = "Daily stop of the LRN6087 Data Safe demo host. Start manually before rehearsal or session."
  action         = "STOP_RESOURCE"

  recurrence_type    = "CRON"
  recurrence_details = var.auto_stop_cron

  resources {
    id = local.db_host_id
  }

  freeform_tags = local.base_freeform_tags
}

# ---------------------------------------------------------------------------
# Instance principal (optional)
# ---------------------------------------------------------------------------
# Lets ds_connector_create.sh call OCI from the host (create the connector,
# generate and download the bundle). Scoped to this one instance and this one
# compartment. Dynamic groups live in the tenancy - that is the only resource
# outside the demo compartment, and it goes away with terraform destroy.

resource "oci_identity_dynamic_group" "db_host" {
  count = var.enable_instance_principal ? 1 : 0

  compartment_id = var.tenancy_ocid
  name           = "dg-${local.lab_name_core}-db-01"
  description    = "LRN6087 Data Safe demo host (instance principal for the on-premises connector setup)"
  matching_rule  = "ALL {instance.id = '${local.db_host_id}'}"

  freeform_tags = local.base_freeform_tags
}

resource "oci_identity_policy" "db_host" {
  count = var.enable_instance_principal ? 1 : 0

  compartment_id = local.compartment_ocid
  name           = "pol-${local.lab_name_core}-db-01"
  description    = "LRN6087 Data Safe demo host may manage Data Safe in the demo compartment"
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.db_host[0].name} to manage data-safe-family in compartment id ${local.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.db_host[0].name} to read compartments in compartment id ${local.compartment_ocid}",
  ]

  freeform_tags = local.base_freeform_tags
}

# ---------------------------------------------------------------------------
# Ansible inventory (generated, git-ignored)
# ---------------------------------------------------------------------------
# Private IP only: every Ansible run goes through the Bastion tunnel
# (ansible_host=127.0.0.1, see docs/datasafe-demo.md).

locals {
  ansible_inventory = yamlencode({
    dsdemo_hosts = {
      vars = merge({
        ansible_user               = "opc"
        ansible_python_interpreter = var.ansible_python_interpreter
        oracle_sid                 = var.oracle_sid
        dsdemo_pdbs                = var.demo_pdbs
        dsdemo_new_pdb             = var.demo_new_pdb
        dsdemo_connector_name      = var.ds_connector_name
        dsdemo_connector_port      = var.ds_connector_port
        dsdemo_compartment_ocid    = local.compartment_ocid
        dsdemo_region              = var.region
        dsdemo_host_private_ip     = local.db_host_private_ip
        dsdemo_instance_principal  = var.enable_instance_principal
        },
        var.generate_lab_keypair ? {
          ansible_ssh_private_key_file = local_sensitive_file.lab_private_key[0].filename
        } : {},
      )
      hosts = {
        (local.db_host_hostname) = {
          ansible_host = local.db_host_private_ip
        }
      }
    }
  })
}

resource "local_file" "ansible_inventory" {
  filename        = "${local.repo_root}/ansible/inventories/generated/datasafe-demo/hosts.yml"
  file_permission = "0600"
  content         = "---\n# Generated by terraform/envs/datasafe-demo - do not edit by hand.\n${local.ansible_inventory}"
}

# --- EOF ----------------------------------------------------------------------
