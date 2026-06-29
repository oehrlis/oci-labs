# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.06.26
# Version....: v0.1.0
# Purpose....: Provision a Windows Server 2022 AD instance with cloudbase-init.
# Notes......: Stack-code "windc". Requires x86 shape (VM.Standard3.Flex).
#              admin_password_secret is base64-encoded for safe tftpl handling.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.06.26 oehrli - initial version
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Locals
# ------------------------------------------------------------------------------

locals {
  instance_display_name = "ci-${var.lab_name_core}-dc-01"
  hostname_label        = "windc01"

  netbios_name = upper(split(".", var.domain_name)[0])

  cloud_init = templatefile("${path.module}/templates/windows_ad-cloudinit.yaml.tftpl", {
    admin_password_b64 = base64encode(var.admin_password_secret)
    domain_name        = var.domain_name
    netbios_name       = local.netbios_name
    company_name       = var.company_name
    lab_name_core      = var.lab_name_core
  })
}

# ------------------------------------------------------------------------------
# Windows AD Compute Instance
# ------------------------------------------------------------------------------

resource "oci_core_instance" "windows_ad" {
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
    hostname_label   = local.hostname_label
    nsg_ids          = [oci_core_network_security_group.windows_ad.id]
  }

  source_details {
    source_type             = "image"
    source_id               = var.instance_image_ocid
    boot_volume_size_in_gbs = var.boot_volume_size_gbs
  }

  metadata = {
    ssh_authorized_keys = var.ssh_authorized_keys
    user_data           = base64encode(local.cloud_init)
  }

  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  is_pv_encryption_in_transit_enabled = true

  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }

  freeform_tags = var.freeform_tags
}

# --- EOF ----------------------------------------------------------------------
