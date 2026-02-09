# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Provision a jumphost/gateway instance with cloud-init.
# Notes......: Uses lab_name_core for naming and inherits freeform tags.
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
  # Display name for the jumphost instance
  instance_display_name = "ci-${var.lab_name_core}-gw-01"

  # Rendered cloud-init template
  cloud_init = templatefile("${path.module}/templates/jumphost-cloudinit.yaml.tftpl", {
    ssh_authorized_keys = var.ssh_authorized_keys
    ansible_repo_url    = var.ansible_repo_url
    ansible_branch      = var.ansible_branch
    ansible_playbook    = var.ansible_playbook
    ssh_port            = var.ssh_port # Default 22, z.B. 16022 im Lab
    enable_wireguard    = var.enable_wireguard
    lab_name_core       = var.lab_name_core
  })
}

resource "oci_core_instance" "jumphost" {
  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = local.instance_display_name
  shape               = var.shape

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_gbs
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = var.assign_public_ip
    hostname_label   = "gw01"
  }

  source_details {
    source_type             = "image"
    source_id               = var.instance_image_ocid
    boot_volume_size_in_gbs = var.boot_volume_size_gbs
  }

  # ⇨ Hier: SSH-Key + Cloud-Init in die Instanz-Metadaten
  metadata = {
    ssh_authorized_keys = var.ssh_authorized_keys
    user_data           = base64encode(local.cloud_init)
  }

  instance_options {
    # disable the legacy (/v1) instance metadata service endpoints 
    are_legacy_imds_endpoints_disabled = true
  }

  # Whether to enable in-transit encryption for the data volume's paravirtualized attachment
  is_pv_encryption_in_transit_enabled = true

  # prevent the host from destroying and recreating itself if the image ocid changes 
  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }

  freeform_tags = var.freeform_tags
}

# --- EOF ----------------------------------------------------------------------
