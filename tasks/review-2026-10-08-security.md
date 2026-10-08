# Security-Review oci-labs 2026-10-08 (quick)

<!-- markdownlint-disable MD013 MD022 MD032 MD060 -->

- rolle: security
- commit: fb5bedb
- modus: quick
- linse: docs/review-lens.md (Arbeitskopie, uncommittete Aenderung vorhanden)
- register: tasks/review-register.md (RA-oci-labs-001..013)
- history: nicht wiederholt - Orchestrator-Scan komplett (64/64 Commits), nur RA-oci-labs-001..003 (akzeptiert)
- RELEASE-BLOCKER: nein - kein echtes Credential in Baum oder Historie gefunden

## Invarianten am Code

| INV | Ergebnis | Beleg |
|---|---|---|
| INV-1 | erfuellt fuer Repo-Werte; Default-Passwort im Skript siehe F-04 | `git grep` auf PAR-Token, Private-Key-Bloecke, Fingerprints: 0 Treffer |
| INV-2 | verletzt - F-01, F-02 | terraform/envs/cpu-patch-test/variables.tf:311, Makefile:475 |
| INV-3 | erfuellt | `git ls-files .claude` liefert nur `.claude/aitk.toml`; CLAUDE.md liegt im Root (die Aussage "CLAUDE.md fehlt" in tasks/review-2026-10-08-scan-secrets.md ist falsch - die Linse erwartet sie im Root) |
| INV-4 | erfuellt | breiter OCID-Grep `ocid1\.[a-z0-9]+\.oc[0-9]+\.[a-z0-9-]*\.[a-z0-9]{20,}` ohne Platzhalter: 0 Treffer; Luecke im Gate siehe F-11 |
| INV-5 | erfuellt (ausser akzeptierte Altlasten) | zusaetzlich: kein OCID eines vom Gate nicht abgedeckten Typs in der Historie (`git log --all -p`) |
| INV-6 | verletzt - RA-oci-labs-005 weiterhin offen (F-14), Vermutung F-15 | 13 Zeilen in 10 Dateien |
| INV-7 | erfuellt fuer heutige Dateien, Luecken bei weiteren Mustern - F-10 | `git check-ignore` siehe F-10 |

## Befunde

### F-01 - Lab-Instanz ohne Auto-Stop als Default (cpu-patch-test)
- schwere: hoch
- rolle: security
- ort: terraform/envs/cpu-patch-test/variables.tf
- regel: INV-2
- beleg: terraform/envs/cpu-patch-test/variables.tf:308-312 - `enable_auto_stop` `default = false`; terraform/envs/cpu-patch-test/terraform.tfvars.example:66 - `enable_auto_stop = false`; Begruendung in terraform/envs/cpu-patch-test/README.md:238-240 (STOP mitten im AutoUpgrade-Lauf)
- ausloeser: wenn ein CPU-Lab nach dem Test nicht zerstoert wird, laeuft eine 8-OCPU-Instanz mit NOPASSWD-sudo fuer `oracle` und `opc` (ansible/roles/db19_engineering/defaults/main.yml:91-93) unbegrenzt weiter - genau das "schnell aufgesetzt, lange vergessen" aus dem Bedrohungsmodell
- aufwand: S
- fix: Auto-Stop per Default an und fuer die Dauer eines AutoUpgrade-Laufs gezielt aussetzen (z.B. Make-Target, das den Schedule pausiert und danach wieder aktiviert), statt ihn dauerhaft abzuschalten
- einstufung: Die Tabelle stuft einen Invariantenbruch als `kritisch` ein. Ich setze `hoch`, weil der Default allein keinen externen Zugang ohne Ablauf erzeugt (`assign_public_ip` Default false, variables.tf:247-256; Bastion-Session-TTL 3 h, Makefile:609) und der Trade-off dokumentiert ist - siehe OFFENE FRAGE 1

