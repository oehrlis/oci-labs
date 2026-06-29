# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: main.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Provision VCN, gateways, route tables, security lists, subnets, and flow logs.
# Notes......: Uses lab_name_core for consistent naming; tags inherit from freeform_tags input.
# Reference..: https://github.com/oehrlis/oci-labs-infra
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Locals
# ------------------------------------------------------------------------------

locals {
  # Shortcuts for names
  vcn_name            = "vcn-${var.lab_name_core}-net-01"
  public_subnet_name  = "sn-${var.lab_name_core}-public-01"
  private_subnet_name = "sn-${var.lab_name_core}-private-01"
  db_subnet_name      = "sn-${var.lab_name_core}-db-01"
  app_subnet_name     = "sn-${var.lab_name_core}-app-01"

  public_sl_name  = "sl-${var.lab_name_core}-public-01"
  private_sl_name = "sl-${var.lab_name_core}-private-01"
  db_sl_name      = "sl-${var.lab_name_core}-db-01"
  app_sl_name     = "sl-${var.lab_name_core}-app-01"

  public_rt_name  = "rtb-${var.lab_name_core}-public-01"
  private_rt_name = "rtb-${var.lab_name_core}-private-01"
  db_rt_name      = "rtb-${var.lab_name_core}-db-01"
  app_rt_name     = "rtb-${var.lab_name_core}-app-01"

  log_group_name = "lg-${var.lab_name_core}-net-01"
  flow_log_name  = "log-${var.lab_name_core}-vcn-flow-01"

  # Network / protocol constants
  anywhere      = "0.0.0.0/0"
  all_protocols = "all"
  icmp_protocol = 1
  tcp_protocol  = 6
  udp_protocol  = 17

  dns_port   = 53
  http_port  = 80
  https_port = 443
  ntp_port   = 123

  # Optional TCP-Lab-Range (OCI-konform)
  port_range_min = 15000
  port_range_max = 20999

  # Windows AD subnet names
  windows_subnet_name = "sn-${var.lab_name_core}-windows-01"
  windows_sl_name     = "sl-${var.lab_name_core}-windows-01"
  windows_rt_name     = "rtb-${var.lab_name_core}-windows-01"

  rdp_port = 3389

  # Windows AD ingress rules from VCN (all required AD + management ports)
  windows_ad_ingress_rules = [
    { name = "rdp",             description = "Allow RDP (TCP 3389)",               protocol = local.tcp_protocol,  tcp_min = 3389, tcp_max = 3389, udp_min = null, udp_max = null, icmp_type = null },
    { name = "winrm_http",      description = "Allow WinRM HTTP (TCP 5985)",         protocol = local.tcp_protocol,  tcp_min = 5985, tcp_max = 5985, udp_min = null, udp_max = null, icmp_type = null },
    { name = "winrm_https",     description = "Allow WinRM HTTPS (TCP 5986)",        protocol = local.tcp_protocol,  tcp_min = 5986, tcp_max = 5986, udp_min = null, udp_max = null, icmp_type = null },
    { name = "ldap_tcp",        description = "Allow LDAP (TCP 389)",                protocol = local.tcp_protocol,  tcp_min = 389,  tcp_max = 389,  udp_min = null, udp_max = null, icmp_type = null },
    { name = "ldap_udp",        description = "Allow LDAP (UDP 389)",                protocol = local.udp_protocol,  tcp_min = null, tcp_max = null, udp_min = 389,  udp_max = 389,  icmp_type = null },
    { name = "ldaps",           description = "Allow LDAPS (TCP 636)",               protocol = local.tcp_protocol,  tcp_min = 636,  tcp_max = 636,  udp_min = null, udp_max = null, icmp_type = null },
    { name = "kerberos_tcp",    description = "Allow Kerberos (TCP 88)",             protocol = local.tcp_protocol,  tcp_min = 88,   tcp_max = 88,   udp_min = null, udp_max = null, icmp_type = null },
    { name = "kerberos_udp",    description = "Allow Kerberos (UDP 88)",             protocol = local.udp_protocol,  tcp_min = null, tcp_max = null, udp_min = 88,   udp_max = 88,   icmp_type = null },
    { name = "kerberos_pwd_tcp",description = "Allow Kerberos password (TCP 464)",   protocol = local.tcp_protocol,  tcp_min = 464,  tcp_max = 464,  udp_min = null, udp_max = null, icmp_type = null },
    { name = "kerberos_pwd_udp",description = "Allow Kerberos password (UDP 464)",   protocol = local.udp_protocol,  tcp_min = null, tcp_max = null, udp_min = 464,  udp_max = 464,  icmp_type = null },
    { name = "dns_tcp",         description = "Allow DNS (TCP 53)",                  protocol = local.tcp_protocol,  tcp_min = 53,   tcp_max = 53,   udp_min = null, udp_max = null, icmp_type = null },
    { name = "dns_udp",         description = "Allow DNS (UDP 53)",                  protocol = local.udp_protocol,  tcp_min = null, tcp_max = null, udp_min = 53,   udp_max = 53,   icmp_type = null },
    { name = "gc",              description = "Allow Global Catalog (TCP 3268)",     protocol = local.tcp_protocol,  tcp_min = 3268, tcp_max = 3268, udp_min = null, udp_max = null, icmp_type = null },
    { name = "gc_ssl",          description = "Allow Global Catalog SSL (TCP 3269)", protocol = local.tcp_protocol,  tcp_min = 3269, tcp_max = 3269, udp_min = null, udp_max = null, icmp_type = null },
    { name = "icmp_from_vcn",   description = "Allow ICMP echo from VCN",            protocol = local.icmp_protocol, tcp_min = null, tcp_max = null, udp_min = null, udp_max = null, icmp_type = 8   },
  ]

  # Gemeinsame Egress-Regeln für alle internen Subnets und Public
  # (ohne "all" nach 0.0.0.0/0)
  common_egress_rules = [
    {
      name        = "dns"
      description = "Allow outbound DNS (UDP 53)"
      destination = local.anywhere
      protocol    = local.udp_protocol
      tcp_min     = null
      tcp_max     = null
      udp_min     = local.dns_port
      udp_max     = local.dns_port
      icmp_type   = null
    },
    {
      name        = "http"
      description = "Allow outbound HTTP (TCP 80)"
      destination = local.anywhere
      protocol    = local.tcp_protocol
      tcp_min     = local.http_port
      tcp_max     = local.http_port
      udp_min     = null
      udp_max     = null
      icmp_type   = null
    },
    {
      name        = "https"
      description = "Allow outbound HTTPS (TCP 443)"
      destination = local.anywhere
      protocol    = local.tcp_protocol
      tcp_min     = local.https_port
      tcp_max     = local.https_port
      udp_min     = null
      udp_max     = null
      icmp_type   = null
    },
    {
      name        = "ntp"
      description = "Allow outbound NTP (UDP 123)"
      destination = local.anywhere
      protocol    = local.udp_protocol
      tcp_min     = null
      tcp_max     = null
      udp_min     = local.ntp_port
      udp_max     = local.ntp_port
      icmp_type   = null
    },
    {
      name        = "icmp_echo"
      description = "Allow outbound ICMP echo (ping)"
      destination = local.anywhere
      protocol    = local.icmp_protocol
      tcp_min     = null
      tcp_max     = null
      udp_min     = null
      udp_max     = null
      icmp_type   = 8
    },
    {
      name        = "intra_vcn_all"
      description = "Allow all traffic within VCN"
      destination = var.vcn_cidr
      protocol    = local.all_protocols
      tcp_min     = null
      tcp_max     = null
      udp_min     = null
      udp_max     = null
      icmp_type   = null
    },
    {
      name        = "tcp_range"
      description = "Allow outbound TCP port range 15000-20999"
      destination = local.anywhere
      protocol    = local.tcp_protocol
      tcp_min     = local.port_range_min
      tcp_max     = local.port_range_max
      udp_min     = null
      udp_max     = null
      icmp_type   = null
    }
  ]
}

