# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: terraform.tfvars
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Date.......: 2026.06.26
# Purpose....: Variable values for ad-cmu-test stack.
# Notes......: NEVER commit secrets. admin_password_secret via:
#              export TF_VAR_admin_password_secret=$(op read "op://Private/WinDC/password")
#              terraform apply
# ------------------------------------------------------------------------------

# Core
compartment_ocid = "ocid1.compartment.oc1..aaaa"
region_key       = "chzh"
environment_code = "l"
stack_code       = "windc"
lab_instance     = 1

common_freeform_tags = {
  project = "oradba-labs"
  owner   = "oehrli"
  stack   = "windc"
}

# Network
vcn_cidr            = "10.19.0.0/16"
public_subnet_cidr  = "10.19.10.0/24"
private_subnet_cidr = "10.19.20.0/24"
windows_subnet_cidr = "10.19.50.0/24"

# Uncomment to allow direct RDP from your IP:
# allowed_rdp_cidrs = ["<your-ip>/32"]

# Windows AD
domain_name                  = "trivadislabs.com"
windows_shape                = "VM.Standard3.Flex"
windows_ocpus                = 2
windows_memory_gbs           = 16
windows_boot_volume_size_gbs = 100
assign_windows_public_ip     = false

# admin_password_secret is NOT set here - use TF_VAR_admin_password_secret
