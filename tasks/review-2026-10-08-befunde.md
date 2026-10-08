# Befunde 2026-10-08 (konsolidiert)

<!-- markdownlint-disable MD001 MD013 MD022 MD029 MD032 -->

- rollen: security, doku-tests
- commit: fb5bedb

### F-01 - Lab-Instanz ohne Auto-Stop als Default (cpu-patch-test)
- schwere: kritisch
- rolle: security
- ort: terraform/envs/cpu-patch-test/variables.tf
- regel: INV-2
- beleg: terraform/envs/cpu-patch-test/variables.tf:308-312 - `enable_auto_stop` `default = false` (am Artefakt bestaetigt); terraform/envs/cpu-patch-test/terraform.tfvars.example:66 - `enable_auto_stop = false`; terraform/envs/cpu-patch-test/main.tf:343 - Schedule nur bei true; Begruendung terraform/envs/cpu-patch-test/README.md:238-240 (STOP mitten im AutoUpgrade-Lauf)
- ausloeser: wenn ein CPU-Lab nach dem Test nicht zerstoert wird, laeuft eine 8-OCPU-Instanz mit NOPASSWD-sudo fuer `oracle` und `opc` (ansible/roles/db19_engineering/defaults/main.yml:91-93) unbegrenzt weiter - genau "schnell aufgesetzt, lange vergessen" aus dem Bedrohungsmodell
- aufwand: S
- fix: Auto-Stop per Default einschalten und nur fuer die Dauer eines AutoUpgrade-Laufs gezielt pausieren (Make-Target, das den Schedule aussetzt und danach wieder aktiviert), statt ihn dauerhaft abzuschalten

### F-02 - Bucket-Write-PAR und Read-PAR im argv (ps-sichtbar)
- schwere: mittel
- rolle: security
- ort: Makefile
- regel: secret
- beleg: Makefile:561 - `-e db19_gold_image_par="$$uri"` (Write-PAR `AnyObjectWrite`, Makefile:555) als ansible-playbook-Argument (am Artefakt bestaetigt); ansible/roles/db19_engineering/tasks/push_gold_image.yml:116-119 - derselbe PAR als `curl -X PUT`-Argument auf dem Lab-Host (no_log schuetzt nur die Ansible-Ausgabe); Makefile:496-497 - Read-PAR als curl-Argument auf der Workstation; Widerspruch zu Makefile:343-346 ("never on the command line")
- ausloeser: wenn waehrend des mehrminuetigen Gold-Image-Uploads ein anderer lokaler Benutzer auf Workstation oder Lab-Host `ps -ef` liest, erhaelt er Schreibrecht auf den Artefakt-Bucket und kann ein Gold-Image ersetzen, das spaetere Labs als ORACLE_HOME installieren
- aufwand: S
- fix: PAR ueber die bestehende 0600-Vars-Datei (`cpu_lab_ansible_secrets`) an Ansible geben und auf dem Host per `curl --config <0600-datei>` bzw. `-K -` von stdin statt als Argument uebergeben

### F-03 - Windows-AD-NSG oeffnet RDP, WinRM, LDAP, Kerberos, DNS fuer 0.0.0.0/0
- schwere: mittel
- rolle: security
- ort: terraform/modules/windows_ad/security.tf
- regel: network
- beleg: terraform/modules/windows_ad/security.tf:64 und :86 - `source = "0.0.0.0/0"` fuer alle Eintraege aus `nsg_tcp_rules`/`nsg_udp_rules` (3389, 5985, 5986, 389, 636, 88, 464, 53, 3268, 3269), am Artefakt bestaetigt; Kommentar :11 begruendet das mit "kein Public IP per Default"; die Security List begrenzt RDP dagegen auf `allowed_rdp_cidrs` (terraform/modules/network/main.tf:630-645)
- ausloeser: OCI wertet Security List und NSG als Vereinigung aus - die NSG hebelt `allowed_rdp_cidrs` aus; wenn `assign_windows_public_ip = true` gesetzt wird und das Windows-Subnet eine IGW-Route bekommt (heute nur NAT/DRG, network/main.tf:290-297; Subnet erlaubt Public IPs, :749), sind RDP und WinRM des Domain Controllers aus dem Internet erreichbar
- aufwand: S
- fix: NSG-Quellen auf `var.vcn_cidr` plus `home_cidrs` bzw. `allowed_rdp_cidrs` setzen statt 0.0.0.0/0

