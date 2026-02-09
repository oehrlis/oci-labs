# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Provide network primitives (VCN and private subnet) for OCI lab
#              deployments.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.lab_name}-vcn"
  cidr_block     = var.vcn_cidr

  # NEU: DNS für die VCN aktivieren (Label muss tenantweit pro Region einzigartig sein)
  dns_label = "db19cbase"
}

resource "oci_core_subnet" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  cidr_block     = var.private_subnet_cidr

  display_name               = "${var.lab_name}-private-subnet"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_vcn.this.default_route_table_id
  security_list_ids          = [oci_core_vcn.this.default_security_list_id]
  dns_label                  = "priv"
}

# --- EOF ----------------------------------------------------------------------