# -----------------------------------------------------------------------------
# VCN
# -----------------------------------------------------------------------------

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_ocid
  cidr_block     = var.vcn_cidr
  display_name   = local.vcn_name
  dns_label      = replace(substr(var.lab_name_core, 0, 15), "-", "")

  freeform_tags = var.freeform_tags
}


# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------

resource "oci_core_internet_gateway" "igw" {
  count          = var.internet_gateway_enabled ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "igw-${var.lab_name_core}-01"

  freeform_tags = var.freeform_tags
}

# -----------------------------------------------------------------------------
# NAT Gateway
# -----------------------------------------------------------------------------

resource "oci_core_nat_gateway" "nat" {
  count          = var.nat_gateway_enabled ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "ngw-${var.lab_name_core}-01"

  freeform_tags = var.freeform_tags
}

# -----------------------------------------------------------------------------
# Route Tables
# -----------------------------------------------------------------------------

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.public_rt_name

  dynamic "route_rules" {
    for_each = var.internet_gateway_enabled ? [1] : []
    content {
      network_entity_id = oci_core_internet_gateway.igw[0].id
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
    }
  }

  freeform_tags = var.freeform_tags
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.private_rt_name

  dynamic "route_rules" {
    for_each = var.nat_gateway_enabled ? [1] : []
    content {
      network_entity_id = oci_core_nat_gateway.nat[0].id
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
    }
  }

  freeform_tags = var.freeform_tags
}