### F-04 - Windows-Administrator-Passwort dauerhaft in Instanz-Metadaten und in einer Datei auf dem DC
- schwere: mittel
- rolle: security
- ort: terraform/modules/windows_ad/templates/windows_ad-cloudinit.yaml.tftpl
- regel: secret
- beleg: terraform/modules/windows_ad/main.tf:30 - `admin_password_b64 = base64encode(var.admin_password_secret)`; :68 - Cloud-Init als `user_data`; windows_ad-cloudinit.yaml.tftpl:12 und :76-87 - Passwort (Base64, Klartext-aequivalent) wird in `00_init_environment.ps1` unter `C:\OraLab\Scripts` geschrieben und nicht entfernt
- ausloeser: wenn ein Lab-AD-Benutzer (aus users_ad.csv) sich am DC anmeldet oder ein lokaler Prozess den IMDS-Endpunkt liest, erhaelt er das Administrator- und damit Domain-Admin-Passwort fuer die ganze Lebensdauer der Instanz (`are_legacy_imds_endpoints_disabled = true`, main.tf:72, verhindert nur IMDSv1)
- aufwand: M
- fix: Datei mit restriktiver ACL schreiben und nach Gebrauch loeschen und das Passwort nach dem Bootstrap rotieren, damit der Metadaten-Wert wertlos wird

### F-05 - Skript setzt bekanntes Default-Passwort fuer den oracle-OS-User
- schwere: mittel
- rolle: security
- ort: tools/infra-tools/scripts/setup_common_os.sh
- regel: secret
- beleg: tools/infra-tools/scripts/setup_common_os.sh:199-205 - `chpasswd` mit Passwort = Benutzername (Orchestrator am Artefakt bestaetigt); unbedingter Aufruf in main, :251; kein Aufrufer im Repo (`git grep setup_common_os` trifft nur die Datei selbst und einen Kommentar)
- ausloeser: Vermutung: wenn das Skript manuell oder in einem Image-Build auf einem Lab-Host laeuft und zusaetzlich SSH-Passwort-Login aktiv ist (anderes Image, base_ssh-Rolle nicht angewendet), ist `oracle` mit einem im public Repo dokumentierten Passwort erreichbar - mit NOPASSWD-sudo (ansible/roles/db19_engineering/defaults/main.yml:91-92) ist das root
- aufwand: S
- fix: Funktion entfernen bzw. auf `passwd -l` (nur Key-Zugang) umstellen; ist das Skript tot, das ganze Skript loeschen

### F-06 - PAR-Lebensdauer ohne Obergrenze, Write-PAR bei Abbruch nicht widerrufen, SSH-Allow-List ohne Ablauf
- schwere: mittel
- rolle: security
- ort: Makefile
- regel: INV-2
- beleg: Makefile:475 - `PAR_DAYS ?= 7` ohne Plausibilitaetspruefung, geht ungeprueft in `--time-expires` (Makefile:481, 493); Makefile:545 - `GOLD_PAR_HOURS ?= 2` ebenso; Makefile:551-570 - Write-PAR wird erst nach dem Playbook widerrufen, ohne `trap`; Makefile:708-722 - `cpu-lab-allow-ip` setzt eine SSH-Freigabe ohne Ablauf
- ausloeser: wenn jemand `PAR_DAYS=365` setzt, entsteht ein Jahres-Bearer-Token auf das 19c-Image ohne Warnung; wenn `cpu-lab-goldimage-push` zwischen Makefile:553 und :563 abbricht (Ctrl-C), bleibt die bucket-weite Schreib-PAR bis zum Ablauf aktiv; eine per allow-ip geoeffnete SSH-Regel bleibt, bis jemand sie aendert
- aufwand: S
- fix: Obergrenze fuer PAR_DAYS/GOLD_PAR_HOURS mit Abbruch erzwingen, den Widerruf der Write-PAR in einen `trap ... EXIT INT TERM` legen und die Allow-List-Freigabe an Auto-Stop/Destroy koppeln

### F-07 - .gitignore deckt auto.tfvars, Plan-Dateien und .ssh/ nicht repo-weit ab
- schwere: mittel
- rolle: security
- ort: .gitignore
- regel: INV-7
- beleg: .gitignore:10-13 - nur `**/terraform.tfvars` und `**/.env`; kein `*.auto.tfvars`, kein `.ssh/`, kein `tfplan` (am Artefakt bestaetigt); env-eigene .gitignore nur in terraform/envs/core und terraform/envs/cpu-patch-test; `git check-ignore` meldet `terraform/envs/ad-cmu-test/.ssh/id` und `terraform/envs/mfa_oma_setup/.ssh/id` als nicht ignoriert
- ausloeser: wenn jemand das Windows-Admin-Passwort in eine `secrets.auto.tfvars` legt oder einen Plan in ad-cmu-test speichert (Plan enthaelt sensitive Werte im Klartext), landet das mit `git add .` im public Repo - der Pre-commit-Scan faengt Passwoerter ohne bekanntes Muster nicht
- aufwand: S
- fix: `**/*.auto.tfvars`, `**/*.tfvars` mit `!*.tfvars.example`, `**/.ssh/`, `**/tfplan*`, `**/.env.*` mit `!.env.example` in die Root-.gitignore aufnehmen