### F-02 - PAR-Lebensdauer ohne Obergrenze, Write-PAR bei Abbruch nicht widerrufen, SSH-Allow-List ohne Ablauf
- schwere: mittel
- rolle: security
- ort: Makefile
- regel: INV-2
- beleg: Makefile:475 - `PAR_DAYS ?= 7` ohne Plausibilitaetspruefung, geht ungeprueft in `--time-expires` (Makefile:481, 493); Makefile:545 - `GOLD_PAR_HOURS ?= 2` ebenso; Makefile:551-570 - Write-PAR (`AnyObjectWrite`) wird erst nach dem Playbook widerrufen, ohne `trap` - Ctrl-C oder ein Abbruch des Recipes zwischen 553 und 563 laesst ihn bis zum Ablauf gueltig; Makefile:708-722 - `cpu-lab-allow-ip` setzt eine SSH-Freigabe ohne Ablauf
- ausloeser: wenn jemand `PAR_DAYS=365` setzt, entsteht ein Jahres-Bearer-Token auf das 19c-Image ohne Warnung; wenn `cpu-lab-goldimage-push` abbricht, bleibt die bucket-weite Schreib-PAR bis zu GOLD_PAR_HOURS aktiv; eine per allow-ip geoeffnete SSH-Regel bleibt, bis jemand sie aendert
- aufwand: S
- fix: Obergrenze fuer PAR_DAYS/GOLD_PAR_HOURS erzwingen (Abbruch statt Warnung), den Widerruf der Write-PAR in einen `trap ... EXIT INT TERM` legen und die Allow-List-Freigabe an Auto-Stop/Destroy koppeln oder beim Stop entfernen

### F-03 - Bucket-Write-PAR und Read-PAR im argv (ps-sichtbar)
- schwere: mittel
- rolle: security
- ort: Makefile
- regel: secret
- beleg: Makefile:561 - `--tags goldimage_push -e db19_gold_image_par="$$uri"` (Write-PAR `AnyObjectWrite`, Makefile:555) als ansible-playbook-Argument; ansible/roles/db19_engineering/tasks/push_gold_image.yml:116-119 - derselbe PAR als Argument von `curl -X PUT` auf dem Lab-Host (no_log schuetzt nur die Ansible-Ausgabe, nicht die Prozessliste); Makefile:496-497 - Read-PAR als curl-Argument auf der Workstation
- ausloeser: wenn waehrend des mehrminuetigen GB-Uploads ein anderer lokaler Benutzer auf Workstation oder Lab-Host `ps -ef` liest, erhaelt er eine Schreibberechtigung auf den Bucket `orarepo` und kann ein Gold-Image ersetzen, das spaetere Labs als ORACLE_HOME installieren. Das widerspricht der eigenen Regel in Makefile:343-346 ("never on the command line")
- aufwand: S
- fix: PAR wie die anderen Secrets ueber die 0600-Vars-Datei (`cpu_lab_ansible_secrets`) an Ansible geben und auf dem Host per `curl --config <0600-datei>` bzw. `-K -` von stdin statt als Argument uebergeben

### F-04 - Skript setzt bekanntes Default-Passwort fuer den oracle-OS-User
- schwere: hoch
- rolle: security
- ort: tools/infra-tools/scripts/setup_common_os.sh
- regel: secret
- beleg: tools/infra-tools/scripts/setup_common_os.sh:199-205 - `echo "${ORACLE_USER}:${ORACLE_USER}" | chpasswd` (Passwort = Benutzername); Aufruf unbedingt in main, :251
- ausloeser: wenn das Skript auf einem Lab-Host laeuft und zusaetzlich SSH-Passwort-Login aktiv ist (plausibler Zusatzfehler: anderes Image, base_ssh-Rolle nicht angewendet), ist `oracle` mit einem im public Repo dokumentierten Passwort erreichbar; zusammen mit NOPASSWD-sudo fuer `oracle` (ansible/roles/db19_engineering/defaults/main.yml:91-92) ist das root
- aufwand: S
- fix: Funktion entfernen oder auf `passwd -l` (Account ohne Passwort, Zugang nur per Key) umstellen
- hinweis: Aktuell kein Aufrufer im Baum gefunden (`git grep setup_common_os` trifft nur die Datei selbst und einen Kommentar) - Vermutung, dass es manuell oder in Image-Builds genutzt wird; bei totem Code ist die Loeschung der Fix

