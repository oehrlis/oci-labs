# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Provision DB19 engineering hosts with cloud-init bootstrap.
# Notes......: Names derive from lab_name_core; tags inherit from freeform_tags.
# Reference..: https://github.com/oehrlis/oci-labs-infra
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Locals
# ------------------------------------------------------------------------------

locals {
  # ci-chzh-l-odb19eng-db-01, ci-...-db-02, ...
  instance_display_names = [
    for idx in range(var.db_host_count) :
    "ci-${var.lab_name_core}-db-${format("%02d", idx + 1)}"
  ]

  # Hostname labels: db19-01, db19-02, ...
  hostname_labels = [
    for idx in range(var.db_host_count) :
    "${var.hostname_prefix}${format("%02d", idx + 1)}"
  ]
}

resource "oci_core_instance" "db19" {
  count               = var.db_host_count
  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = local.instance_display_names[count.index]
  shape               = var.shape

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_gbs
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = var.assign_public_ip
    hostname_label   = local.hostname_labels[count.index]
  }

  source_details {
    source_type             = "image"
    source_id               = var.instance_image_ocid
    boot_volume_size_in_gbs = var.boot_volume_size_gbs
  }

  metadata = {
    user_data = base64encode(
      templatefile(
        "${path.module}/templates/db19-cloudinit.yaml.tftpl",
        {
          ssh_authorized_keys = var.ssh_authorized_keys
          ssh_port            = var.ssh_port
          open_db_ports       = var.open_db_ports
          db_listener_port    = var.db_listener_port
          db_oem_port         = var.db_oem_port
        }
      )
    )
  }

  freeform_tags = var.freeform_tags
}

# --- EOF ----------------------------------------------------------------------