### F-08 - Netzwerk-Modul oeffnet SSH und WireGuard per Default fuer 0.0.0.0/0; ad-cmu-test erbt das
- schwere: mittel
- rolle: security
- ort: terraform/modules/network/variables.tf
- regel: network
- beleg: terraform/modules/network/variables.tf:115 - `allowed_ssh_cidrs` `default = ["0.0.0.0/0"]`; :127 - `allowed_wireguard_cidrs` ebenso (am Artefakt bestaetigt); verwendet in der Public-Subnet-Security-List, terraform/modules/network/main.tf:374-403; terraform/envs/ad-cmu-test/main.tf:54-77 uebergibt `allowed_ssh_cidrs` nicht
- ausloeser: wenn in ad-cmu-test oder einer neuen Env, die das Argument vergisst, eine Instanz mit Public IP im Public Subnet landet (z.B. Jumphost), ist Port 22 aus dem ganzen Internet offen
- aufwand: S
- fix: Modul-Defaults auf `[]` setzen (und terraform/modules/network/README.md:20-22 nachziehen), damit jede Freigabe explizit ist

### F-09 - Ansible-Rolle windows_ad rendert das Admin-Passwort ohne no_log und laesst die Datei liegen
- schwere: mittel
- rolle: security
- ort: ansible/roles/windows_ad/tasks/main.yml
- regel: secret
- beleg: ansible/roles/windows_ad/tasks/main.yml:45-48 - `win_template` von `00_init_environment.ps1.j2` ohne `no_log`; ansible/roles/windows_ad/templates/00_init_environment.ps1.j2:31 - Passwort als Klartext-Zuweisung; kein Aufraeum-Task am Ende der Rolle
- ausloeser: wenn die Rolle mit `--diff` oder erhoehter Verbositaet laeuft, steht das Passwort im Terminal bzw. Log; die Datei bleibt danach auf dem DC lesbar (wie F-04)
- aufwand: S
- fix: `no_log: true` am Template-Task und Loeschen der Datei in einem `always`-Block nach dem Muster aus ansible/roles/db19_engineering/tasks/credentials.yml:66-95

### F-10 - Windows-Bootstrap laedt und startet ungepinnten Code von einem Branch
- schwere: mittel
- rolle: security
- ort: terraform/modules/windows_ad/templates/windows_ad-cloudinit.yaml.tftpl
- regel: pinning
- beleg: terraform/modules/windows_ad/templates/windows_ad-cloudinit.yaml.tftpl:60 - `Invoke-WebRequest` auf `.../ad-lab/archive/refs/heads/main.zip` ohne Checksumme; die Skripte laufen danach als Administrator (ansible/roles/windows_ad/tasks/main.yml:51-118)
- ausloeser: wenn `main` von ad-lab kompromittiert oder versehentlich geaendert wird, fuehrt jeder neue DC den neuen Stand mit Domain-Admin-Rechten aus, ohne dass sich in oci-labs etwas aendert
- aufwand: S
- fix: auf Tag oder Commit-SHA pinnen und den SHA-256 des Archivs pruefen (Muster wie .github/workflows/gitleaks.yml:36)

### F-11 - make lint laeuft nicht in der CI
- schwere: mittel
- rolle: doku-tests
- ort: .github/workflows/ci.yml
- regel: ci-gate
- beleg: .github/workflows/ enthaelt nur gitleaks.yml, kein ci.yml; terraform fmt/validate, ansible-lint, yamllint, markdownlint, shellcheck, check-version laufen nur lokal (`make lint`, Makefile:172) - bestaetigt von review-doku, review-testing und scan-tests
- ausloeser: wenn ein Push oder PR kaputtes HCL, eine shellcheck-Warnung oder ein falsch formatiertes Terraform einfuehrt, bleibt der Check gruen - das lokale Gate greift nur, wer `make lint` von Hand laeuft
- aufwand: S
- fix: Workflow `.github/workflows/ci.yml` mit `make lint` (Tools per Version und SHA gepinnt, `permissions: contents: read`, wie gitleaks.yml) anlegen; Regressionsfaelle RT-04/RT-05 aus review-testing als Abnahme

### F-12 - Object-Storage-Namespace des Lab-Tenants im Baum
- schwere: mittel
- rolle: security
- ort: docs/review-lens.md
- regel: INV-6
- beleg: 13 Zeilen in 10 getrackten Dateien, unveraendert gegenueber dem Register - CHANGELOG.md:27; docs/runbook-cpu-patch-lab.md:14,118,161; tasks/plan-cpu-lab.md:75; tasks/state-2026-08-28.md:8; terraform/envs/core/README.md:55; terraform/envs/core/terraform.tfvars.example:14; terraform/envs/cpu-patch-test/.env.example:71,77; terraform/envs/cpu-patch-test/README.md:20; terraform/modules/core/main.tf:69; tools/upload_bootstrap.sh:27 - Wert jeweils `<namespace>`
- ausloeser: wenn ein Leser des public Repos den Namespace kennt, kennt er das Ziel jeder PAR-URL des Labs und den Tenancy-Kontext
- aufwand: S
- fix: Owner-Entscheid treffen - im Register `akzeptiert` mit Begruendung, Name und Datum, oder alle Stellen durch `<namespace>` ersetzen