### F-05 - Windows-AD-NSG oeffnet RDP, WinRM, LDAP, Kerberos, DNS fuer 0.0.0.0/0
- schwere: mittel
- rolle: security
- ort: terraform/modules/windows_ad/security.tf
- regel: network
- beleg: terraform/modules/windows_ad/security.tf:58-66 und 80-88 - `source = "0.0.0.0/0"` fuer alle Eintraege aus `nsg_tcp_rules`/`nsg_udp_rules` (3389, 5985, 5986, 389, 636, 88, 464, 53, 3268, 3269); die Security List begrenzt RDP dagegen auf `allowed_rdp_cidrs` (terraform/modules/network/main.tf:630-645)
- ausloeser: OCI wertet Security List und NSG als Vereinigung aus - die NSG hebelt `allowed_rdp_cidrs` damit aus. Wenn `assign_windows_public_ip = true` gesetzt und der Windows-Subnet-Route-Table eine IGW-Route bekommt (heute nur NAT/DRG, terraform/modules/network/main.tf:290-297; das Subnet erlaubt Public IPs, :749), sind RDP und WinRM des Domain Controllers aus dem Internet erreichbar
- aufwand: S
- fix: NSG-Quellen auf `var.vcn_cidr` plus `home_cidrs` bzw. `allowed_rdp_cidrs` setzen statt 0.0.0.0/0

### F-06 - Netzwerk-Modul oeffnet SSH und WireGuard per Default fuer 0.0.0.0/0; ad-cmu-test erbt das
- schwere: mittel
- rolle: security
- ort: terraform/modules/network/variables.tf
- regel: network
- beleg: terraform/modules/network/variables.tf:112-116 - `allowed_ssh_cidrs` `default = ["0.0.0.0/0"]`; :124-128 - `allowed_wireguard_cidrs` `default = ["0.0.0.0/0"]`; verwendet in der Public-Subnet-Security-List, terraform/modules/network/main.tf:374-403; terraform/envs/ad-cmu-test/main.tf:54-77 uebergibt `allowed_ssh_cidrs` nicht (core und cpu-patch-test uebergeben `[]` bzw. eigene Werte)
- ausloeser: wenn in ad-cmu-test (oder einer neuen Env, die das Argument vergisst) eine Instanz mit Public IP im Public Subnet landet, z.B. ein Jumphost, ist Port 22 aus dem ganzen Internet offen
- aufwand: S
- fix: Modul-Defaults auf `[]` setzen, damit eine Freigabe immer explizit ist

### F-07 - Windows-Administrator-Passwort dauerhaft in Instanz-Metadaten und in einer Datei auf dem DC
- schwere: mittel
- rolle: security
- ort: terraform/modules/windows_ad/templates/windows_ad-cloudinit.yaml.tftpl
- regel: secret
- beleg: terraform/modules/windows_ad/main.tf:30 - `admin_password_b64 = base64encode(var.admin_password_secret)`; :68 - Cloud-Init als `user_data`; windows_ad-cloudinit.yaml.tftpl:12 und :76-87 - das Passwort (Base64, also Klartext-aequivalent) wird in `00_init_environment.ps1` unter `C:\OraLab\Scripts` geschrieben und nicht entfernt
- ausloeser: wenn ein Lab-AD-Benutzer (das Lab legt Benutzer aus users_ad.csv an) sich am DC anmeldet oder ein Prozess auf dem DC den IMDS-Endpunkt liest, erhaelt er das Administrator- und damit Domain-Admin-Passwort fuer die ganze Lebensdauer der Instanz
- aufwand: M
- fix: Passwort nach dem Setup aus der Datei entfernen bzw. das Skript mit restriktiver ACL schreiben und nach Gebrauch loeschen, und das Passwort nach dem Bootstrap rotieren, damit der Metadaten-Wert wertlos wird
- hinweis: `are_legacy_imds_endpoints_disabled = true` (terraform/modules/windows_ad/main.tf:72) verhindert IMDSv1, nicht das Lesen durch lokale Prozesse