resource "oci_core_route_table" "db" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.db_rt_name

  dynamic "route_rules" {
    for_each = var.nat_gateway_enabled ? [1] : []
    content {
      network_entity_id = oci_core_nat_gateway.nat[0].id
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
    }
  }

  freeform_tags = var.freeform_tags
}

resource "oci_core_route_table" "app" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.app_rt_name

  dynamic "route_rules" {
    for_each = var.nat_gateway_enabled ? [1] : []
    content {
      network_entity_id = oci_core_nat_gateway.nat[0].id
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
    }
  }

  freeform_tags = var.freeform_tags
}

# Windows subnet: NAT gateway for outbound internet (no public IP needed)
resource "oci_core_route_table" "windows" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.windows_rt_name

  dynamic "route_rules" {
    for_each = var.nat_gateway_enabled ? [1] : []
    content {
      network_entity_id = oci_core_nat_gateway.nat[0].id
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
    }
  }

  dynamic "route_rules" {
    for_each = var.drg_id != null ? var.home_cidrs : []
    content {
      network_entity_id = var.drg_id
      destination       = route_rules.value
      destination_type  = "CIDR_BLOCK"
    }
  }

  freeform_tags = var.freeform_tags
}

# -----------------------------------------------------------------------------
# DRG Attachment
# -----------------------------------------------------------------------------

resource "oci_core_drg_attachment" "this" {
  count        = var.drg_id != null ? 1 : 0
  drg_id       = var.drg_id
  vcn_id       = oci_core_vcn.this.id
  display_name = "drga-${var.lab_name_core}-01"

  freeform_tags = var.freeform_tags
}

