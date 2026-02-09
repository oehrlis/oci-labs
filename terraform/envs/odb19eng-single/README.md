Genau, bevor wir in Ansible-Rollen einsteigen, ist ein **“Smoke Test”** von Infra + Jumphost perfekt. 👍
Lass uns einen kleinen, klaren Testfahrplan machen, ohne noch mehr neue Module zu erfinden.

Ich schlage vor:

1. **Minimal-Lab = VCN + Jumphost** (DB19-Module vorerst auskommentiert)
2. **Image-OCID als Variable reinziehen**
3. **Terraform lokal laufen lassen**
4. **Per SSH auf den Jumphost → checken, ob Cloud-Init gemacht hat, was es soll**

Dann wissen wir: Naming-Modul, Network-Modul, Jumphost-Modul, Cloud-Init → alles verdrahtet.

---

## 1️⃣ Minimal-Lab stack: nur Network + Jumphost

Im Stack `oci-labs-infra/labs/odb19eng-single`:

### a) `variables.tf` ergänzen (Image-OCID)

Füge hier noch die Image-Variable für den Jumphost dazu:

```hcl
variable "jumphost_image_ocid" {
  type        = string
  description = "Image OCID for the jumphost (Oracle Linux 8/9 in the chosen region)."
}
```

> Den Wert holst du dir einmalig aus der OCI Console (Compute → Instances → Create → Platform images → Oracle Linux → Details → OCID kopieren) oder per CLI.

(Die DB-Image-Variable für später können wir danach ergänzen.)

---

### b) `main.tf` – Naming + Network + Jumphost (DB noch auskommentiert)

Ich zeige dir eine bereinigte Version, die das **Naming-Modul** nutzt und **nur** Network + Jumphost testet:

```hcl
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }
}

provider "oci" {}

# ---------------------------------------------------------------------------
# Naming module
# ---------------------------------------------------------------------------

module "naming" {
  source               = "../../modules/naming"
  region_key           = var.region_key
  environment_code     = var.environment_code
  stack_code           = var.stack_code
  lab_instance         = var.lab_instance
  common_freeform_tags = var.common_freeform_tags
}

# Convenience locals
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
  db_subnet_cidr      = var.db_subnet_cidr
  app_subnet_cidr     = var.app_subnet_cidr

  internet_gateway_enabled = true
  nat_gateway_enabled      = true

  enable_flow_logs            = var.enable_flow_logs
  flow_log_retention_duration = var.flow_log_retention_duration

  allowed_ssh_cidrs      = var.allowed_ssh_cidrs
  ssh_port               = var.ssh_port
  allowed_wireguard_cidrs = var.allowed_wireguard_cidrs
  wireguard_port         = var.wireguard_port
  allow_public_http_https = false
}

# ---------------------------------------------------------------------------
# Jumphost / Gateway
# ---------------------------------------------------------------------------

module "jumphost_gateway" {
  source = "../../modules/jumphost_gateway"

  compartment_ocid    = var.compartment_ocid
  availability_domain = local.availability_domain
  subnet_id           = module.network.public_subnet_id

  lab_name_core = local.lab_name_core
  freeform_tags = local.base_freeform_tags

  shape  = var.jumphost_shape
  ocpus  = var.jumphost_ocpus
  memory_gbs = var.jumphost_memory_gbs

  assign_public_ip = true

  ssh_authorized_keys = var.ssh_authorized_keys
  ssh_port            = var.ssh_port
  enable_wireguard    = var.enable_wireguard

  instance_image_ocid   = var.jumphost_image_ocid
  boot_volume_size_gbs  = 20
}

# ---------------------------------------------------------------------------
# DB19 Engineering – vorerst für den Test *deaktiviert*
# ---------------------------------------------------------------------------

# module "db19_engineering" {
#   source = "../../modules/db19_engineering"
#
#   compartment_ocid    = var.compartment_ocid
#   availability_domain = local.availability_domain
#   subnet_id           = module.network.db_subnet_id
#
#   lab_name_core = local.lab_name_core
#   freeform_tags = local.base_freeform_tags
#
#   instance_image_ocid = var.db19_image_ocid
#   db_host_count       = var.db_host_count
#
#   hostname_prefix      = "db19"
#   ssh_authorized_keys  = var.ssh_authorized_keys
#   ssh_port             = 22
#   open_db_ports        = true
#   db_listener_port     = 1521
#   db_oem_port          = 5500
# }
```

