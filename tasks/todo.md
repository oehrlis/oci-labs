# windows_ad Lab-Modul - Implementation Plan

## Ziel

Neues Lab-Modul `windows_ad` für Oracle CMU + Kerberos-Tests.
Stack-Code: `windc` | Domain: `trivadislabs.com`

---

## Aufgabe 1 - Network-Modul erweitern

**Dateien:** `terraform/modules/network/`

### variables.tf - Ergaenzungen

- `windows_subnet_cidr` (string, default `"10.19.50.0/24"`)
  > Hinweis: default aus Task-Spec war `10.0.3.0/24` - nicht im VCN-Range 10.19.0.0/16.
  > Korrigiert auf `10.19.50.0/24` (naechste freie /24 in der Sequenz).
  > Bitte bestaetigen.

### main.tf - Ergaenzungen

Neue Ressourcen (analog zu db/app):

- `locals`: `windows_subnet_name`, `windows_sl_name`, `windows_rt_name`
- `oci_core_route_table.windows` mit NAT-Gateway-Route
- `oci_core_security_list.windows` mit:
  - Ingress aus VCN: RDP 3389, WinRM 5985/5986, LDAP 389/636,
    Kerberos TCP+UDP 88/464, DNS TCP+UDP 53, Global Catalog 3268/3269, ICMP
  - Egress: `common_egress_rules` + Windows Update (HTTP/HTTPS bereits drin)
- `oci_core_subnet.windows` (prohibit_public_ip: true)
- Flow-Log-Eintrag in `local.flow_log_targets`

### outputs.tf - Ergaenzung

- `windows_subnet_id`

---

## Aufgabe 2 - Terraform-Modul windows_ad

**Verzeichnis:** `terraform/modules/windows_ad/`

### variables.tf

| Variable | Typ | Default | Pflicht |
|---|---|---|---|
| `compartment_ocid` | string | - | ja |
| `lab_name_core` | string | - | ja |
| `freeform_tags` | map(string) | `{}` | nein |
| `subnet_id` | string | - | ja |
| `instance_image_ocid` | string | - | ja |
| `ssh_authorized_keys` | string | - | ja (WinRM-key fuer OCI Metadata) |
| `shape` | string | `"VM.Standard3.Flex"` | nein |
| `ocpus` | number | `2` | nein |
| `memory_gbs` | number | `16` | nein |
| `domain_name` | string | `"trivadislabs.com"` | nein |
| `admin_password_secret` | string | - | ja (1Password ref) |
| `boot_volume_size_gbs` | number | `100` | nein |
| `availability_domain` | string | - | ja |
| `assign_public_ip` | bool | `false` | nein |

### main.tf

Locals:
```
instance_display_name = "ci-${var.lab_name_core}-windc-01"
hostname_label        = "windc01"
```

Ressource `oci_core_instance.windows_ad`:
- shape: VM.Standard3.Flex (x86, kein ARM)
- metadata: `user_data` = base64(templatefile(cloudinit-template))
- `instance_options { are_legacy_imds_endpoints_disabled = true }`
- `is_pv_encryption_in_transit_enabled = true`
- `lifecycle { ignore_changes = [source_details[0].source_id] }`

### security.tf

NSG `oci_core_network_security_group.windows_ad` mit Rules:
- Ingress: RDP 3389, WinRM 5985/5986, LDAP 389/636,
  Kerberos 88/464 (TCP+UDP), DNS 53 (TCP+UDP), GC 3268/3269
- Egress: all (0.0.0.0/0, all protocols)

### outputs.tf

- `instance_id`, `public_ip`, `private_ip`, `instance_name`

### templates/windows_ad-cloudinit.yaml.tftpl

cloudbase-init fuer:
- WinRM aktivieren (HTTPS + Basic Auth)
- Firewall-Regeln fuer WinRM oeffnen
- domain_name als Environment-Variable setzen

---

## Aufgabe 3 - Env ad-cmu-test

**Verzeichnis:** `terraform/envs/ad-cmu-test/`

