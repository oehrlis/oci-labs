# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.11.05
# Version....: v0.2.0
# Purpose....: Provision N identical Oracle Linux hosts for Oracle DB labs.
# Notes......: Thin wrapper around compute_host: DB naming (component "db"),
#              role tags, Oracle Net listener and ICMP ingress, oradba
#              cloud-init. Cloud-init stays minimal on purpose - OS
#              prerequisites and the Oracle install are Ansible's job.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.08.19 oehrli - initial version
# 2026.10.15 oehrli - ignore ssh_authorized_keys drift (no replacement)
# 2026.11.05 oehrli - resources moved into compute_host (moved blocks below)
# ------------------------------------------------------------------------------

module "host" {
  source = "../compute_host"

  compartment_ocid    = var.compartment_ocid
  vcn_id              = var.vcn_id
  vcn_cidr            = var.vcn_cidr
  subnet_id           = var.subnet_id
  availability_domain = var.availability_domain
  lab_name_core       = var.lab_name_core
  freeform_tags       = var.freeform_tags

  component     = "db"
  role_tag      = "oracle-db-host"
  data_role_tag = "oracle-db-data"

  hostname_prefix      = var.hostname_prefix
  host_count           = var.host_count
  instance_image_ocid  = var.instance_image_ocid
  shape                = var.shape
  ocpus                = var.ocpus
  memory_gbs           = var.memory_gbs
  boot_volume_size_gbs = var.boot_volume_size_gbs
  assign_public_ip     = var.assign_public_ip

  attach_data_volume      = var.attach_data_volume
  data_volume_size_gbs    = var.data_volume_size_gbs
  data_volume_vpus_per_gb = var.data_volume_vpus_per_gb

  ssh_public_keys   = var.ssh_public_keys
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
  ssh_port          = var.ssh_port
  egress_https_only = var.egress_https_only

  user_data_template = "${path.module}/templates/oracle_db_host-cloudinit.yaml.tftpl"
  user_data_vars = {
    oradba_repo_url    = var.oradba_repo_url
    oradba_install_dir = var.oradba_install_dir
  }

  ingress_rules = {
    listener = {
      protocol    = "tcp"
      port_min    = var.listener_port
      description = "Oracle Net listener (intra-VCN)"
    }
    icmp = {
      protocol    = "icmp"
      description = "ICMP inside the VCN"
    }
  }
}

# ------------------------------------------------------------------------------
# State moves - v0.1.0 addresses to compute_host. Without them every existing
# stack would destroy and recreate its database hosts on the next apply.
# ------------------------------------------------------------------------------

moved {
  from = oci_core_instance.db_host
  to   = module.host.oci_core_instance.this
}

moved {
  from = oci_core_volume.data
  to   = module.host.oci_core_volume.data
}

moved {
  from = oci_core_volume_attachment.data
  to   = module.host.oci_core_volume_attachment.data
}

moved {
  from = oci_core_network_security_group.db_host
  to   = module.host.oci_core_network_security_group.this
}

moved {
  from = oci_core_network_security_group_security_rule.ingress_ssh
  to   = module.host.oci_core_network_security_group_security_rule.ingress_ssh
}

moved {
  from = oci_core_network_security_group_security_rule.ingress_listener
  to   = module.host.oci_core_network_security_group_security_rule.ingress["listener"]
}

moved {
  from = oci_core_network_security_group_security_rule.ingress_icmp
  to   = module.host.oci_core_network_security_group_security_rule.ingress["icmp"]
}

# egress_all gained a count in v0.1.x (egress_https_only); the chain keeps
# both the old unindexed and the indexed address working.
moved {
  from = oci_core_network_security_group_security_rule.egress_all
  to   = oci_core_network_security_group_security_rule.egress_all[0]
}

moved {
  from = oci_core_network_security_group_security_rule.egress_all[0]
  to   = module.host.oci_core_network_security_group_security_rule.egress_all[0]
}

moved {
  from = oci_core_network_security_group_security_rule.egress_https
  to   = module.host.oci_core_network_security_group_security_rule.egress_https
}

moved {
  from = oci_core_network_security_group_security_rule.egress_vcn
  to   = module.host.oci_core_network_security_group_security_rule.egress_vcn
}

# --- EOF ----------------------------------------------------------------------