### F-08 - Ansible-Rolle windows_ad rendert das Admin-Passwort ohne no_log und laesst die Datei liegen
- schwere: mittel
- rolle: security
- ort: ansible/roles/windows_ad/tasks/main.yml
- regel: secret
- beleg: ansible/roles/windows_ad/tasks/main.yml:45-48 - `win_template` von `00_init_environment.ps1.j2` ohne `no_log`; ansible/roles/windows_ad/templates/00_init_environment.ps1.j2:31 - `$PlainPassword = "{{ windows_ad_admin_password }}"`; kein Aufraeum-Task am Ende der Rolle
- ausloeser: wenn die Rolle mit `--diff` oder erhoehter Verbositaet laeuft, steht das Passwort im Terminal bzw. Log; die Datei bleibt danach auf dem DC lesbar (wie F-07). Die db19-Rolle zeigt das richtige Muster (credentials.yml:66-95, `no_log` plus `always`-Loeschung)
- aufwand: S
- fix: `no_log: true` am Template-Task und Loeschen der Datei in einem `always`-Block wie in credentials.yml

### F-09 - Windows-Bootstrap laedt und startet ungepinnten Code von einem Branch
- schwere: mittel
- rolle: security
- ort: terraform/modules/windows_ad/templates/windows_ad-cloudinit.yaml.tftpl
- regel: pinning
- beleg: terraform/modules/windows_ad/templates/windows_ad-cloudinit.yaml.tftpl:60 - `Invoke-WebRequest -Uri 'https://github.com/oehrlis/ad-lab/archive/refs/heads/main.zip'`, ohne Checksumme; die Skripte laufen danach als Administrator (ansible/roles/windows_ad/tasks/main.yml:51-118)
- ausloeser: wenn `main` von ad-lab kompromittiert oder versehentlich geaendert wird, fuehrt jeder neue DC den neuen Stand mit Domain-Admin-Rechten aus, ohne dass sich in oci-labs etwas aendert
- aufwand: S
- fix: auf einen Tag oder Commit-SHA pinnen und den SHA-256 des Archivs pruefen (Muster wie .github/workflows/gitleaks.yml:36)

### F-10 - .gitignore deckt auto.tfvars, Plan-Dateien und .ssh/ nicht repo-weit ab
- schwere: mittel
- rolle: security
- ort: .gitignore
- regel: INV-7
- beleg: .gitignore:9-13 - nur `**/terraform.tfvars` und `**/.env`; kein `*.auto.tfvars`, kein `.ssh/`, kein `tfplan`; die env-eigenen .gitignore gibt es nur in terraform/envs/core und terraform/envs/cpu-patch-test - `git check-ignore` meldet `terraform/envs/ad-cmu-test/.ssh/id` und `terraform/envs/mfa_oma_setup/.ssh/id` als NICHT ignoriert; ein `tfplan` in ad-cmu-test oder mfa_oma_setup waere ebenfalls nicht ignoriert
- ausloeser: wenn jemand das Windows-Admin-Passwort in eine `secrets.auto.tfvars` legt (Terraform laedt sie automatisch) oder einen Plan in ad-cmu-test speichert (der Plan enthaelt sensitive Werte im Klartext), landet das mit `git add .` im public Repo - das Pre-commit-Gate faengt Passwoerter ohne bekanntes Muster nicht
- aufwand: S
- fix: `**/*.auto.tfvars`, `**/*.tfvars` mit `!*.tfvars.example`, `**/.ssh/`, `**/tfplan*`, `**/.env.*` mit `!.env.example` in die Root-.gitignore aufnehmen