Damit haben wir ein **sauberes, testbares Minimum**.

---

### c) `outputs.tf` – fürs Testing genug Infos

Für den Test brauchen wir vor allem:

* Lab-Name-Core
* Jumphost Public/Private IP
* VCN/Subnet IDs – nice to have

```hcl
output "lab_name_core" {
  description = "Core lab name segment used in resource names."
  value       = local.lab_name_core
}

output "jumphost_public_ip" {
  description = "Public IP address of the jumphost/gateway."
  value       = module.jumphost_gateway.public_ip
}

output "jumphost_private_ip" {
  description = "Private IP address of the jumphost/gateway."
  value       = module.jumphost_gateway.private_ip
}

output "vcn_id" {
  description = "OCID of the lab VCN."
  value       = module.network.vcn_id
}
```

`inventory-output.tf` können wir für den allerersten Test noch weglassen oder schon drin lassen (DB-Modul ist ja noch aus).

---

## 2️⃣ Testschritte lokal

Im Verzeichnis `oci-labs-infra/labs/odb19eng-single`:

### 1. Terraform initialisieren

```bash
terraform init
```

### 2. Apply mit minimalen Parametern

```bash
terraform apply \
  -var "compartment_ocid=ocid1.compartment.oc1...." \
  -var "region_key=chzh" \
  -var "jumphost_image_ocid=ocid1.image.oc1...." \
  -var "ssh_authorized_keys=$(cat ~/.ssh/id_rsa.pub)"
```

Wenn dein Tenant SSH lieber auf Port 22 mag, kannst du `-var "ssh_port=22"` setzen – das Netzmodul und der Jumphost respektieren das.

---

## 3️⃣ Prüfen, ob alles tut

### a) In der OCI Console

* VCN existiert?
* Subnets:

  * `sn-...-public-01`
  * `sn-...-private-01`
  * `sn-...-db-01`
  * `sn-...-app-01`
* Route-Tables / SecLists passen?
* Log Group + Flow Log für die VCN vorhanden?
* Compute-Instanz:

  * Name `ci-<lab_name_core>-gw-01`
  * Shape Ampere mit 1 OCPU / 16GB
  * Public IP ist vergeben?

### b) SSH auf den Jumphost

```bash
ssh -p 16022 opc@<jumphost_public_ip>
```

oder mit Port 22, je nachdem.

Auf der Maschine dann:

```bash
# Check OS & Basic config
cat /etc/os-release

# SSH-Port wirklich geändert?
sudo ss -tnlp | grep sshd

# firewalld aktiv?
sudo systemctl status firewalld

# fail2ban aktiv?
sudo systemctl status fail2ban

# WireGuard-Paket vorhanden, wenn enable_wireguard=true
rpm -qa | grep -i wireguard
```

Wenn das alles passt, wissen wir:

* Naming-Modul → ok
* Network-Modul → ok (Routing, IGW/NAT, SecLists)
* Jumphost-Modul + Cloud-Init-Template → ok

**Dann** lohnt sich der nächste Schritt: DB19-Engineering-Modul aktivieren + erstes Ansible-Playbook.

---

Wenn du magst, machen wir direkt im nächsten Schritt:

* **DB19-Engineering in den Lab-Stack einhängen** (Modul-Block wieder einkommentieren, `db19_image_ocid` Variable ergänzen)
* und danach die erste **Ansible-Rolle `db19_engineering` + Playbook** im `oci-labs-config`-Repo.
