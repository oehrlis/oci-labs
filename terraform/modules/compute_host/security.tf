# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: security.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.11.05
# Version....: v0.1.0
# Purpose....: Instance-level NSG for the hosts: SSH, caller-defined ingress,
#              open or HTTPS-only egress.
# Notes......: External SSH is opt-in via allowed_ssh_cidrs; the default is
#              intra-VCN access only. Extra ingress (listener, admin console,
#              ICMP) comes from ingress_rules, keyed by a stable name.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.11.05 oehrli - initial version (extracted from oracle_db_host)
# ------------------------------------------------------------------------------

locals {
  # Intra-VCN SSH is always allowed (bastion / jumphost), external CIDRs are opt-in
  ssh_source_cidrs = distinct(concat([var.vcn_cidr], var.allowed_ssh_cidrs))

  # Protocol names as OCI expects them in the rule
  protocol_numbers = { tcp = "6", udp = "17", icmp = "1", all = "all" }
}

# ------------------------------------------------------------------------------
# NSG
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group" "this" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "nsg-${var.lab_name_core}-${var.component}-01"
  freeform_tags  = var.freeform_tags
}

# ------------------------------------------------------------------------------
# Ingress SSH
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group_security_rule" "ingress_ssh" {
  for_each = toset(local.ssh_source_cidrs)

  network_security_group_id = oci_core_network_security_group.this.id
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
# Ingress - caller-defined rules (source defaults to the VCN CIDR)
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group_security_rule" "ingress" {
  for_each = var.ingress_rules

  network_security_group_id = oci_core_network_security_group.this.id
  direction                 = "INGRESS"
  protocol                  = local.protocol_numbers[each.value.protocol]
  source                    = coalesce(each.value.source, var.vcn_cidr)
  source_type               = "CIDR_BLOCK"
  description               = each.value.description

  dynamic "tcp_options" {
    for_each = each.value.protocol == "tcp" ? [1] : []
    content {
      destination_port_range {
        min = each.value.port_min
        max = coalesce(each.value.port_max, each.value.port_min)
      }
    }
  }

  dynamic "udp_options" {
    for_each = each.value.protocol == "udp" ? [1] : []
    content {
      destination_port_range {
        min = each.value.port_min
        max = coalesce(each.value.port_max, each.value.port_min)
      }
    }
  }
}

# ------------------------------------------------------------------------------
# Egress
# ------------------------------------------------------------------------------
# Default open: dnf, GitHub, MOS / AutoUpgrade patch downloads.

resource "oci_core_network_security_group_security_rule" "egress_all" {
  count = var.egress_https_only ? 0 : 1

  network_security_group_id = oci_core_network_security_group.this.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "Allow all outbound traffic (dnf, GitHub, MOS patch download)"
}

# Restricted egress (egress_https_only = true): HTTPS to anywhere plus the VCN.
# DNS and NTP to the VCN resolver are covered by the subnet security list.
resource "oci_core_network_security_group_security_rule" "egress_https" {
  count = var.egress_https_only ? 1 : 0

  network_security_group_id = oci_core_network_security_group.this.id
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

  network_security_group_id = oci_core_network_security_group.this.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = var.vcn_cidr
  destination_type          = "CIDR_BLOCK"
  description               = "All traffic inside the VCN"
}

# --- EOF ----------------------------------------------------------------------
