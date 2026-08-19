# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: security.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.08.19
# Version....: v0.1.0
# Purpose....: Instance-level NSG for the Oracle DB lab hosts (SSH, listener).
# Notes......: NSG complements the subnet-level Security List in the network
#              module. External SSH is opt-in via allowed_ssh_cidrs; the
#              default is intra-VCN access only.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.08.19 oehrli - initial version
# ------------------------------------------------------------------------------

locals {
  nsg_name = "nsg-${var.lab_name_core}-db-01"

  # Intra-VCN SSH is always allowed (jumphost / bastion / Cloud Shell via VPN),
  # external CIDRs are opt-in via allowed_ssh_cidrs.
  ssh_source_cidrs = distinct(concat([var.vcn_cidr], var.allowed_ssh_cidrs))
}

# ------------------------------------------------------------------------------
# NSG
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group" "db_host" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = local.nsg_name
  freeform_tags  = var.freeform_tags
}

# ------------------------------------------------------------------------------
# NSG Rules - Ingress SSH
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group_security_rule" "ingress_ssh" {
  for_each = toset(local.ssh_source_cidrs)

  network_security_group_id = oci_core_network_security_group.db_host.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = each.value
  source_type               = "CIDR_BLOCK"
  description               = "SSH from ${each.value}"

  tcp_options {
    destination_port_range {
      min = var.ssh_port
      max = var.ssh_port
    }
  }
}

# ------------------------------------------------------------------------------
# NSG Rules - Ingress Oracle Net listener (intra-VCN only)
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group_security_rule" "ingress_listener" {
  network_security_group_id = oci_core_network_security_group.db_host.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  description               = "Oracle Net listener (intra-VCN)"

  tcp_options {
    destination_port_range {
      min = var.listener_port
      max = var.listener_port
    }
  }
}

# ------------------------------------------------------------------------------
# NSG Rules - Ingress ICMP (path MTU / reachability inside the VCN)
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group_security_rule" "ingress_icmp" {
  network_security_group_id = oci_core_network_security_group.db_host.id
  direction                 = "INGRESS"
  protocol                  = "1"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  description               = "ICMP inside the VCN"
}

# ------------------------------------------------------------------------------
# NSG Rules - Egress
# ------------------------------------------------------------------------------
# Outbound must stay open: yum/dnf updates, GitHub clone of oradba, and
# AutoUpgrade patch downloads from Oracle (updates.oracle.com).

resource "oci_core_network_security_group_security_rule" "egress_all" {
  network_security_group_id = oci_core_network_security_group.db_host.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "Allow all outbound traffic (dnf, GitHub, MOS patch download)"
}

# --- EOF ----------------------------------------------------------------------
