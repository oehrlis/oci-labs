# oci-labs - Task Board

## Session: 2026-06-26 - windows_ad Lab-Modul

### Erledigt

- [x] **Aufgabe 1** - Network-Modul: Windows-Subnet (10.19.50.0/24), Security List (AD-Ports), outputs
- [x] **Aufgabe 2** - Modul `modules/windows_ad`: variables, main, security (NSG), outputs, cloudinit-template
- [x] **Aufgabe 3** - Env `envs/ad-cmu-test`: provider (ACE-Profil), variables, main, outputs, tfvars
- [x] **Aufgabe 4** - Ansible: role `windows_ad` (10 Tasks, FQCN), playbook `lab-ad-cmu.yml`
- [x] CHANGELOG.md erstellt, VERSION auf 0.2.0 gesetzt
- [x] Runbook `docs/runbook-ad-cmu-lab.md` erstellt
- [x] `docs/architecture-overview.md` befuellt

---

## Offene Punkte (naechste Session)

### Sofort - uncommitted Changes commiten

- [x] Commit: Stefan's Korrekturen an windows_ad Modul + env (v0.2.1)
- [ ] Pruefen: `terraform/envs/mfa_oma_setup/.env` - ggf. zu .gitignore hinzufuegen (Secrets!)

### Infrastruktur

- [ ] `cd terraform/envs/ad-cmu-test && terraform init && terraform validate`
- [ ] `terraform plan` reviewen (VCN + Windows DC + DRG-Attachment + auto-stop Schedule)
- [ ] `TF_VAR_admin_password_secret=$(op read "op://AI-DevOps/WinDC/password") terraform apply`
- [ ] DRG-Attachment in `main.tf` pruefen/hinzufuegen (home_cidrs -> DRG -> OCI VCN)
  - DRG OCID: `ocid1.drg.oc1.eu-zurich-1.aaaaaaaa6lag2...`
  - Home CIDRs: 192.168.1.0/24, 10.8.0.0/24

### Ansible

- [ ] ad-lab Scripts klonen: `git clone https://github.com/oehrlis/ad-lab.git` (adjacent zu oci-labs)
- [ ] Ansible Inventory erstellen: `ansible/inventories/ad-cmu-test/hosts.yml` (IP aus TF output)
- [ ] group_vars/windows_dc.yml anlegen (domain=oradba.ch, etc.) - ggf. Vault verschluesseln
- [ ] Playbook testen: `ansible-playbook playbooks/lab-ad-cmu.yml -i inventories/ad-cmu-test/`

### Validierung

- [ ] AD-Domain `oradba.ch` pruefen: ad-lab Scripts erwarten ggf. `trivadislabs.com` hardcoded
- [ ] WinRM von Home-Lab erreichbar via DRG/VPN (nach DRG-Attachment)
- [ ] Oracle DB CMU/Kerberos Konfiguration auf DB-Server (krb5.conf, sqlnet.ora, keytab)

### Abschluss

- [ ] `git push` (14 Commits noch nicht gepusht)

---

## Kontext / Schluesseldaten

```
OCI Profil:     ACE
Compartment:    cmp-oradba-labs (ocid1.compartment.oc1..aaaaaaaaxq7bir...)
Region:         eu-zurich-1 (region_key: chzh)
Stack-Name:     chzh-l-windc-01
Windows Image:  ocid1.image.oc1.eu-zurich-1.aaaaaaaanrw7bmj2... (Server 2022 Std)
AD Domain:      oradba.ch
Shape:          VM.Standard.E4.Flex, 2 OCPUs, 8 GB
DRG:            ocid1.drg.oc1.eu-zurich-1.aaaaaaaa6lag2...
Secret:         op read "op://AI-DevOps/WinDC/password"
```
