# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.08.19
# Version....: v0.1.0
# Purpose....: Provision N identical Oracle Linux 8 hosts for Oracle DB labs.
# Notes......: Cloud-init stays minimal on purpose - OS prerequisites and the
#              Oracle software install are handled by Ansible (db19_engineering).
#              Accenture standards enforced: PV encryption in transit, IMDSv2.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.08.19 oehrli - initial version
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Locals
# ------------------------------------------------------------------------------

locals {
  # Host keys: "01", "02", ... - used as for_each key and name suffix
  host_keys = toset([for i in range(1, var.host_count + 1) : format("%02d", i)])

  # hostname_label must be alphanumeric only (OCI DNS label restriction)
  hostname_prefix = "oradb"
}

# ------------------------------------------------------------------------------
# Oracle DB compute instances
# ------------------------------------------------------------------------------

resource "oci_core_instance" "db_host" {
  for_each = local.host_keys

  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = "ci-${var.lab_name_core}-db-${each.key}"
  shape               = var.shape

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_gbs
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = var.assign_public_ip
    hostname_label   = "${local.hostname_prefix}${each.key}"
    nsg_ids          = [oci_core_network_security_group.db_host.id]
  }

  source_details {
    source_type             = "image"
    source_id               = var.instance_image_ocid
    boot_volume_size_in_gbs = var.boot_volume_size_gbs
  }

  metadata = {
    ssh_authorized_keys = join("\n", [for k in var.ssh_public_keys : trimspace(k)])
    user_data = base64encode(templatefile(
      "${path.module}/templates/oracle_db_host-cloudinit.yaml.tftpl",
      {
        hostname           = "${local.hostname_prefix}${each.key}"
        oradba_repo_url    = var.oradba_repo_url
        oradba_install_dir = var.oradba_install_dir
      }
    ))
  }

  # Accenture OCI security standard: IMDSv2 only
  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  # Accenture OCI security standard: encrypt paravirtualized volume traffic
  is_pv_encryption_in_transit_enabled = true

  # Image OCIDs change when Oracle publishes a new OL8 build - do not force
  # a replacement of a running lab host just because the lookup moved on.
  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }

  freeform_tags = merge(var.freeform_tags, { role = "oracle-db-host" })
}

# ------------------------------------------------------------------------------
# Optional data volume per host (engineering labs; off for CPU patch tests)
# ------------------------------------------------------------------------------

resource "oci_core_volume" "data" {
  for_each = var.attach_data_volume ? local.host_keys : toset([])

  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = "bv-${var.lab_name_core}-db-${each.key}-data-01"

  size_in_gbs          = var.data_volume_size_gbs
  vpus_per_gb          = var.data_volume_vpus_per_gb
  is_auto_tune_enabled = false

  freeform_tags = merge(var.freeform_tags, { role = "oracle-db-data" })
}

resource "oci_core_volume_attachment" "data" {
  for_each = var.attach_data_volume ? local.host_keys : toset([])

  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.db_host[each.key].id
  volume_id       = oci_core_volume.data[each.key].id

  display_name = "va-${var.lab_name_core}-db-${each.key}-data-01"

  # Accenture OCI security standard: encrypt block volume traffic in transit
  is_pv_encryption_in_transit_enabled = true
}

# --- EOF ----------------------------------------------------------------------