# -----------------------------------------------------------------------------
# Security Lists
# -----------------------------------------------------------------------------
# Public subnet: SSH, WireGuard; minimale, konforme Egress-Regeln
resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.public_sl_name
  freeform_tags  = var.freeform_tags

  # -----------------------------
  # EGRESS – aus common_egress_rules
  # -----------------------------
  dynamic "egress_security_rules" {
    for_each = local.common_egress_rules
    content {
      description = egress_security_rules.value.description
      destination = egress_security_rules.value.destination
      protocol    = egress_security_rules.value.protocol

      dynamic "tcp_options" {
        for_each = egress_security_rules.value.tcp_min != null ? [1] : []
        content {
          min = egress_security_rules.value.tcp_min
          max = egress_security_rules.value.tcp_max
        }
      }

      dynamic "udp_options" {
        for_each = egress_security_rules.value.udp_min != null ? [1] : []
        content {
          min = egress_security_rules.value.udp_min
          max = egress_security_rules.value.udp_max
        }
      }

      dynamic "icmp_options" {
        for_each = egress_security_rules.value.icmp_type != null ? [1] : []
        content {
          type = egress_security_rules.value.icmp_type
        }
      }
    }
  }

  # -----------------------------
  # INGRESS – SSH / WireGuard wie gehabt
  # -----------------------------

  # WireGuard UDP – für jede erlaubte CIDR
  dynamic "ingress_security_rules" {
    for_each = var.allowed_wireguard_cidrs
    content {
      protocol    = local.udp_protocol
      source      = ingress_security_rules.value
      source_type = "CIDR_BLOCK"
      stateless   = false

      udp_options {
        min = var.wireguard_port
        max = var.wireguard_port
      }
    }
  }

  # SSH TCP – für jede erlaubte CIDR
  dynamic "ingress_security_rules" {
    for_each = var.allowed_ssh_cidrs
    content {
      protocol    = local.tcp_protocol
      source      = ingress_security_rules.value
      source_type = "CIDR_BLOCK"
      stateless   = false

      tcp_options {
        min = var.ssh_port
        max = var.ssh_port
      }
    }
  }
}

# Private, DB, App: allow all within VCN, egress all
resource "oci_core_security_list" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.private_sl_name

  # Ingress: alles aus der VCN (kann später feiner werden)
  ingress_security_rules {
    protocol = local.all_protocols
    source   = var.vcn_cidr
  }

  # Egress: gemeinsame Policy
  dynamic "egress_security_rules" {
    for_each = local.common_egress_rules
    content {
      description = egress_security_rules.value.description
      destination = egress_security_rules.value.destination
      protocol    = egress_security_rules.value.protocol

      dynamic "tcp_options" {
        for_each = egress_security_rules.value.tcp_min != null ? [1] : []
        content {
          min = egress_security_rules.value.tcp_min
          max = egress_security_rules.value.tcp_max
        }
      }

      dynamic "udp_options" {
        for_each = egress_security_rules.value.udp_min != null ? [1] : []
        content {
          min = egress_security_rules.value.udp_min
          max = egress_security_rules.value.udp_max
        }
      }

      dynamic "icmp_options" {
        for_each = egress_security_rules.value.icmp_type != null ? [1] : []
        content {
          type = egress_security_rules.value.icmp_type
        }
      }
    }
  }

  freeform_tags = var.freeform_tags
}

resource "oci_core_security_list" "db" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.db_sl_name

  # Ingress: alles aus der VCN (später segmentierbar)
  ingress_security_rules {
    protocol = local.all_protocols
    source   = var.vcn_cidr
  }

  dynamic "egress_security_rules" {
    for_each = local.common_egress_rules
    content {
      description = egress_security_rules.value.description
      destination = egress_security_rules.value.destination
      protocol    = egress_security_rules.value.protocol

      dynamic "tcp_options" {
        for_each = egress_security_rules.value.tcp_min != null ? [1] : []
        content {
          min = egress_security_rules.value.tcp_min
          max = egress_security_rules.value.tcp_max
        }
      }

      dynamic "udp_options" {
        for_each = egress_security_rules.value.udp_min != null ? [1] : []
        content {
          min = egress_security_rules.value.udp_min
          max = egress_security_rules.value.udp_max
        }
      }

      dynamic "icmp_options" {
        for_each = egress_security_rules.value.icmp_type != null ? [1] : []
        content {
          type = egress_security_rules.value.icmp_type
        }
      }
    }
  }

  freeform_tags = var.freeform_tags
}

resource "oci_core_security_list" "app" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.app_sl_name

  # Ingress: alles aus der VCN
  ingress_security_rules {
    protocol = local.all_protocols
    source   = var.vcn_cidr
  }

  dynamic "egress_security_rules" {
    for_each = local.common_egress_rules
    content {
      description = egress_security_rules.value.description
      destination = egress_security_rules.value.destination
      protocol    = egress_security_rules.value.protocol

      dynamic "tcp_options" {
        for_each = egress_security_rules.value.tcp_min != null ? [1] : []
        content {
          min = egress_security_rules.value.tcp_min
          max = egress_security_rules.value.tcp_max
        }
      }

      dynamic "udp_options" {
        for_each = egress_security_rules.value.udp_min != null ? [1] : []
        content {
          min = egress_security_rules.value.udp_min
          max = egress_security_rules.value.udp_max
        }
      }

      dynamic "icmp_options" {
        for_each = egress_security_rules.value.icmp_type != null ? [1] : []
        content {
          type = egress_security_rules.value.icmp_type
        }
      }
    }
  }

  freeform_tags = var.freeform_tags
}