### F-11 - gitleaks-OCID-Regel deckt nur 16 Ressourcentypen ab
- schwere: niedrig
- rolle: security
- ort: .gitleaks.toml
- regel: INV-4
- beleg: .gitleaks.toml:38 - Typ-Liste `tenancy|user|compartment|instance|vcn|subnet|drg|...|policy`; nicht erfasst u.a. `bastion`, `bastionsession`, `natgateway`, `internetgateway`, `securitylist`, `networksecuritygroup`, `routetable`, `volume`, `bootvolume`, `image`, `publicip`, `domain`, `resourceschedule` - genau die Typen, die dieses Repo anlegt
- ausloeser: wenn eine echte Bastion- oder Subnetz-fremde OCID in Doku oder Runbook kopiert wird, meldet CI und Pre-commit gruen, obwohl INV-4 verletzt ist. Heute kein solcher Treffer in Baum und Historie (geprueft)
- aufwand: S
- fix: Typ-Liste durch `[a-z0-9]+` ersetzen und die Platzhalter-Allowlist beibehalten

### F-12 - CI-Scan eines Pull Requests nutzt die .gitleaks.toml aus dem PR
- schwere: niedrig
- rolle: security
- ort: .gitleaks.toml
- regel: ci-gate
- beleg: .github/workflows/gitleaks.yml:14 - `pull_request`; :48-49 - `--config .gitleaks.toml` aus dem ausgecheckten PR-Stand
- ausloeser: wenn ein PR (das Repo ist public) zugleich ein Secret und einen passenden `[[allowlists]]`-Eintrag einfuehrt, ist der Check gruen; nur Review der .gitleaks.toml faengt das
- aufwand: S
- fix: Allowlist-Aenderungen per CODEOWNERS bzw. Pflicht-Review schuetzen oder in der CI die Config aus dem Basis-Branch laden

### F-13 - Doku empfiehlt Secrets als `-e ...` im argv, entgegen der Makefile-Regel
- schwere: niedrig
- rolle: security
- ort: ansible/roles/db19_engineering/tasks/credentials.yml
- regel: doc-drift
- beleg: ansible/roles/db19_engineering/tasks/credentials.yml:48-50 - `-e mos_password="$(op read ...)"`; ansible/roles/db19_engineering/tasks/create_db.yml:26; terraform/envs/cpu-patch-test/outputs.tf:32 und :41; terraform/envs/cpu-patch-test/.env.example:63 - alles gegen Makefile:343-346 ("never on the command line")
- ausloeser: wenn jemand der Fehlermeldung des Asserts folgt statt `make cpu-lab-*` zu nutzen, stehen MOS-Passwort und SYS-Passwort fuer die ganze Laufzeit (AutoUpgrade: eine Stunde) in `ps`
- aufwand: S
- fix: die Beispiele auf `-e @<0600-datei>` bzw. den Make-Weg umstellen

### F-14 - Object-Storage-Namespace des Lab-Tenants im Baum (RA-oci-labs-005, weiterhin offen)
- schwere: mittel
- rolle: security
- ort: docs/review-lens.md
- regel: INV-6
- beleg: 13 Zeilen in 10 getrackten Dateien, unveraendert gegenueber dem Register - CHANGELOG.md:27; docs/runbook-cpu-patch-lab.md:14,118,161; tasks/plan-cpu-lab.md:75; tasks/state-2026-08-28.md:8; terraform/envs/core/README.md:55; terraform/envs/core/terraform.tfvars.example:14; terraform/envs/cpu-patch-test/.env.example:71,77; terraform/envs/cpu-patch-test/README.md:20; terraform/modules/core/main.tf:69; tools/upload_bootstrap.sh:27 - Wert jeweils `<namespace>`
- ausloeser: wenn ein Leser des public Repos den Namespace kennt, kennt er das Ziel jeder PAR-URL des Labs und den Tenancy-Kontext
- aufwand: S
- fix: Owner-Entscheid treffen - entweder `akzeptiert` mit Begruendung im Register oder durch `<namespace>` ersetzen

