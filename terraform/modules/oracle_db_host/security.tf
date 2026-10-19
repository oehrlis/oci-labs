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
# 2026.10.19 oehrli - optional HTTPS-only egress (egress_https_only)
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
  count = var.egress_https_only ? 0 : 1

  network_security_group_id = oci_core_network_security_group.db_host.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "Allow all outbound traffic (dnf, GitHub, MOS patch download)"
}

# The rule gained a count for egress_https_only. Without this block every
# existing stack would destroy and recreate it on the next apply.
moved {
  from = oci_core_network_security_group_security_rule.egress_all
  to   = oci_core_network_security_group_security_rule.egress_all[0]
}

# Restricted egress (egress_https_only = true): HTTPS to anywhere, everything
# inside the VCN. Enough for dnf (OCI regional yum mirrors), container
# registries, GitHub and the Data Safe on-premises connector, which only ever
# opens outbound TLS connections to the Data Safe service. DNS and NTP to the
# VCN resolver (169.254.169.254) are covered by the subnet security list.
resource "oci_core_network_security_group_security_rule" "egress_https" {
  count = var.egress_https_only ? 1 : 0

  network_security_group_id = oci_core_network_security_group.db_host.id
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "Outbound HTTPS only (dnf, registries, Data Safe connector)"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "egress_vcn" {
  count = var.egress_https_only ? 1 : 0

  network_security_group_id = oci_core_network_security_group.db_host.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = var.vcn_cidr
  destination_type          = "CIDR_BLOCK"
  description               = "All traffic inside the VCN"
}

# --- EOF ----------------------------------------------------------------------