# Windows AD: specific AD port ingress from VCN + optional external RDP
resource "oci_core_security_list" "windows" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = local.windows_sl_name
  freeform_tags  = var.freeform_tags

  # INGRESS – AD ports from VCN
  dynamic "ingress_security_rules" {
    for_each = local.windows_ad_ingress_rules
    content {
      description = ingress_security_rules.value.description
      protocol    = ingress_security_rules.value.protocol
      source      = var.vcn_cidr
      source_type = "CIDR_BLOCK"
      stateless   = false

      dynamic "tcp_options" {
        for_each = ingress_security_rules.value.tcp_min != null ? [1] : []
        content {
          min = ingress_security_rules.value.tcp_min
          max = ingress_security_rules.value.tcp_max
        }
      }

      dynamic "udp_options" {
        for_each = ingress_security_rules.value.udp_min != null ? [1] : []
        content {
          min = ingress_security_rules.value.udp_min
          max = ingress_security_rules.value.udp_max
        }
      }

      dynamic "icmp_options" {
        for_each = ingress_security_rules.value.icmp_type != null ? [1] : []
        content {
          type = ingress_security_rules.value.icmp_type
        }
      }
    }
  }

  # INGRESS – AD ports from home/VPN CIDRs (traffic arrives via DRG with on-prem source IP)
  dynamic "ingress_security_rules" {
    for_each = {
      for pair in setproduct(var.home_cidrs, local.windows_ad_ingress_rules) :
      "${pair[0]}-${pair[1].name}" => { cidr = pair[0], rule = pair[1] }
    }
    content {
      description = "${ingress_security_rules.value.rule.description} from ${ingress_security_rules.value.cidr}"
      protocol    = ingress_security_rules.value.rule.protocol
      source      = ingress_security_rules.value.cidr
      source_type = "CIDR_BLOCK"
      stateless   = false

      dynamic "tcp_options" {
        for_each = ingress_security_rules.value.rule.tcp_min != null ? [1] : []
        content {
          min = ingress_security_rules.value.rule.tcp_min
          max = ingress_security_rules.value.rule.tcp_max
        }
      }

      dynamic "udp_options" {
        for_each = ingress_security_rules.value.rule.udp_min != null ? [1] : []
        content {
          min = ingress_security_rules.value.rule.udp_min
          max = ingress_security_rules.value.rule.udp_max
        }
      }

      dynamic "icmp_options" {
        for_each = ingress_security_rules.value.rule.icmp_type != null ? [1] : []
        content {
          type = ingress_security_rules.value.rule.icmp_type
        }
      }
    }
  }

  # INGRESS – RDP from allowed external CIDRs (default empty → no external access)
  dynamic "ingress_security_rules" {
    for_each = var.allowed_rdp_cidrs
    content {
      protocol    = local.tcp_protocol
      source      = ingress_security_rules.value
      source_type = "CIDR_BLOCK"
      stateless   = false

      tcp_options {
        min = local.rdp_port
        max = local.rdp_port
      }
    }
  }

  # EGRESS – common policy
  dynamic "egress_security_rules" {
    for_each = local.common_egress_rules
    content {
      description = egress_security_rules.value.description
      destination = egress_security_rules.value.destination
      protocol    = egress_security_rules.value.protocol

      dynamic "tcp_options" {
        for_each = egress_security_rules.value.tcp_min != null ? [1] : []
        content {
          min = egress_security_rules.value.tcp_min
          max = egress_security_rules.value.tcp_max
        }
      }

      dynamic "udp_options" {
        for_each = egress_security_rules.value.udp_min != null ? [1] : []
        content {
          min = egress_security_rules.value.udp_min
          max = egress_security_rules.value.udp_max
        }
      }

      dynamic "icmp_options" {
        for_each = egress_security_rules.value.icmp_type != null ? [1] : []
        content {
          type = egress_security_rules.value.icmp_type
        }
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Subnets
# -----------------------------------------------------------------------------

resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.public_subnet_cidr
  display_name               = local.public_subnet_name
  dns_label                  = "pub"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  prohibit_public_ip_on_vnic = false

  freeform_tags = var.freeform_tags
}

resource "oci_core_subnet" "private" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.private_subnet_cidr
  display_name               = local.private_subnet_name
  dns_label                  = "priv"
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  prohibit_public_ip_on_vnic = true

  freeform_tags = var.freeform_tags
}

resource "oci_core_subnet" "db" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.db_subnet_cidr
  display_name               = local.db_subnet_name
  dns_label                  = "db"
  route_table_id             = oci_core_route_table.db.id
  security_list_ids          = [oci_core_security_list.db.id]
  prohibit_public_ip_on_vnic = true

  freeform_tags = var.freeform_tags
}