### F-15 - OCI-CLI-Profilname und Compartment-Name als Defaults im Baum
- schwere: niedrig
- rolle: security
- ort: Makefile
- regel: INV-6
- beleg: Makefile:405, 423, 480 (u.a., 9 Zeilen im Makefile) - `profile="$${profile:-<profilname>}"`; Profilname insgesamt in 16 getrackten Dateien, darunter terraform/envs/cpu-patch-test/provider.tf und variables.tf; Compartment-Name in terraform/envs/cpu-patch-test/.env.example:16 und ansible/roles/db19_engineering/defaults/main.yml
- ausloeser: Vermutung: der Profilname entspricht dem Tenancy-Namen bzw. dem Namespace-Praefix - dann faellt er unter INV-6; beide Klassen stehen in der Linse unter "Sensible Namen"
- aufwand: S
- fix: Profil-Default auf `DEFAULT` setzen und den echten Namen nur aus der gitignorierten .env lesen; Entscheid zusammen mit F-14

## Gepruefte Secret-Treffer

| Treffer | Bewertung | Beleg |
|---|---|---|
| Namespace des Lab-Tenants | echt, Identifikator, kein Credential - F-14 | 13 Zeilen, siehe F-14 |
| `ocid1....xxx` in tfvars.example und .env.example | Beispiel (Platzhalter) | terraform/envs/cpu-patch-test/terraform.tfvars.example:18, terraform/envs/ad-cmu-test/terraform.tfvars.example:15 |
| PAR-URL `/p/<token>/` | Beispiel | terraform/envs/cpu-patch-test/.env.example:77 |
| `203.0.113.10/32` | Beispiel (RFC 5737 Dokumentationsnetz) | terraform/envs/cpu-patch-test/terraform.tfvars.example:44 |
| `op://secrets/Oracle-MOS/...` | False Positive - 1Password-Referenz, kein Wert | Makefile:56-57 |
| `mos_password: ""`, `db19_sys_password: ""` | False Positive - leere Defaults mit Assert | ansible/roles/db19_engineering/defaults/main.yml:372, 381, 443 |
| `random_password`, Outputs `db_sys_password`, `smtp_password`, Client-Secret | False Positive - generiert, `sensitive = true`, nur im lokalen State | terraform/envs/cpu-patch-test/outputs.tf:29-44, terraform/envs/mfa_oma_setup/outputs.tf:28-29, 53-55 |
| Smoke-Test-Passwort | False Positive - pro Lauf generiert, `no_log` | ansible/roles/db19_engineering/tasks/smoke.yml:38-41 |
| `oracle:oracle` | echt im Sinne eines bekannten Default-Credentials - F-04 | tools/infra-tools/scripts/setup_common_os.sh:202 |
| E-Mail-Adressen | False Positive - Autor-Header, Doku-Beispiele | laut tasks/review-2026-10-08-scan-secrets.md |

## Was gut ist (nicht umbauen)

- Secrets an Ansible ueber 0600-Datei mit `umask 077`, `mktemp` und `trap` (Makefile:351-362); Werte via Environment statt argv an python3
- `no_log` konsequent in der db19-Rolle; Expect-Skript mit MOS-Passwort 0700 und im `always`-Block geloescht (credentials.yml:66-95); dbca-Response-Datei 0600 und danach entfernt (create_db.yml:109-152); Data-Pump-Credential im Parfile unter `umask 077`, sofort geloescht (smoke.yml:173-204)
- Netz-Defaults der Envs: `assign_public_ip = false`, `assign_windows_public_ip = false`, `allowed_ssh_cidrs = []`, `allowed_rdp_cidrs = []`; DB-Listener nur intra-VCN (oracle_db_host/security.tf:64-79)
- IMDSv2 erzwungen und PV-Verschluesselung in transit auf beiden Instanz-Modulen
- Artefakt-Bucket `NoPublicAccess` (terraform/modules/core/main.tf:83)
- IAM: einzige Policy ist gruppen- und compartment-gebunden auf `email-family` (terraform/modules/iam_mfa_oma/main.tf:172-174); keine Dynamic Groups
- Read-PAR `ObjectRead` auf ein Objekt, Write-PAR 2 h mit Widerruf, Token in der Ausgabe redigiert (Makefile:504, 558); Bastion-Session-TTL 3 h (Makefile:609, 629)
- Terraform-Schluessel `local_sensitive_file` 0600 in 0700-Verzeichnis, Inventory 0600 in gitignoriertem Pfad
- ad-cmu-test hat einen taeglichen Auto-Stop (terraform/envs/ad-cmu-test/main.tf:129-148)
- Gates: gitleaks-Workflow mit `permissions: contents: read`, Checkout per Commit-SHA, `persist-credentials: false`, gitleaks-Binary per Version plus SHA-256; Allowlists auf Commit UND Pfad UND Regel begrenzt; Pre-commit-Hook scheitert geschlossen (fehlendes gitleaks oder fehlende Config blockiert); `make hooks` ueberschreibt fremde Hooks nicht still; Makefile laeuft mit `-eu -o pipefail`