### F-13 - terraform/global wird von make lint nie validiert
- schwere: mittel
- rolle: doku-tests
- ort: terraform/global
- regel: test-gap
- beleg: Makefile:184 - `for env in $(TF_DIR)/envs/*/` deckt nur `envs/` ab (am Artefakt bestaetigt); terraform/global/provider.tf und terraform/global/versions.tf existieren; `terraform init -backend=false && terraform validate` laeuft fuer terraform/global offline erfolgreich (vom Orchestrator verifiziert) - es fehlt nur der Aufruf im Gate
- ausloeser: wenn `terraform/global/` geaendert wird, meldet `make lint` Erfolg - fehlerhafte HCL oder inkompatible Provider-Constraints bleiben bis zum naechsten manuellen `terraform init` unentdeckt
- aufwand: S
- fix: im `lint-terraform`-Loop `$(TF_DIR)/global` neben `$(TF_DIR)/envs/*/` aufnehmen (Regressionsfall RT-01 aus review-testing)

### F-14 - Ansible-Playbook-Syntax-Check nur mit laufendem Lab ausfuehrbar
- schwere: mittel
- rolle: doku-tests
- ort: Makefile
- regel: test-gap
- beleg: Makefile:197-199 - `lint-ansible-syntax: guard-ansible guard-cpu-env` - `guard-cpu-env` verlangt die erst nach `make cpu-lab-apply` erzeugte Env-Datei (am Artefakt bestaetigt); Makefile:172 - `lint` enthaelt `lint-ansible-syntax` nicht
- ausloeser: wenn ein Playbook einen Syntaxfehler einfuehrt, den ansible-lint nicht meldet, faellt er erst beim Lauf gegen ein bezahltes Live-Lab auf
- aufwand: M
- fix: statischen Inventory-Stub (z.B. `ansible/tests/inventory-stub/`) anlegen und den Syntax-Check aller Playbooks dagegen in `make lint` aufnehmen (Regressionsfall RT-03)

### F-15 - CLAUDE.md enthaelt unfuellte TODO-Platzhalter
- schwere: mittel
- rolle: doku-tests
- ort: CLAUDE.md
- regel: todo
- beleg: CLAUDE.md:5 - `TODO: describe project purpose, tech stack, and main commands.`; CLAUDE.md:9 - `- Build/Test: TODO` (am Artefakt bestaetigt)
- ausloeser: wenn ein Agent oder neuer Contributor CLAUDE.md liest, bekommt er weder Projektzweck noch Build-Kommandos und startet ohne Kontext
- aufwand: S
- fix: Zeile 5 durch zwei Saetze zum Stack (Terraform + Ansible + Makefile fuer OCI-Lab-Envs) ersetzen, Zeile 9 durch `make help` / `make lint`

### F-16 - gitleaks-OCID-Regel deckt nur 16 Ressourcentypen ab
- schwere: niedrig
- rolle: security
- ort: .gitleaks.toml
- regel: INV-4
- beleg: .gitleaks.toml:38 - feste Typ-Liste `tenancy|user|compartment|instance|vcn|subnet|drg|...|policy`; nicht erfasst u.a. `bastion`, `bastionsession`, `natgateway`, `internetgateway`, `securitylist`, `networksecuritygroup`, `routetable`, `volume`, `bootvolume`, `image`, `publicip`, `domain`, `resourceschedule`; heute kein solcher Treffer in Baum und Historie
- ausloeser: wenn eine echte Bastion- oder NSG-OCID in Doku oder Runbook kopiert wird, melden CI und Pre-commit gruen, obwohl INV-4 verletzt ist
- aufwand: S
- fix: Typ-Liste durch `[a-z0-9]+` ersetzen und die Platzhalter-Allowlist beibehalten

### F-17 - CI-Scan eines Pull Requests nutzt die .gitleaks.toml aus dem PR
- schwere: niedrig
- rolle: security
- ort: .gitleaks.toml
- regel: ci-gate
- beleg: .github/workflows/gitleaks.yml:14 - Trigger `pull_request`; :48-49 - `--config .gitleaks.toml` aus dem ausgecheckten PR-Stand
- ausloeser: wenn ein PR im public Repo zugleich ein Secret und einen passenden `[[allowlists]]`-Eintrag einfuehrt, ist der Check gruen; nur Review der .gitleaks.toml faengt das
- aufwand: S
- fix: Allowlist-Aenderungen per CODEOWNERS bzw. Pflicht-Review schuetzen oder die Config in der CI aus dem Basis-Branch laden

### F-18 - Doku empfiehlt Secrets als `-e ...` im argv, entgegen der Makefile-Regel
- schwere: niedrig
- rolle: security
- ort: ansible/roles/db19_engineering/tasks/credentials.yml
- regel: doc-drift
- beleg: ansible/roles/db19_engineering/tasks/credentials.yml:48-50 - Assert-Meldung empfiehlt `-e mos_password="$(op read ...)"`; ebenso ansible/roles/db19_engineering/tasks/create_db.yml:26, terraform/envs/cpu-patch-test/outputs.tf:32 und :41, terraform/envs/cpu-patch-test/.env.example:63 - gegen Makefile:343-346
- ausloeser: wenn jemand der Assert-Meldung folgt statt `make cpu-lab-*` zu nutzen, stehen MOS- und SYS-Passwort fuer die ganze Laufzeit (AutoUpgrade: etwa eine Stunde) in `ps`
- aufwand: S
- fix: alle Beispiele auf `-e @<0600-datei>` bzw. den Make-Weg umstellen