resource "oci_core_subnet" "app" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.app_subnet_cidr
  display_name               = local.app_subnet_name
  dns_label                  = "app"
  route_table_id             = oci_core_route_table.app.id
  security_list_ids          = [oci_core_security_list.app.id]
  prohibit_public_ip_on_vnic = true

  freeform_tags = var.freeform_tags
}

# public-capable (prohibit_public_ip = false) so the module can optionally assign a public IP
resource "oci_core_subnet" "windows" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.windows_subnet_cidr
  display_name               = local.windows_subnet_name
  dns_label                  = "win"
  route_table_id             = oci_core_route_table.windows.id
  security_list_ids          = [oci_core_security_list.windows.id]
  prohibit_public_ip_on_vnic = false

  freeform_tags = var.freeform_tags
}

# -----------------------------------------------------------------------------
# Logging: Log Group + VCN Flow Logs
# -----------------------------------------------------------------------------
resource "oci_logging_log_group" "net" {
  compartment_id = var.compartment_ocid
  display_name   = local.log_group_name

  freeform_tags = var.freeform_tags
}

# Flow Logs pro Subnet (public / private / db / app)
locals {
  flow_log_targets = {
    public  = oci_core_subnet.public.id
    private = oci_core_subnet.private.id
    db      = oci_core_subnet.db.id
    app     = oci_core_subnet.app.id
    windows = oci_core_subnet.windows.id
  }
}

resource "oci_logging_log" "vcn_flow" {
  for_each = local.flow_log_targets

  log_group_id       = oci_logging_log_group.net.id
  display_name       = "log-${var.lab_name_core}-${each.key}-flow-01"
  log_type           = "SERVICE"
  is_enabled         = true
  retention_duration = var.flow_log_retention_duration

  configuration {
    source {
      category    = "all"
      resource    = each.value
      service     = "flowlogs"
      source_type = "OCISERVICE"
    }
  }

  freeform_tags = var.freeform_tags
}

# -----------------------------------------------------------------------------
# Default Route Table "neutralisieren"
# -----------------------------------------------------------------------------
# Default Route Table der VCN verwalten
resource "oci_core_default_route_table" "default_rt" {
  manage_default_resource_id = oci_core_vcn.this.default_route_table_id

  # keine route_rules-Blöcke definieren -> Terraform managed nur das Objekt,
  # aber ändert die Routen nicht aktiv
  freeform_tags = var.freeform_tags
}


# -----------------------------------------------------------------------------
# Default Security List leeren
# -----------------------------------------------------------------------------
# Default Security List der VCN verwalten
resource "oci_core_default_security_list" "default_sl" {
  manage_default_resource_id = oci_core_vcn.this.default_security_list_id

  # keine ingress/egress-Blöcke definieren -> keine zusätzlichen Regeln
  freeform_tags = var.freeform_tags
}
# --- EOF ----------------------------------------------------------------------