## OFFENE FRAGEN

- OFFENE FRAGE 1: Ist der Auto-Stop-Default `false` in cpu-patch-test ein bewusster Owner-Entscheid gegen INV-2? - angenommen: nein, daher F-01 als Befund (`hoch` statt `kritisch`, Begruendung in F-01); bei Ja wird F-01 `akzeptiert` mit Name und Datum
- OFFENE FRAGE 2: Faellt der Arbeitgebername in technischen Kommentaren unter "Kurznamen von Arbeitgeber" der Linse? Treffer u.a. Makefile:464 ("Accenture monitoring thresholds"), terraform/modules/oracle_db_host/main.tf:12, 74, 79, 118, terraform/envs/cpu-patch-test/README.md:99 - angenommen: bewusst oeffentlich (Standard-Referenz), daher kein Befund
- OFFENE FRAGE 3: Wird tools/infra-tools/scripts/setup_common_os.sh noch genutzt? - angenommen: ja (konservativ), daher F-04 `hoch`

## BLOCKIERT

- BLOCKIERT: IaC-Scanner (tfsec, checkov) - nicht installiert, Security-Lists/NSGs/IAM nur von Hand geprueft - `brew install tfsec checkov && tfsec terraform/ && checkov -d terraform/`
- BLOCKIERT: Hand-Grep auf sensible Namen nach privater Liste - `~/notes/docs/repo-audit-framework.md` enthaelt keine konkrete Namensliste fuer oci-labs (die Linse verweist darauf); geprueft nur mit Fallback-Muster und den Klassen Namespace, Profil-, Compartment-, Arbeitgebername - Liste in der Datei ergaenzen, dann `git grep -n -i -f <liste>`
- BLOCKIERT: Dateirechte der lokalen Secret-Artefakte (.ssh/, generiertes Inventory, .env, tfstate) am Artefakt - `stat` auf .env durch Deny-Regel gesperrt; nur am Code belegt (main.tf:181-196, 405-409) - `stat -f '%Sp %N' terraform/envs/cpu-patch-test/.ssh/* ansible/inventories/generated/cpu-patch-test/hosts.yml terraform/envs/*/terraform.tfstate`
- BLOCKIERT: externes Repo oehrlis/ad-lab (Skripte, die F-09 als Administrator startet, und default_pwd_windows.txt) - ausserhalb des Scopes dieses Laufs - eigener Lauf `/repo-audit` im ad-lab-Repo
- BLOCKIERT: History-Scan - bewusst nicht wiederholt, vom Orchestrator komplett gelaufen (64/64 Commits, nur RA-oci-labs-001..003) - `gitleaks git --config .gitleaks.toml --redact --log-opts=--all .`

## Register-Abgleich

- RA-oci-labs-005: weiterhin offen (F-14, gleicher ort/regel)
- RA-oci-labs-004, -006, -007: behoben bestaetigt (keine echten OCIDs im Runbook; Workflow und Hook vorhanden und wirksam)
- akzeptiert, nicht gemeldet: RA-oci-labs-001, RA-oci-labs-002, RA-oci-labs-003
- Achtung Schluessel: F-12 nutzt bewusst `ort: .gitleaks.toml` statt `.github/workflows/gitleaks.yml`, damit der Checker RA-oci-labs-006 (gleiche regel `ci-gate`) nicht faelschlich als regressiert fuehrt
