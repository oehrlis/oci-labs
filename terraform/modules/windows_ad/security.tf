# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: security.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.06.26
# Version....: v0.1.0
# Purpose....: Instance-level NSG for Windows AD (RDP, WinRM, AD, Kerberos).
# Notes......: NSG complements the subnet-level Security List in the network module.
#              NSG and Security List rules are a union: an open NSG source would
#              override the Security List, so ingress is limited to vcn_cidr and
#              allowed_cidrs (default empty = no ingress from outside the VCN).
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.06.26 oehrli - initial version
# 2026.11.24 oehrli - ingress limited to vcn_cidr + allowed_cidrs (no 0.0.0.0/0)
# ------------------------------------------------------------------------------

locals {
  nsg_name = "nsg-${var.lab_name_core}-dc-01"

  nsg_tcp_rules = {
    rdp          = { port = 3389, description = "RDP" }
    winrm_http   = { port = 5985, description = "WinRM HTTP" }
    winrm_https  = { port = 5986, description = "WinRM HTTPS" }
    ldap_tcp     = { port = 389, description = "LDAP" }
    ldaps        = { port = 636, description = "LDAPS" }
    kerberos_tcp = { port = 88, description = "Kerberos" }
    kpwd_tcp     = { port = 464, description = "Kerberos pwd change" }
    dns_tcp      = { port = 53, description = "DNS" }
    gc           = { port = 3268, description = "Global Catalog" }
    gc_ssl       = { port = 3269, description = "Global Catalog SSL" }
  }

  nsg_udp_rules = {
    ldap_udp     = { port = 389, description = "LDAP UDP" }
    kerberos_udp = { port = 88, description = "Kerberos UDP" }
    kpwd_udp     = { port = 464, description = "Kerberos pwd change UDP" }
    dns_udp      = { port = 53, description = "DNS UDP" }
  }

  # Allowed ingress sources: VCN CIDR (if known) plus explicit external CIDRs
  nsg_source_cidrs = distinct(concat(var.vcn_cidr == null ? [] : [var.vcn_cidr], var.allowed_cidrs))

  # One rule per (port rule, source CIDR) pair
  nsg_tcp_ingress = {
    for pair in setproduct(keys(local.nsg_tcp_rules), local.nsg_source_cidrs) :
    "${pair[0]}-${pair[1]}" => merge(local.nsg_tcp_rules[pair[0]], { source = pair[1] })
  }

  nsg_udp_ingress = {
    for pair in setproduct(keys(local.nsg_udp_rules), local.nsg_source_cidrs) :
    "${pair[0]}-${pair[1]}" => merge(local.nsg_udp_rules[pair[0]], { source = pair[1] })
  }
}

# ------------------------------------------------------------------------------
# NSG
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group" "windows_ad" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = local.nsg_name
  freeform_tags  = var.freeform_tags
}

# ------------------------------------------------------------------------------
# NSG Rules - Ingress TCP
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group_security_rule" "ingress_tcp" {
  for_each = local.nsg_tcp_ingress

  network_security_group_id = oci_core_network_security_group.windows_ad.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = each.value.source
  source_type               = "CIDR_BLOCK"
  description               = "${each.value.description} from ${each.value.source}"

  tcp_options {
    destination_port_range {
      min = each.value.port
      max = each.value.port
    }
  }
}

# ------------------------------------------------------------------------------
# NSG Rules - Ingress UDP
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group_security_rule" "ingress_udp" {
  for_each = local.nsg_udp_ingress

  network_security_group_id = oci_core_network_security_group.windows_ad.id
  direction                 = "INGRESS"
  protocol                  = "17"
  source                    = each.value.source
  source_type               = "CIDR_BLOCK"
  description               = "${each.value.description} from ${each.value.source}"

  udp_options {
    destination_port_range {
      min = each.value.port
      max = each.value.port
    }
  }
}

# ------------------------------------------------------------------------------
# NSG Rules - Egress
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group_security_rule" "egress_all" {
  network_security_group_id = oci_core_network_security_group.windows_ad.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "Allow all outbound traffic"
}

# --- EOF ----------------------------------------------------------------------
