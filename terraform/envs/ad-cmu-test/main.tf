# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.06.26
# Version....: v0.1.0
# Purpose....: Assemble the ad-cmu-test stack: naming, network, Windows AD.
# Notes......: Stack-code "windc". Image lookup targets Windows Server 2022 x86.
#              No jumphost in this stack - connect via WireGuard/bastion.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.06.26 oehrli - initial version
# ------------------------------------------------------------------------------

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
  lab_name_core      = module.naming.lab_name_core
  base_freeform_tags = module.naming.base_freeform_tags
}

# ---------------------------------------------------------------------------
# Availability domain
# ---------------------------------------------------------------------------

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

locals {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

module "network" {
  source = "../../modules/network"

  compartment_ocid = var.compartment_ocid

  lab_name_core = local.lab_name_core
  freeform_tags = local.base_freeform_tags

  vcn_cidr            = var.vcn_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  windows_subnet_cidr = var.windows_subnet_cidr

  internet_gateway_enabled = true
  nat_gateway_enabled      = true

  enable_flow_logs            = var.enable_flow_logs
  flow_log_retention_duration = var.flow_log_retention_duration

  allowed_rdp_cidrs = var.allowed_rdp_cidrs
}

# ---------------------------------------------------------------------------
# Windows Server 2022 image lookup (x86 / VM.Standard3.Flex)
# ---------------------------------------------------------------------------

data "oci_core_images" "windows" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Windows"
  operating_system_version = var.windows_os_version
  shape                    = var.windows_shape

  sort_by    = "TIMECREATED"
  sort_order = "DESC"
}

# ---------------------------------------------------------------------------
# Windows AD instance
# ---------------------------------------------------------------------------

module "windows_ad" {
  source = "../../modules/windows_ad"

  compartment_ocid    = var.compartment_ocid
  availability_domain = local.availability_domain
  vcn_id              = module.network.vcn_id
  subnet_id           = module.network.windows_subnet_id

  lab_name_core = local.lab_name_core
  freeform_tags = local.base_freeform_tags

  instance_image_ocid = data.oci_core_images.windows.images[0].id

  shape      = var.windows_shape
  ocpus      = var.windows_ocpus
  memory_gbs = var.windows_memory_gbs

  boot_volume_size_gbs = var.windows_boot_volume_size_gbs
  assign_public_ip     = var.assign_windows_public_ip

  domain_name           = var.domain_name
  admin_password_secret = var.admin_password_secret
}

# --- EOF ----------------------------------------------------------------------
