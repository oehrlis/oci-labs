# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Provision an OCI Native Bastion for secure access to private
#              subnets.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

resource "oci_bastion_bastion" "this" {
  compartment_id = var.compartment_ocid
  bastion_type   = "STANDARD"
  name           = var.bastion_name

  # Nur noch Subnet, VCN wird implizit aus dem Subnet abgeleitet
  target_subnet_id = var.target_subnet_id

  client_cidr_block_allow_list = var.client_cidr_block_allow_list
}

# --- EOF ----------------------------------------------------------------------