### provider.tf

Analog zu odb19eng-single: OCI-Provider >= 5.0, config_file_profile DEFAULT.

### variables.tf

- Core: compartment_ocid, region_key, environment_code (default "l"),
  stack_code (default "windc"), lab_instance (default 1)
- Network: vcn_cidr, public_subnet_cidr, private_subnet_cidr,
  windows_subnet_cidr (default 10.19.50.0/24)
- Windows AD: windows_shape, windows_ocpus, windows_memory_gbs,
  windows_os_version (default "2022"), domain_name, admin_password_secret
- Tags: common_freeform_tags

### main.tf

Komposition:
1. `module.naming` (region_key, environment_code, stack_code="windc", lab_instance)
2. `data.oci_identity_availability_domains`
3. `module.network` (mit windows_subnet_cidr)
4. `data.oci_core_images.windows_image` (Windows Server 2022, VM.Standard3.Flex)
5. `module.windows_ad` (subnet_id = module.network.windows_subnet_id)

### outputs.tf

- `windows_public_ip`, `windows_private_ip`, `vcn_id`, `windows_subnet_id`

### terraform.tfvars

Template mit Platzhaltern (kein Secret-Commit):
```hcl
compartment_ocid     = "ocid1.compartment.oc1.."
region_key           = "chzh"
domain_name          = "trivadislabs.com"
admin_password_secret = "op://AI-DevOps/WinDC/password"
```

---

## Aufgabe 4 - Ansible Role windows_ad

**Verzeichnis:** `ansible/roles/windows_ad/`

### defaults/main.yml

```yaml
windows_ad_domain: "trivadislabs.com"
windows_ad_admin_user: "Administrator"
windows_ad_scripts_src: "{{ playbook_dir }}/../../../ad-lab"
windows_ad_company: "Trivadis Labs"
windows_ad_netbios: "TRIVADISLABS"
```

### tasks/main.yml (10 Tasks, FQCN ansible.windows.*)

1. `ansible.windows.win_ping` - WinRM-Verbindung pruefen
2. `ansible.windows.win_file` - Zielverzeichnis erstellen
3. `ansible.windows.win_copy` - ad-lab Scripts kopieren
4. `ansible.windows.win_template` - 00_init_environment.ps1 rendern
5. `ansible.windows.win_shell` - 01_install_ad_role.ps1 + `ansible.builtin.reboot`
6. `ansible.windows.win_wait_for` - LDAP Port 389 warten
7. `ansible.windows.win_shell` - 11_add_lab_company.ps1
8. `ansible.windows.win_shell` - 11_add_service_principles.ps1
9. `ansible.windows.win_shell` - 12_config_dns.ps1
10. `ansible.windows.win_shell` - 13_config_ca.ps1 + 27_config_cmu.ps1

### templates/00_init_environment.ps1.j2

Jinja2-Template: setzt DOMAIN, COMPANY, NETBIOS, Passwort-Variablen.

### ansible/playbooks/lab-ad-cmu.yml

```yaml
- hosts: windows_dc
  connection: winrm
  gather_facts: true
  roles:
    - role: windows_ad
```

---

## Reihenfolge & Commits

1. Aufgabe 1 - Network erweitern → `feat(network): add windows subnet and AD security list`
2. Aufgabe 2 - Modul windows_ad → `feat(windows_ad): add Terraform module for Windows AD`
3. Aufgabe 3 - Env ad-cmu-test → `feat(ad-cmu-test): add env stack for Windows AD CMU lab`
4. Aufgabe 4 - Ansible Role → `feat(ansible): add windows_ad role and lab-ad-cmu playbook`

---

## Offene Fragen (vor Start)

- [ ] Windows-Subnet CIDR: `10.19.50.0/24` statt `10.0.3.0/24` (ausserhalb VCN-Range)?
- [ ] NSG zusaetzlich zur Security List, oder nur Security List (wie bei anderen Subnets)?
- [ ] `admin_password_secret`: direkt `sensitive` Variable oder nur als 1Password-Ref-String?