### F-19 - OCI-CLI-Profilname und Compartment-Name als Defaults im Baum
- schwere: niedrig
- rolle: security
- ort: Makefile
- regel: INV-6
- beleg: Makefile:405, 423, 480 (u.a., 9 Zeilen) - `profile="$${profile:-<profilname>}"`; Profilname in 16 getrackten Dateien, darunter terraform/envs/cpu-patch-test/provider.tf und variables.tf; Compartment-Name in terraform/envs/cpu-patch-test/.env.example:16 und ansible/roles/db19_engineering/defaults/main.yml
- ausloeser: Vermutung: der Profilname entspricht dem Tenancy-Namen bzw. Namespace-Praefix und faellt dann unter INV-6; beide Klassen stehen in der Linse unter "Sensible Namen"
- aufwand: S
- fix: Profil-Default auf `DEFAULT` setzen und den echten Namen nur aus der gitignorierten .env lesen; zusammen mit F-12 entscheiden

### F-20 - CLAUDE.md nennt falsches Lint-Kommando
- schwere: niedrig
- rolle: doku-tests
- ort: CLAUDE.md
- regel: doc-drift
- beleg: CLAUDE.md:10 - `markdownlint docs/` (am Artefakt bestaetigt) vs Makefile:211-214 - `markdownlint "**/*.md"` mit .markdownlintignore
- ausloeser: wer das dokumentierte Kommando nutzt, prueft nur docs/ und uebersieht terraform/, ansible/, tasks/
- aufwand: S
- fix: CLAUDE.md:10 auf `make lint-markdown` korrigieren (zusammen mit F-15)

### F-21 - Makefile-Kopfzeile zeigt Version v0.1.0 statt 0.3.0
- schwere: niedrig
- rolle: doku-tests
- ort: Makefile
- regel: doc-drift
- beleg: Makefile:8 - `# Version....: v0.1.0` (am Artefakt bestaetigt); VERSION:1 - `0.3.0`; Makefile:39 liest VERSION korrekt, nur der Kopfkommentar ist veraltet
- ausloeser: wer den Makefile-Kopf liest, erhaelt eine falsche Versionsnummer; die ausgelieferte Version ist nicht betroffen
- aufwand: S
- fix: Makefile:8 auf den Wert aus VERSION setzen und beim Version-Bump mitziehen

### F-22 - terraform/envs/site2site-udm ist ein Env-Verzeichnis ohne IaC
- schwere: niedrig
- rolle: doku-tests
- ort: terraform/envs/site2site-udm
- regel: test-gap
- beleg: terraform/envs/site2site-udm/ - nur README.md, keine .tf-Datei; Makefile:185 meldet den Skip sichtbar ("SKIPPED: no provider.tf")
- ausloeser: wenn spaeter .tf-Dateien ohne provider.tf hinzukommen, werden sie weiterhin uebersprungen (sichtbar, aber ohne Fehler); das leere Env suggeriert vorhandene Infrastruktur
- aufwand: S
- fix: Verzeichnis entfernen, solange das Env nicht begonnen ist, oder minimal mit provider.tf anlegen (Regressionsfall RT-02)

### F-23 - Leere Platzhalter-Doku ansible/docs/ansible-workflow.md
- schwere: niedrig
- rolle: doku-tests
- ort: ansible/docs/ansible-workflow.md
- regel: orphan-doc
- beleg: ansible/docs/ansible-workflow.md - 0 Bytes (`wc -l`), getrackt
- ausloeser: wenn ein Leser oder Link die Datei oeffnet, findet er eine leere Seite statt Inhalt
- aufwand: S
- fix: Mindestinhalt (H1 plus Scope-Satz) einfuegen oder Datei per `git rm` entfernen

### F-24 - Leere Platzhalter-Doku ansible/docs/architecture-config.md
- schwere: niedrig
- rolle: doku-tests
- ort: ansible/docs/architecture-config.md
- regel: orphan-doc
- beleg: ansible/docs/architecture-config.md - 0 Bytes (`wc -l`), getrackt
- ausloeser: wenn ein Leser oder Link die Datei oeffnet, findet er eine leere Seite statt Inhalt
- aufwand: S
- fix: Mindestinhalt (H1 plus Scope-Satz) einfuegen oder Datei per `git rm` entfernen

### F-25 - Leere Platzhalter-Doku ansible/docs/profiles-overview.md
- schwere: niedrig
- rolle: doku-tests
- ort: ansible/docs/profiles-overview.md
- regel: orphan-doc
- beleg: ansible/docs/profiles-overview.md - 0 Bytes (`wc -l`), getrackt
- ausloeser: wenn ein Leser oder Link die Datei oeffnet, findet er eine leere Seite statt Inhalt
- aufwand: S
- fix: Mindestinhalt (H1 plus Scope-Satz) einfuegen oder Datei per `git rm` entfernen

