# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Date.......: 2026.08.23
# Version....: v0.1.0
# Purpose....: The long-lived resources several lab stacks share: network,
#              artifact bucket and Bastion.
# Notes......: Composed as a module rather than only an env so it can be used
#              two ways. envs/core instantiates it with its own state - the
#              shared, long-lived variant. A lab env can instantiate it directly
#              when no core is found, which is the implicit build.
#
#              What makes the implicit build safe is ownership, not the code:
#              a lookup that finds a core consumes it and never destroys it;
#              a lookup that finds nothing builds one in the caller's own state
#              and owns it. Everything here carries core_owner so a consumer can
#              tell the two apart and warn before it depends on another lab.
#
#              Tenancy portability follows from the same split. A new tenancy -
#              the ACE tenancy, a customer tenancy for a workshop - needs a
#              profile in ~/.oci/config, a .env, and one apply of envs/core.
#              No pre-seeded resources.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------

locals {
  core_tags = merge(var.freeform_tags, {
    core_owner = var.core_owner
  })
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

module "network" {
  source = "../network"

  compartment_ocid = var.compartment_ocid
  lab_name_core    = var.lab_name_core
  freeform_tags    = local.core_tags

  vcn_cidr            = var.vcn_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  db_subnet_cidr      = var.db_subnet_cidr

  # App and Windows subnets belong to the stacks that need them; creating them
  # here would also force their default CIDRs, which sit outside this VCN.
  create_app_subnet     = false
  create_windows_subnet = false

  internet_gateway_enabled = true
  nat_gateway_enabled      = true

  enable_flow_logs            = var.enable_flow_logs
  flow_log_retention_duration = var.flow_log_retention_duration

  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

# ---------------------------------------------------------------------------
# Artifact bucket
# ---------------------------------------------------------------------------
# Gold images and staged patch media. Off by default in a tenancy where the
# bucket predates Terraform - trivadisbdsxsp has carried "orarepo" outside any
# state since before this repository existed.

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_ocid
}

resource "oci_objectstorage_bucket" "artifacts" {
  count = var.manage_artifact_bucket ? 1 : 0

  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = var.artifact_bucket_name

  access_type           = "NoPublicAccess"
  storage_tier          = "Standard"
  versioning            = "Disabled"
  object_events_enabled = false

  freeform_tags = local.core_tags
}

# ---------------------------------------------------------------------------
# Bastion
# ---------------------------------------------------------------------------
# Port-forwarding sessions are authorised by IAM rather than by source IP, so
# moving between office WiFi and mobile stops mattering. Sessions are not
# durable - see the Makefile for why every check probes with a real command.

resource "oci_bastion_bastion" "core" {
  count = var.enable_bastion ? 1 : 0

  compartment_id   = var.compartment_ocid
  bastion_type     = "STANDARD"
  target_subnet_id = module.network.db_subnet_id

  # The name accepts only letters, digits and underscores.
  name = "bastion_${replace(var.lab_name_core, "-", "_")}"

  client_cidr_block_allow_list = var.bastion_client_cidrs
  max_session_ttl_in_seconds   = var.bastion_max_session_ttl

  freeform_tags = local.core_tags
}

# --- EOF ----------------------------------------------------------------------
