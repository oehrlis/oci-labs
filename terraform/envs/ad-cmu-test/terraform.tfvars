# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: terraform.tfvars
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Date.......: 2026.06.26
# Purpose....: Variable values for ad-cmu-test stack.
# Notes......: NEVER commit secrets. admin_password_secret via:
#              export TF_VAR_admin_password_secret=$(op read "op://AI-DevOps/WinDC/password")
#              terraform apply
# ------------------------------------------------------------------------------

# Core - ACE Tenancy / cmp-oradba-labs (personal lab, 5000 credits/year)
# Profile: ACE (~/.oci/config)
# Tenancy: ocid1.tenancy.oc1..aaaaaaaaapv5xofkxzyd4nbshzwrghdg6i7gdvob7y6tyv6atcb2hd6irzbq
compartment_ocid = "ocid1.compartment.oc1..aaaaaaaaxq7bir4bjy3bzozyjd4idlvharoco3ww5jx5nzzvv6rhcypb6cfa"
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
domain_name                  = "oradba.ch"
company_name                 = "OraDBA Labs"
instance_image_ocid          = "ocid1.image.oc1.eu-zurich-1.aaaaaaaanrw7bmj2aeab2zvviznxrfvt4w5uxm2j6bmgikmbpp5j5iwbrclq"
windows_shape                = "VM.Standard.E4.Flex"
windows_ocpus                = 2
windows_memory_gbs           = 8
windows_boot_volume_size_gbs = 100
assign_windows_public_ip     = false

# admin_password_secret is NOT set here - use TF_VAR_admin_password_secret

# VPN / DRG - site-to-site IPSec (UDM home lab → OCI)
# DRG from deep-thought/terraform/oci/vpn; also add 10.19.0.0/16 to UDM remote networks
drg_id = "ocid1.drg.oc1.eu-zurich-1.aaaaaaaa6lag2i4uv64up6elwntezqd64xbtpcal5nqltps2cxculppgncka"
home_cidrs = [
  "192.168.1.0/24",  # Home LAN
  "10.8.0.0/24",     # WireGuard VPN clients (road)
]