### F-26 - Leere Platzhalter-Doku ansible/inventories/README.md
- schwere: niedrig
- rolle: doku-tests
- ort: ansible/inventories/README.md
- regel: orphan-doc
- beleg: ansible/inventories/README.md - 0 Bytes (`wc -l`), getrackt
- ausloeser: wenn ein Leser das Inventory-Verzeichnis auf GitHub oeffnet, zeigt das README nichts
- aufwand: S
- fix: Mindestinhalt (H1 plus Hinweis auf das generierte Inventory) einfuegen oder Datei per `git rm` entfernen

### F-27 - Leere Platzhalter-Doku docs/lab-odb19eng-single.md
- schwere: niedrig
- rolle: doku-tests
- ort: docs/lab-odb19eng-single.md
- regel: orphan-doc
- beleg: docs/lab-odb19eng-single.md - 0 Bytes (`wc -l`), getrackt
- ausloeser: wenn ein Leser oder Link die Datei oeffnet, findet er eine leere Seite statt Inhalt
- aufwand: S
- fix: Mindestinhalt (H1 plus Scope-Satz) einfuegen oder Datei per `git rm` entfernen

### F-28 - Leere Platzhalter-Doku docs/lab-odb19sec-dg.md
- schwere: niedrig
- rolle: doku-tests
- ort: docs/lab-odb19sec-dg.md
- regel: orphan-doc
- beleg: docs/lab-odb19sec-dg.md - 0 Bytes (`wc -l`), getrackt
- ausloeser: wenn ein Leser oder Link die Datei oeffnet, findet er eine leere Seite statt Inhalt
- aufwand: S
- fix: Mindestinhalt (H1 plus Scope-Satz) einfuegen oder Datei per `git rm` entfernen

### F-29 - Em-Dashes in docs/runbook-mfa-oma.md
- schwere: niedrig
- rolle: doku-tests
- ort: docs/runbook-mfa-oma.md
- regel: doc-drift
- beleg: docs/runbook-mfa-oma.md:22,43,68,70,72,82,89,92,190,194,447,503,538,671,786 - 15 Zeichen U+2014 (am Artefakt gezaehlt)
- ausloeser: Projektregel "hyphen-minus only" verletzt; markdownlint faengt das nicht, die Abweichung waechst still
- aufwand: S
- fix: U+2014 durch ` - ` ersetzen; Mermaid-Strings in :22 und :43 danach im Diagramm pruefen

### F-30 - Em-Dashes in docs/spec-iam-mfa-oma.md
- schwere: niedrig
- rolle: doku-tests
- ort: docs/spec-iam-mfa-oma.md
- regel: doc-drift
- beleg: docs/spec-iam-mfa-oma.md:255,257,258 - 3 Zeichen U+2014 (am Artefakt gezaehlt)
- ausloeser: Projektregel "hyphen-minus only" verletzt; markdownlint faengt das nicht
- aufwand: S
- fix: U+2014 durch ` - ` ersetzen

### F-31 - Em-Dash in terraform/modules/iam_mfa_oma/README.md
- schwere: niedrig
- rolle: doku-tests
- ort: terraform/modules/iam_mfa_oma/README.md
- regel: doc-drift
- beleg: terraform/modules/iam_mfa_oma/README.md:170 - 1 Zeichen U+2014 (am Artefakt gezaehlt)
- ausloeser: Projektregel "hyphen-minus only" verletzt; markdownlint faengt das nicht
- aufwand: S
- fix: U+2014 durch ` - ` ersetzen

### F-32 - CONTRIBUTING fehlt
- schwere: niedrig
- rolle: doku-tests
- ort: CONTRIBUTING.md
- regel: contributing
- beleg: kein CONTRIBUTING.md im Root (review-doku); Ein-Personen-Lab-Repo
- ausloeser: wenn jemand im public Repo einen PR oder Issue oeffnen will, findet er weder Erwartungen noch den Hinweis auf `make hooks` und `make lint`
- aufwand: S
- fix: kurzes CONTRIBUTING.md mit `make hooks`, `make lint`, Secret-Regel (`op read`) und Verweis auf SECURITY.md

### F-33 - OCI-PAR-URL mit Token in der Historie (History-Scan, Orchestrator)
- schwere: kritisch
- rolle: security
- ort: infra/stacks/lab-db19c-baseline/terraform.tfvars
- regel: history
- beleg: 93d3f77 infra/stacks/lab-db19c-baseline/terraform.tfvars:25 - oci-par-url, objectstorage.<region>.oraclecloud.com/p/.../ (redigiert)
- ausloeser: wer die public Historie liest, erhaelt den PAR-Token
- aufwand: S
- fix: bereits entschieden (Register akzeptiert) - keine Rotation, kein History-Rewrite

