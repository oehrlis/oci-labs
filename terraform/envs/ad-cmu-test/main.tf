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

  drg_id     = var.drg_id
  home_cidrs = var.home_cidrs
}

# ---------------------------------------------------------------------------
# Windows Server 2022 image lookup (skipped when instance_image_ocid is set)
# ---------------------------------------------------------------------------

data "oci_core_images" "windows" {
  count = var.instance_image_ocid == null ? 1 : 0

  compartment_id           = var.compartment_ocid
  operating_system         = "Windows"
  operating_system_version = var.windows_os_version
  shape                    = var.windows_shape

  sort_by    = "TIMECREATED"
  sort_order = "DESC"
}

locals {
  windows_image_id = var.instance_image_ocid != null ? var.instance_image_ocid : data.oci_core_images.windows[0].images[0].id
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

  instance_image_ocid = local.windows_image_id

  shape      = var.windows_shape
  ocpus      = var.windows_ocpus
  memory_gbs = var.windows_memory_gbs

  boot_volume_size_gbs = var.windows_boot_volume_size_gbs
  assign_public_ip     = var.assign_windows_public_ip

  domain_name           = var.domain_name
  company_name          = var.company_name
  admin_password_secret = var.admin_password_secret
}

# ---------------------------------------------------------------------------
# Resource Scheduler — auto-stop Windows AD at 20:00 Europe/Zurich
# ---------------------------------------------------------------------------

resource "oci_resource_scheduler_schedule" "windows_ad_stop" {
  compartment_id = var.compartment_ocid
  display_name   = "sched-${local.lab_name_core}-dc-stop-01"
  description    = "Daily stop at 18:00 UTC (20:00 CEST / 19:00 CET). Start manually."
  action         = "STOP_RESOURCE"

  recurrence_type    = "CRON"
  recurrence_details = "0 18 * * *"

  resources {
    id = module.windows_ad.instance_id
  }

  freeform_tags = local.base_freeform_tags
}

# ---------------------------------------------------------------------------
# Wait for cloudbase-init: poll WinRM port 5985 after instance (re)create
# ---------------------------------------------------------------------------

resource "null_resource" "wait_for_winrm" {
  depends_on = [module.windows_ad]
  triggers   = { instance_id = module.windows_ad.instance_id }

  provisioner "local-exec" {
    command = <<-EOT
      WIN_IP="${module.windows_ad.private_ip}"
      INVENTORY="${path.root}/../../ansible/inventories/ad-cmu-test/hosts.yml"
      echo "Waiting for WinRM on $WIN_IP:5985 (cloudbase-init phase 1)..."
      until nc -z -w 5 "$WIN_IP" 5985 2>/dev/null; do
        printf '.'; sleep 20
      done
      echo " WinRM ready - cloudbase-init phase 1 complete."
      echo "Phase 2 (AD DS promote + lab setup) runs in background after DC reboot."
      echo "Monitor: C:\\OraLab\\logs\\cloudinit-phase2.log on the instance."
      echo "Complete marker: C:\\OraLab\\logs\\setup-complete.txt"
      printf 'all:\n  children:\n    windows_dc:\n      hosts:\n        windc01:\n          ansible_host: "%s"\n' "$WIN_IP" > "$INVENTORY"
      echo "Ansible inventory updated: $INVENTORY"
    EOT
  }
}

# --- EOF ----------------------------------------------------------------------
