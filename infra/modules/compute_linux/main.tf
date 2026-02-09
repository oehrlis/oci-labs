# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Create a Linux compute instance with optional data volume for OCI
#              lab deployments.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "os_image" {
  compartment_id           = var.compartment_ocid
  operating_system         = var.os_name
  operating_system_version = var.os_version
  shape                    = var.shape

  sort_by    = "TIMECREATED"
  sort_order = "DESC"
}

resource "oci_core_instance" "this" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid

  display_name = var.instance_name
  shape        = var.shape

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.os_image.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_gbs
  }

  agent_config {
    is_management_disabled = false
    is_monitoring_disabled = false

    plugins_config {
      name          = "Bastion"
      desired_state = "ENABLED"
    }
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = false
    hostname_label   = var.instance_name
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    # user_data kommt bereits base64-encoded aus dem Stack
    user_data = var.user_data
  }
}

resource "oci_core_volume" "data" {
  count = var.enable_data_volume ? 1 : 0

  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "${var.instance_name}-data"
  size_in_gbs         = var.data_volume_size_gbs
}

resource "oci_core_volume_attachment" "data_attach" {
  count = var.enable_data_volume ? 1 : 0

  #compartment_id  = var.compartment_ocid
  instance_id     = oci_core_instance.this.id
  volume_id       = oci_core_volume.data[0].id
  attachment_type = "paravirtualized"
}

# --- EOF ----------------------------------------------------------------------