### F-34 - Echte OCIDs und Key-Fingerprint in der Historie, 93d3f77 (History-Scan, Orchestrator)
- schwere: hoch
- rolle: security
- ort: infra/stacks/lab-db19c-baseline/terraform.tfvars
- regel: INV-5
- beleg: 93d3f77 infra/stacks/lab-db19c-baseline/terraform.tfvars:16,17,22 - oci-ocid (tenancy, user, compartment); :18 - oci-api-key-fingerprint (redigiert)
- ausloeser: wer die public Historie liest, kennt die Tenancy-Struktur
- aufwand: S
- fix: bereits entschieden (Register akzeptiert)

### F-35 - Echte Compartment- und DRG-OCID in der Historie, f70530f (History-Scan, Orchestrator)
- schwere: hoch
- rolle: security
- ort: docs/runbook-ad-cmu-lab.md
- regel: INV-5
- beleg: f70530f docs/runbook-ad-cmu-lab.md:136,144 - oci-ocid (redigiert)
- ausloeser: wer die public Historie liest, kennt Compartment und DRG
- aufwand: S
- fix: bereits entschieden (Register akzeptiert)

## Notizen

### Prioritaet (impact x likelihood x blast radius, Security-Impact x1.5)

- 1. F-01 Auto-Stop-Default aus (INV-2, hoch) - einziger `hoch`; vergessene Instanz mit NOPASSWD-sudo ist das Kern-Szenario des Bedrohungsmodells
- 2. F-02 Write-PAR im argv - Schreibzugriff auf das Gold-Image wirkt auf alle spaeteren Labs (Supply Chain)
- 3. F-03, F-08 Netz-Defaults 0.0.0.0/0 (NSG und Modul) - je ein Konfigurationsschritt bis zur Internet-Exposition
- 4. F-04, F-09 Windows-Admin-Passwort (Metadaten, Datei, kein no_log) - gemeinsam fixen
- 5. F-05 Default-Passwort im Skript - billig zu entfernen
- 6. F-06, F-07 PAR-Obergrenze/trap und .gitignore-Luecken
- 7. F-10 Pinning des ad-lab-Bootstraps
- 8. F-11 CI-Gate fuer make lint (RA-oci-labs-013) - Hebel fuer alle Testluecken; danach F-13, F-14
- 9. F-12 und F-19 - Owner-Entscheid INV-6, ein Durchgang
- 10. F-15, F-20 CLAUDE.md in einem Commit; danach F-16, F-17, F-18
- 11. Rest niedrig: F-21, F-22, F-23..F-28, F-29..F-31, F-32
- Quick-Wins (S, eigenstaendig): F-05, F-08, F-13, F-15/F-20, F-16, F-07

### Konsolidierungs-Entscheide

- Schluessel-Wahl bei Mehr-Datei-Befunden: leere .md-Dateien (review-doku F-04) und Em-Dashes (review-doku F-05) sind je eine Finding pro Datei (F-23..F-28, F-29..F-31), weil jeder Fix in seiner Datei landet und einzeln geschlossen werden soll
- Em-Dashes: review-doku nannte "4 Dateien", belegt sind 3 Dateien mit 19 Zeichen (am Artefakt nachgezaehlt)
- F-01: Konsolidierung schlug `hoch` vor (Default ohne Public IP, Bastion-TTL 3 h); der Orchestrator setzt `kritisch` nach der Tabelle (Invariantenbruch) - konservativ, bis der Owner OFFENE FRAGE 1 entscheidet
- F-05 von `hoch` auf `mittel` gesenkt: kein Aufrufer im Repo (Orchestrator verifiziert), die Nutzung ist Vermutung - eine Vermutung ist hoechstens `mittel`
- F-22 von `mittel` auf `niedrig` gesenkt: das Verzeichnis enthaelt kein IaC, also gibt es nichts Ungeprueftes; der Skip ist seit RA-oci-labs-008 sichtbar
- F-13 behaelt `ort: terraform/global` (nicht Makefile), damit es nicht mit F-14 (Makefile, test-gap) kollidiert und nicht als Regression von RA-oci-labs-008 (Makefile, lint-gate) zaehlt
- F-17 traegt bewusst `ort: .gitleaks.toml` statt `.github/workflows/gitleaks.yml`, damit RA-oci-labs-006 (gleiche regel `ci-gate`) nicht als regressiert gilt
- Verworfen nach Orchestrator-Korrektur: INV-3-Befund aus scan-secrets (CLAUDE.md liegt im Root), MD041 und "197 Fences ohne Sprache" aus scan-markdown (leere Dateien bzw. schliessende Fences)
- Verworfen: scan-tests "site2site-udm stiller Skip" - veraltet, Makefile:185 meldet den Skip sichtbar; Rest in F-22
- tasks/review-2026-10-08-scan-secrets.md: Profil- und Compartment-Namen vom Orchestrator redigiert (`<profile>`, `<compartment>`)

### Register-Abgleich

- weiterhin offen: RA-oci-labs-005 (F-12), RA-oci-labs-012 (F-32), RA-oci-labs-013 (F-11)
- behoben bestaetigt, nicht gemeldet: RA-oci-labs-004, -006, -007, -008, -009, -010, -011
- akzeptiert, nicht gemeldet: RA-oci-labs-001, RA-oci-labs-002, RA-oci-labs-003

### OFFENE FRAGEN

