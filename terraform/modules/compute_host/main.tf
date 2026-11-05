# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.11.05
# Version....: v0.1.0
# Purpose....: N identical compute hosts on an existing subnet, with an
#              instance NSG and optional data volume per host.
# Notes......: Product-neutral: the caller supplies cloud-init, component name,
#              role tags and extra NSG rules. Accenture standards enforced:
#              PV encryption in transit, IMDSv2.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.11.05 oehrli - initial version (extracted from oracle_db_host)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Locals
# ------------------------------------------------------------------------------

locals {
  # Host keys: "01", "02", ... - used as for_each key and name suffix
  host_keys = toset([for i in range(1, var.host_count + 1) : format("%02d", i)])

  # cloud-init is optional and per host: the template gets the host's own name
  user_data = {
    for k in local.host_keys : k => var.user_data_template == "" ? {} : {
      user_data = base64encode(templatefile(var.user_data_template, merge(var.user_data_vars, {
        hostname = "${var.hostname_prefix}${k}"
      })))
    }
  }
}

# ------------------------------------------------------------------------------
# Compute instances
# ------------------------------------------------------------------------------

resource "oci_core_instance" "this" {
  for_each = local.host_keys

  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = "ci-${var.lab_name_core}-${var.component}-${each.key}"
  shape               = var.shape

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_gbs
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = var.assign_public_ip
    hostname_label   = "${var.hostname_prefix}${each.key}"
    nsg_ids          = [oci_core_network_security_group.this.id]
  }

  source_details {
    source_type             = "image"
    source_id               = var.instance_image_ocid
    boot_volume_size_in_gbs = var.boot_volume_size_gbs
  }

  metadata = merge(
    { ssh_authorized_keys = join("\n", [for k in var.ssh_public_keys : trimspace(k)]) },
    local.user_data[each.key]
  )

  # Accenture OCI security standard: IMDSv2 only
  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  # Accenture OCI security standard: encrypt paravirtualized volume traffic
  is_pv_encryption_in_transit_enabled = true

  # Image OCIDs change when Oracle publishes a new OL build - do not force a
  # replacement of a running lab host just because the lookup moved on.
  #
  # ssh_authorized_keys likewise: cloud-init reads it on the first boot only,
  # so a changed workstation key cannot reach a running host through Terraform
  # anyway - the only effect would be a replacement that destroys the host.
  # To really roll the keys, replace the host on purpose:
  #   terraform apply -replace='module.<m>.oci_core_instance.this["01"]'
  lifecycle {
    ignore_changes = [source_details[0].source_id, metadata["ssh_authorized_keys"]]
  }

  freeform_tags = merge(var.freeform_tags, { role = var.role_tag })
}

# ------------------------------------------------------------------------------
# Optional data volume per host
# ------------------------------------------------------------------------------

resource "oci_core_volume" "data" {
  for_each = var.attach_data_volume ? local.host_keys : toset([])

  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = "bv-${var.lab_name_core}-${var.component}-${each.key}-data-01"

  size_in_gbs          = var.data_volume_size_gbs
  vpus_per_gb          = var.data_volume_vpus_per_gb
  is_auto_tune_enabled = false

  freeform_tags = merge(var.freeform_tags, { role = var.data_role_tag })
}

resource "oci_core_volume_attachment" "data" {
  for_each = var.attach_data_volume ? local.host_keys : toset([])

  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.this[each.key].id
  volume_id       = oci_core_volume.data[each.key].id

  display_name = "va-${var.lab_name_core}-${var.component}-${each.key}-data-01"

  # Accenture OCI security standard: encrypt block volume traffic in transit
  is_pv_encryption_in_transit_enabled = true
}

# --- EOF ----------------------------------------------------------------------
