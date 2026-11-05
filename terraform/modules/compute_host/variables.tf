# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: variables.tf
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.11.05
# Version....: v0.1.0
# Purpose....: Inputs for the compute_host module.
# Notes......: Product-neutral defaults. Product modules (oracle_db_host, ...)
#              set component, role tags, cloud-init and ingress rules.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2026.11.05 oehrli - initial version (extracted from oracle_db_host)
# ------------------------------------------------------------------------------

variable "compartment_ocid" {
  type        = string
  description = "Compartment OCID where the host resources will be created."
}

variable "vcn_id" {
  type        = string
  description = "VCN OCID - required for creating the instance-level NSG."
}

variable "vcn_cidr" {
  type        = string
  description = "VCN CIDR block. Used as ingress source for intra-VCN NSG rules."
}

variable "subnet_id" {
  type        = string
  description = "Subnet OCID where the host(s) will be placed."
}

variable "availability_domain" {
  type        = string
  description = "Availability domain name for the host(s)."
}

variable "lab_name_core" {
  type        = string
  description = "Core lab name segment used for resource names, e.g. chzh-l-cpupt-01."
}

variable "freeform_tags" {
  type        = map(string)
  description = "Base freeform tags applied to all resources of this module."
  default     = {}
}

variable "component" {
  type        = string
  description = "Component segment in resource names: ci-<lab_name_core>-<component>-01, nsg-<lab_name_core>-<component>-01."
  default     = "host"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{0,15}$", var.component))
    error_message = "component must start with a letter, lowercase alphanumeric, at most 16 characters."
  }
}

variable "role_tag" {
  type        = string
  description = "Value of the freeform tag 'role' on the instances."
  default     = "compute-host"
}

variable "data_role_tag" {
  type        = string
  description = "Value of the freeform tag 'role' on the optional data volumes."
  default     = "compute-host-data"
}

variable "hostname_prefix" {
  type        = string
  description = "Hostname and DNS label prefix, the host key is appended (host01). Must be unique per subnet: envs that share the core DB subnet need their own."
  default     = "host"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{0,12}$", var.hostname_prefix))
    error_message = "hostname_prefix must start with a letter, lowercase alphanumeric, at most 13 characters (OCI DNS label limit with the two-digit key)."
  }
}

variable "host_count" {
  type        = number
  description = "Number of identical hosts to create (workshops: > 1)."
  default     = 1

  validation {
    condition     = var.host_count >= 1 && var.host_count <= 20
    error_message = "host_count must be between 1 and 20."
  }
}

variable "instance_image_ocid" {
  type        = string
  description = "Image OCID for the instances. Resolved by the caller (image lookup in the root)."
}

variable "shape" {
  type        = string
  description = "Compute shape (Flex). Oracle DB 19c needs x86."
  default     = "VM.Standard.E4.Flex"
}

variable "ocpus" {
  type        = number
  description = "Number of OCPUs per host."
  default     = 2
}

variable "memory_gbs" {
  type        = number
  description = "Memory in GB per host."
  default     = 16
}

variable "boot_volume_size_gbs" {
  type        = number
  description = "Boot volume size in GB. OCI minimum is 50 GB; product modules may require more."
  default     = 200

  validation {
    condition     = var.boot_volume_size_gbs >= 50
    error_message = "boot_volume_size_gbs must be at least 50 GB (OCI minimum)."
  }
}

variable "assign_public_ip" {
  type        = bool
  description = "Assign a public IP. Requires a public-capable subnet and allowed_ssh_cidrs."
  default     = false
}

variable "attach_data_volume" {
  type        = bool
  description = "Attach an additional block volume per host (engineering labs)."
  default     = false
}

variable "data_volume_size_gbs" {
  type        = number
  description = "Size in GB of the optional data volume per host."
  default     = 100
}

variable "data_volume_vpus_per_gb" {
  type        = number
  description = "Block volume performance in VPUs/GB (0 = lower cost, 10 = balanced, 20 = high)."
  default     = 10
}

variable "ssh_public_keys" {
  type        = list(string)
  description = <<-EOT
    SSH public keys placed in instance metadata for the opc user. All of them
    are authorised - typically the operator's personal key plus a per-lab
    keypair generated for the stack lifecycle.
  EOT

  validation {
    condition     = length(var.ssh_public_keys) > 0
    error_message = "At least one SSH public key is required, otherwise the host is unreachable."
  }

  validation {
    condition     = alltrue([for k in var.ssh_public_keys : can(regex("^(ssh-(rsa|ed25519)|ecdsa-sha2-)", trimspace(k)))])
    error_message = "Each entry must be an OpenSSH public key (ssh-rsa, ssh-ed25519, or ecdsa-sha2-*)."
  }
}

variable "user_data_template" {
  type        = string
  description = <<-EOT
    Path to a cloud-init template, rendered once per host with user_data_vars
    plus `hostname` (hostname_prefix + host key). Empty = no user_data.
  EOT
  default     = ""
}

variable "user_data_vars" {
  type        = map(string)
  description = "Template variables for user_data_template; `hostname` is set by the module."
  default     = {}
}

variable "ingress_rules" {
  type = map(object({
    protocol    = string
    port_min    = optional(number)
    port_max    = optional(number)
    source      = optional(string)
    description = string
  }))
  description = <<-EOT
    Extra NSG ingress rules beyond SSH, keyed by a stable name (the key is the
    Terraform address - renaming it recreates the rule). protocol: tcp | udp |
    icmp | all; source defaults to the VCN CIDR; port_max defaults to port_min.
  EOT
  default     = {}

  validation {
    condition     = alltrue([for r in values(var.ingress_rules) : contains(["tcp", "udp", "icmp", "all"], r.protocol)])
    error_message = "ingress_rules: protocol must be tcp, udp, icmp or all."
  }

  validation {
    condition     = alltrue([for r in values(var.ingress_rules) : !contains(["tcp", "udp"], r.protocol) || r.port_min != null])
    error_message = "ingress_rules: tcp and udp rules need port_min."
  }
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach SSH from outside the VCN. Empty = intra-VCN only."
  default     = []
}

variable "ssh_port" {
  type        = number
  description = "SSH port exposed by the NSG."
  default     = 22
}

variable "egress_https_only" {
  type        = bool
  description = <<-EOT
    Restrict NSG egress to TCP 443 plus intra-VCN traffic. Default false keeps
    the open egress patch labs need (MOS and AutoUpgrade downloads).
    Note: the subnet security list of the network module still allows its own
    common egress (DNS, NTP, HTTP 80, HTTPS 443, ICMP) - security lists and
    NSGs are evaluated as a union.
  EOT
  default     = false
}

# --- EOF ----------------------------------------------------------------------