- OFFENE FRAGE: Ist der Auto-Stop-Default `false` in cpu-patch-test ein bewusster Owner-Entscheid gegen INV-2? - angenommen: nein, daher F-01 `kritisch` (Release-Blocker); bei Ja im Register `akzeptiert` mit Name und Datum; bei strikter Tabelle waere F-01 `kritisch` und Release-Blocker
- OFFENE FRAGE: Faellt der Arbeitgebername in technischen Kommentaren (u.a. Makefile:464, terraform/modules/oracle_db_host/main.tf:12, 74, 79, 118, terraform/envs/cpu-patch-test/README.md:99) unter "Kurznamen von Arbeitgeber" der Linse? - angenommen: bewusst oeffentlich, daher kein Befund
- OFFENE FRAGE: Wird tools/infra-tools/scripts/setup_common_os.sh noch genutzt (manuell, Image-Build)? - kein Aufrufer im Repo; bei Nein ist Loeschen der Fix fuer F-05
- OFFENE FRAGE: Sind die 6 leeren .md-Dateien geplante Inhalte oder vergessene Stuempfe? - angenommen: Stuempfe (F-23..F-28)
- OFFENE FRAGE: Namespace und Profilname - stehen lassen (akzeptiert) oder ersetzen? - Entscheid fuer F-12 und F-19 gemeinsam

### BLOCKIERT

- BLOCKIERT: IaC-Scanner (tfsec, checkov) nicht installiert, Security-Lists/NSGs/IAM nur von Hand geprueft - `brew install tfsec checkov && tfsec terraform/ && checkov -d terraform/`
- BLOCKIERT: Hand-Grep auf sensible Namen nach privater Liste - `~/notes/docs/repo-audit-framework.md` enthaelt keine konkrete Liste fuer oci-labs; nur Fallback-Muster und Klassen geprueft - Liste ergaenzen, dann `git grep -n -i -f <liste>`
- BLOCKIERT: Dateirechte lokaler Secret-Artefakte (.ssh/, generiertes Inventory, .env, tfstate) - `stat` auf .env per Deny-Regel gesperrt, nur am Code belegt (main.tf:181-196, 405-409) - `stat -f '%Sp %N' terraform/envs/cpu-patch-test/.ssh/* ansible/inventories/generated/cpu-patch-test/hosts.yml terraform/envs/*/terraform.tfstate`
- BLOCKIERT: externes Repo oehrlis/ad-lab (Skripte, die F-10 als Administrator startet) ausserhalb des Scopes - eigener `/repo-audit`-Lauf im ad-lab-Repo
- BLOCKIERT: History-Scan bewusst nicht wiederholt, vom Orchestrator komplett gelaufen (64/64 Commits, nur RA-oci-labs-001..003) - `gitleaks git --config .gitleaks.toml --redact --log-opts=--all .`
- BLOCKIERT: `lint-ansible-syntax` benoetigt das generierte Inventory aus `make cpu-lab-apply`, ohne Live-Lab nicht ausfuehrbar - Abhilfe ist F-14 (Stub), sonst `make cpu-lab-apply && make lint-ansible-syntax`

### Was gut ist (nicht umbauen)

- Secrets an Ansible ueber 0600-Datei mit `umask 077`, `mktemp` und `trap` (Makefile:351-362); Werte via Environment statt argv an python3
- `no_log` konsequent in der db19-Rolle; Expect-Skript 0700 und im `always`-Block geloescht (credentials.yml:66-95); dbca-Response-Datei 0600 und entfernt (create_db.yml:109-152); Data-Pump-Parfile unter `umask 077`, sofort geloescht (smoke.yml:173-204)
- Netz-Defaults der Envs: `assign_public_ip = false`, `assign_windows_public_ip = false`, `allowed_ssh_cidrs = []`, `allowed_rdp_cidrs = []`; DB-Listener nur intra-VCN (oracle_db_host/security.tf:64-79)
- IMDSv2 erzwungen, PV-Verschluesselung in transit; Artefakt-Bucket `NoPublicAccess` (terraform/modules/core/main.tf:83); einzige IAM-Policy gruppen- und compartment-gebunden, keine Dynamic Groups
- Read-PAR auf ein Objekt, Write-PAR 2 h mit Widerruf, Token in der Ausgabe redigiert; Bastion-Session-TTL 3 h; ad-cmu-test mit taeglichem Auto-Stop
- Gates: gitleaks-Workflow mit `contents: read`, Checkout per SHA, `persist-credentials: false`, Binary per Version plus SHA-256; Allowlists auf Commit UND Pfad UND Regel; Pre-commit-Hook scheitert geschlossen; Lint-Targets ohne `|| true`, fehlendes Tool bricht mit `exit 1` ab; Skip von site2site-udm sichtbar
- Doku: README mit funktionierenden Links und korrekter Secrets-Sektion; CHANGELOG im Keep-a-Changelog-Format, VERSION konsistent; SECURITY.md und LICENSE vorhanden; Runbook-Platzhalter statt echter OCIDs; markdownlint mit Repo-Config ohne Verletzung
