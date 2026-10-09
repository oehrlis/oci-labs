# Review-Register - oci-labs

<!-- markdownlint-disable MD013 MD022 MD032 -->

> Gepflegt von /repo-audit. IDs werden nie neu vergeben. Keine Task-Syntax.
> Werte von Secrets und Identifikatoren stehen hier nie - nur Kurz-Hash, Datei, Muster.

- repo: oci-labs

## Befunde

### RA-oci-labs-001 - OCI-PAR-URL mit Token in der Historie

- status: akzeptiert
- schwere: kritisch
- rolle: security
- ort: infra/stacks/lab-db19c-baseline/terraform.tfvars
- regel: history
- gefunden: 2026-10-08
- beleg: 93d3f77 (2026-02-09) infra/stacks/lab-db19c-baseline/terraform.tfvars:25 -
  objectstorage.<region>.oraclecloud.com/p/.../ (redigiert); Datei in ad47625 13 Minuten spaeter geloescht
- begruendung: PAR zeitlich befristet, laut Stefan abgelaufen; Ablauf nicht technisch verifiziert (Test waere Nutzung
  des Tokens); keine Rotation, kein History-Rewrite - Stefan Oehrli 2026-10-08

Repo public seit 2026-02-09 (`gh repo view`), der Commit stammt vom selben Tag - der Wert
ist seit der Veroeffentlichung in Klonen und Forks. In `.gitleaks.toml` per Commit, Pfad
und Regel allowlisted, damit die CI nicht dauerhaft auf bekannter Historie rot ist.

### RA-oci-labs-002 - Echte Tenancy-, User-, Compartment-OCIDs und Key-Fingerprint in der Historie

- status: akzeptiert
- schwere: hoch
- rolle: security
- ort: infra/stacks/lab-db19c-baseline/terraform.tfvars
- regel: INV-5
- gefunden: 2026-10-08
- beleg: 93d3f77 infra/stacks/lab-db19c-baseline/terraform.tfvars:16,17,22 - ocid1.{tenancy,user,compartment}.oc1..... ;
  :18 - fingerprint = ...:...
- begruendung: Identifikatoren, kein Credential (der private API-Key lag nie im Repo, nur sein Pfad); folgt dem
  Owner-Entscheid ohne History-Rewrite zu 93d3f77 - Stefan Oehrli 2026-10-08

Eigener Befund neben RA-oci-labs-001, damit der Entscheid zur PAR die Identifikatoren
nicht still mit-akzeptiert (`regel` INV-5 statt `history`).

### RA-oci-labs-003 - Echte Compartment- und DRG-OCID in der Historie des AD/CMU-Runbooks

- status: akzeptiert
- schwere: hoch
- rolle: security
- ort: docs/runbook-ad-cmu-lab.md
- regel: INV-5
- gefunden: 2026-10-08
- beleg: f70530f (2026-06-28) docs/runbook-ad-cmu-lab.md:136,144 - ocid1.compartment.oc1..... /
  ocid1.drg.oc1.eu-zurich-1.... (redigiert)
- begruendung: Identifikatoren, kein Credential; im Baum durch Platzhalter ersetzt (RA-oci-labs-004), die Historie
  behaelt die alten Werte - kein History-Rewrite, wie bei 93d3f77 - Stefan Oehrli 2026-10-08

### RA-oci-labs-004 - Echte Compartment- und DRG-OCID im AD/CMU-Runbook

- status: behoben
- schwere: hoch
- rolle: security
- ort: docs/runbook-ad-cmu-lab.md
- regel: INV-4
- gefunden: 2026-10-08
- erledigt: 2026-10-08
- commit: 7769324
- beleg: docs/runbook-ad-cmu-lab.md:136 - compartment_ocid = "ocid1.compartment.oc1....."; :144 - drg_id =
  "ocid1.drg.oc1.eu-zurich-1...."

### RA-oci-labs-005 - Object-Storage-Namespace des Lab-Tenants im Baum

- status: behoben
- schwere: mittel
- rolle: security
- ort: docs/review-lens.md
- regel: INV-6
- gefunden: 2026-10-08
- beleg: 13 Zeilen in 10 getrackten Dateien, unveraendert gegenueber dem Register - CHANGELOG.md:27;
  docs/runbook-cpu-patch-lab.md:14,118,161; tasks/plan-cpu-lab.md:75; tasks/state-2026-08-28.md:8;
  terraform/envs/core/README.md:55; terraform/envs/core/terraform.tfvars.example:14;
  terraform/envs/cpu-patch-test/.env.example:71,77; terraform/envs/cpu-patch-test/README.md:20;
  terraform/modules/core/main.tf:69; tools/upload_bootstrap.sh:27 - Wert jeweils `<namespace>`
- gesehen: 2026-10-08
- erledigt: 2026-10-09
- commit: 1efe0de

Kein Credential, aber der Namespace benennt die Tenancy und steht in jeder PAR-URL des
Labs. Owner-Entscheid offen: bewusst stehen lassen (dann hier `akzeptiert` mit
Begruendung) oder durch `<namespace>` ersetzen. `ort` ist die Linse, weil dort der
Entscheid landet.

### RA-oci-labs-006 - Kein Secret-Scan in der CI

- status: behoben
- schwere: hoch
- rolle: security
- ort: .github/workflows/gitleaks.yml
- regel: ci-gate
- gefunden: 2026-10-08
- erledigt: 2026-10-08
- commit: 1930b7f
- beleg: .github/workflows fehlt; kein gitleaks, trufflehog oder anderer Secret-Scan; keine `.gitleaks.toml`

### RA-oci-labs-007 - Kein lokaler Pre-commit-Secret-Scan

- status: behoben
- schwere: mittel
- rolle: security
- ort: tools/git-hooks/pre-commit
- regel: ci-gate
- gefunden: 2026-10-08
- erledigt: 2026-10-08
- commit: 410d177
- beleg: .git/hooks fehlt, kein core.hooksPath, keine .pre-commit-config.yaml

### RA-oci-labs-008 - make lint ohne Secret-Scan, validate ueberspringt Envs still

- status: behoben
- schwere: mittel
- rolle: doku-tests
- ort: Makefile
- regel: lint-gate
- gefunden: 2026-10-08
- erledigt: 2026-10-08
- commit: 410d177
- beleg: Makefile:180 - `[[ -f "$$env/provider.tf" ]] || continue` (stiller Skip, trifft heute
  terraform/envs/site2site-udm); Makefile:167 - lint ohne gitleaks

Geprueft und legitim (keine Fehlermaskierung in Lint-Targets): die `|| true` in
Makefile:368, 429, 481, 526, 576, 626, 630, 637, 648, 675, 700 sind Lookups, deren
leeres Ergebnis danach explizit behandelt wird, oder Aufraeum-/Retry-Schritte;
Makefile:720-728 sind `clean`/`clean-terraform`. Kein Lint-Target enthaelt `|| true`.

### RA-oci-labs-009 - LICENSE fehlt

- status: behoben
- schwere: mittel
- rolle: doku-tests
- ort: LICENSE
- regel: license
- gefunden: 2026-10-08
- erledigt: 2026-10-08
- commit: 017228c
- beleg: keine LICENSE-Datei; Makefile-Kopf verweist auf Apache 2.0, ohne Lizenzdatei gilt fuer Leser "all rights
  reserved"

### RA-oci-labs-010 - SECURITY.md fehlt

- status: behoben
- schwere: mittel
- rolle: doku-tests
- ort: SECURITY.md
- regel: security-md
- gefunden: 2026-10-08
- erledigt: 2026-10-08
- commit: 017228c
- beleg: keine SECURITY.md - kein Meldeweg fuer ein gefundenes Secret

### RA-oci-labs-011 - Kein README im Repo-Root

- status: behoben
- schwere: mittel
- rolle: doku-tests
- ort: README.md
- regel: readme
- gefunden: 2026-10-08
- erledigt: 2026-10-08
- commit: 017228c
- beleg: README.md fehlt - die GitHub-Startseite des public Repos ist leer; Einstieg nur ueber docs/

### RA-oci-labs-012 - CONTRIBUTING fehlt

- status: offen
- schwere: niedrig
- rolle: doku-tests
- ort: CONTRIBUTING.md
- regel: contributing
- gefunden: 2026-10-08
- beleg: kein CONTRIBUTING.md im Root (review-doku); Ein-Personen-Lab-Repo
- gesehen: 2026-10-08

### RA-oci-labs-013 - make lint laeuft nicht in der CI

- status: offen
- schwere: mittel
- rolle: doku-tests
- ort: .github/workflows/ci.yml
- regel: ci-gate
- gefunden: 2026-10-08
- beleg: .github/workflows/ enthaelt nur gitleaks.yml, kein ci.yml; terraform fmt/validate, ansible-lint, yamllint,
  markdownlint, shellcheck, check-version laufen nur lokal (`make lint`, Makefile:172) - bestaetigt von review-doku,
  review-testing und scan-tests
- gesehen: 2026-10-08

### RA-oci-labs-014 - Lab-Instanz ohne Auto-Stop als Default (cpu-patch-test)

- status: behoben
- schwere: kritisch
- rolle: security
- ort: terraform/envs/cpu-patch-test/variables.tf
- regel: inv-2
- gefunden: 2026-10-08
- beleg: terraform/envs/cpu-patch-test/variables.tf:308-312 - `enable_auto_stop` `default = false` (am Artefakt
  bestaetigt); terraform/envs/cpu-patch-test/terraform.tfvars.example:66 - `enable_auto_stop = false`;
  terraform/envs/cpu-patch-test/main.tf:343 - Schedule nur bei true; Begruendung
  terraform/envs/cpu-patch-test/README.md:238-240 (STOP mitten im AutoUpgrade-Lauf)
- erledigt: 2026-10-09
- commit: 73760d3

### RA-oci-labs-015 - Bucket-Write-PAR und Read-PAR im argv (ps-sichtbar)

- status: offen
- schwere: mittel
- rolle: security
- ort: Makefile
- regel: secret
- gefunden: 2026-10-08
- beleg: Makefile:561 - `-e db19_gold_image_par="$$uri"` (Write-PAR `AnyObjectWrite`, Makefile:555) als
  ansible-playbook-Argument (am Artefakt bestaetigt); ansible/roles/db19_engineering/tasks/push_gold_image.yml:116-119 -
  derselbe PAR als `curl -X PUT`-Argument auf dem Lab-Host (no_log schuetzt nur die Ansible-Ausgabe); Makefile:496-497 -
  Read-PAR als curl-Argument auf der Workstation; Widerspruch zu Makefile:343-346 ("never on the command line")

### RA-oci-labs-016 - Windows-AD-NSG oeffnet RDP, WinRM, LDAP, Kerberos, DNS fuer 0.0.0.0/0

- status: offen
- schwere: mittel
- rolle: security
- ort: terraform/modules/windows_ad/security.tf
- regel: network
- gefunden: 2026-10-08
- beleg: terraform/modules/windows_ad/security.tf:64 und :86 - `source = "0.0.0.0/0"` fuer alle Eintraege aus
  `nsg_tcp_rules`/`nsg_udp_rules` (3389, 5985, 5986, 389, 636, 88, 464, 53, 3268, 3269), am Artefakt bestaetigt;
  Kommentar :11 begruendet das mit "kein Public IP per Default"; die Security List begrenzt RDP dagegen auf
  `allowed_rdp_cidrs` (terraform/modules/network/main.tf:630-645)

### RA-oci-labs-017 - Windows-Administrator-Passwort dauerhaft in Instanz-Metadaten und in einer Datei auf dem DC

- status: offen
- schwere: mittel
- rolle: security
- ort: terraform/modules/windows_ad/templates/windows_ad-cloudinit.yaml.tftpl
- regel: secret
- gefunden: 2026-10-08
- beleg: terraform/modules/windows_ad/main.tf:30 - `admin_password_b64 = base64encode(var.admin_password_secret)`; :68 -
  Cloud-Init als `user_data`; windows_ad-cloudinit.yaml.tftpl:12 und :76-87 - Passwort (Base64, Klartext-aequivalent)
  wird in `00_init_environment.ps1` unter `C:\OraLab\Scripts` geschrieben und nicht entfernt

### RA-oci-labs-018 - Skript setzt bekanntes Default-Passwort fuer den oracle-OS-User

- status: behoben
- schwere: mittel
- rolle: security
- ort: tools/infra-tools/scripts/setup_common_os.sh
- regel: secret
- gefunden: 2026-10-08
- beleg: tools/infra-tools/scripts/setup_common_os.sh:199-205 - `chpasswd` mit Passwort = Benutzername (Orchestrator am
  Artefakt bestaetigt); unbedingter Aufruf in main, :251; kein Aufrufer im Repo (`git grep setup_common_os` trifft nur
  die Datei selbst und einen Kommentar)
- erledigt: 2026-10-09
- commit: 09731fa

### RA-oci-labs-019

- titel: PAR-Lebensdauer ohne Obergrenze, Write-PAR bei Abbruch nicht widerrufen, SSH-Allow-List ohne Ablauf
- status: offen
- schwere: mittel
- rolle: security
- ort: Makefile
- regel: inv-2
- gefunden: 2026-10-08
- beleg: Makefile:475 - `PAR_DAYS ?= 7` ohne Plausibilitaetspruefung, geht ungeprueft in `--time-expires` (Makefile:481,
  493); Makefile:545 - `GOLD_PAR_HOURS ?= 2` ebenso; Makefile:551-570 - Write-PAR wird erst nach dem Playbook
  widerrufen, ohne `trap`; Makefile:708-722 - `cpu-lab-allow-ip` setzt eine SSH-Freigabe ohne Ablauf

### RA-oci-labs-020 - .gitignore deckt auto.tfvars, Plan-Dateien und .ssh/ nicht repo-weit ab

- status: offen
- schwere: mittel
- rolle: security
- ort: .gitignore
- regel: inv-7
- gefunden: 2026-10-08
- beleg: .gitignore:10-13 - nur `**/terraform.tfvars` und `**/.env`; kein `*.auto.tfvars`, kein `.ssh/`, kein `tfplan`
  (am Artefakt bestaetigt); env-eigene .gitignore nur in terraform/envs/core und terraform/envs/cpu-patch-test; `git
  check-ignore` meldet `terraform/envs/ad-cmu-test/.ssh/id` und `terraform/envs/mfa_oma_setup/.ssh/id` als nicht
  ignoriert

### RA-oci-labs-021 - Netzwerk-Modul oeffnet SSH und WireGuard per Default fuer 0.0.0.0/0; ad-cmu-test erbt das

- status: offen
- schwere: mittel
- rolle: security
- ort: terraform/modules/network/variables.tf
- regel: network
- gefunden: 2026-10-08
- beleg: terraform/modules/network/variables.tf:115 - `allowed_ssh_cidrs` `default = ["0.0.0.0/0"]`; :127 -
  `allowed_wireguard_cidrs` ebenso (am Artefakt bestaetigt); verwendet in der Public-Subnet-Security-List,
  terraform/modules/network/main.tf:374-403; terraform/envs/ad-cmu-test/main.tf:54-77 uebergibt `allowed_ssh_cidrs`
  nicht

### RA-oci-labs-022 - Ansible-Rolle windows_ad rendert das Admin-Passwort ohne no_log und laesst die Datei liegen

- status: offen
- schwere: mittel
- rolle: security
- ort: ansible/roles/windows_ad/tasks/main.yml
- regel: secret
- gefunden: 2026-10-08
- beleg: ansible/roles/windows_ad/tasks/main.yml:45-48 - `win_template` von `00_init_environment.ps1.j2` ohne `no_log`;
  ansible/roles/windows_ad/templates/00_init_environment.ps1.j2:31 - Passwort als Klartext-Zuweisung; kein Aufraeum-Task
  am Ende der Rolle

### RA-oci-labs-023 - Windows-Bootstrap laedt und startet ungepinnten Code von einem Branch

- status: offen
- schwere: mittel
- rolle: security
- ort: terraform/modules/windows_ad/templates/windows_ad-cloudinit.yaml.tftpl
- regel: pinning
- gefunden: 2026-10-08
- beleg: terraform/modules/windows_ad/templates/windows_ad-cloudinit.yaml.tftpl:60 - `Invoke-WebRequest` auf
  `.../ad-lab/archive/refs/heads/main.zip` ohne Checksumme; die Skripte laufen danach als Administrator
  (ansible/roles/windows_ad/tasks/main.yml:51-118)

### RA-oci-labs-024 - terraform/global wird von make lint nie validiert

- status: offen
- schwere: mittel
- rolle: doku-tests
- ort: terraform/global
- regel: test-gap
- gefunden: 2026-10-08
- beleg: Makefile:184 - `for env in $(TF_DIR)/envs/*/` deckt nur `envs/` ab (am Artefakt bestaetigt);
  terraform/global/provider.tf und terraform/global/versions.tf existieren; `terraform init -backend=false && terraform
  validate` laeuft fuer terraform/global offline erfolgreich (vom Orchestrator verifiziert) - es fehlt nur der Aufruf im
  Gate

### RA-oci-labs-025 - Ansible-Playbook-Syntax-Check nur mit laufendem Lab ausfuehrbar

- status: offen
- schwere: mittel
- rolle: doku-tests
- ort: Makefile
- regel: test-gap
- gefunden: 2026-10-08
- beleg: Makefile:197-199 - `lint-ansible-syntax: guard-ansible guard-cpu-env` - `guard-cpu-env` verlangt die erst nach
  `make cpu-lab-apply` erzeugte Env-Datei (am Artefakt bestaetigt); Makefile:172 - `lint` enthaelt `lint-ansible-syntax`
  nicht

### RA-oci-labs-026 - CLAUDE.md enthaelt unfuellte TODO-Platzhalter

- status: offen
- schwere: mittel
- rolle: doku-tests
- ort: CLAUDE.md
- regel: todo
- gefunden: 2026-10-08
- beleg: CLAUDE.md:5 - `TODO: describe project purpose, tech stack, and main commands.`; CLAUDE.md:9 - `- Build/Test:
  TODO` (am Artefakt bestaetigt)

### RA-oci-labs-027 - gitleaks-OCID-Regel deckt nur 16 Ressourcentypen ab

- status: offen
- schwere: niedrig
- rolle: security
- ort: .gitleaks.toml
- regel: inv-4
- gefunden: 2026-10-08
- beleg: .gitleaks.toml:38 - feste Typ-Liste `tenancy|user|compartment|instance|vcn|subnet|drg|...|policy`; nicht
  erfasst u.a. `bastion`, `bastionsession`, `natgateway`, `internetgateway`, `securitylist`, `networksecuritygroup`,
  `routetable`, `volume`, `bootvolume`, `image`, `publicip`, `domain`, `resourceschedule`; heute kein solcher Treffer in
  Baum und Historie

### RA-oci-labs-028 - CI-Scan eines Pull Requests nutzt die .gitleaks.toml aus dem PR

- status: offen
- schwere: niedrig
- rolle: security
- ort: .gitleaks.toml
- regel: ci-gate
- gefunden: 2026-10-08
- beleg: .github/workflows/gitleaks.yml:14 - Trigger `pull_request`; :48-49 - `--config .gitleaks.toml` aus dem
  ausgecheckten PR-Stand

### RA-oci-labs-029 - Doku empfiehlt Secrets als `-e ...` im argv, entgegen der Makefile-Regel

- status: offen
- schwere: niedrig
- rolle: security
- ort: ansible/roles/db19_engineering/tasks/credentials.yml
- regel: doc-drift
- gefunden: 2026-10-08
- beleg: ansible/roles/db19_engineering/tasks/credentials.yml:48-50 - Assert-Meldung empfiehlt `-e mos_password="$(op
  read ...)"`; ebenso ansible/roles/db19_engineering/tasks/create_db.yml:26, terraform/envs/cpu-patch-test/outputs.tf:32
  und :41, terraform/envs/cpu-patch-test/.env.example:63 - gegen Makefile:343-346

### RA-oci-labs-030 - OCI-CLI-Profilname und Compartment-Name als Defaults im Baum

- status: offen
- schwere: niedrig
- rolle: security
- ort: Makefile
- regel: inv-6
- gefunden: 2026-10-08
- beleg: Makefile:405, 423, 480 (u.a., 9 Zeilen) - `profile="$${profile:-<profilname>}"`; Profilname in 16 getrackten
  Dateien, darunter terraform/envs/cpu-patch-test/provider.tf und variables.tf; Compartment-Name in
  terraform/envs/cpu-patch-test/.env.example:16 und ansible/roles/db19_engineering/defaults/main.yml
- teilweise: Doku und Beispiele in 1efe0de auf Platzhalter umgestellt; die Code-Defaults
  (Makefile 9 Zeilen, terraform/envs/*/variables.tf 2x) tragen den Profilnamen weiter
- entscheid-offen: Default auf das OCI-Standardprofil umstellen (lokale Laeufe brauchen dann
  ein gesetztes Profil) oder als akzeptiert fuehren - Stefan, nach 2026-10-09 zurueckgesetzt

### RA-oci-labs-031 - CLAUDE.md nennt falsches Lint-Kommando

- status: offen
- schwere: niedrig
- rolle: doku-tests
- ort: CLAUDE.md
- regel: doc-drift
- gefunden: 2026-10-08
- beleg: CLAUDE.md:10 - `markdownlint docs/` (am Artefakt bestaetigt) vs Makefile:211-214 - `markdownlint "**/*.md"` mit
  .markdownlintignore

### RA-oci-labs-032 - Makefile-Kopfzeile zeigt Version v0.1.0 statt 0.3.0

- status: offen
- schwere: niedrig
- rolle: doku-tests
- ort: Makefile
- regel: doc-drift
- gefunden: 2026-10-08
- beleg: Makefile:8 - `# Version....: v0.1.0` (am Artefakt bestaetigt); VERSION:1 - `0.3.0`; Makefile:39 liest VERSION
  korrekt, nur der Kopfkommentar ist veraltet

### RA-oci-labs-033 - terraform/envs/site2site-udm ist ein Env-Verzeichnis ohne IaC

- status: offen
- schwere: niedrig
- rolle: doku-tests
- ort: terraform/envs/site2site-udm
- regel: test-gap
- gefunden: 2026-10-08
- beleg: terraform/envs/site2site-udm/ - nur README.md, keine .tf-Datei; Makefile:185 meldet den Skip sichtbar
  ("SKIPPED: no provider.tf")

### RA-oci-labs-034 - Leere Platzhalter-Doku ansible/docs/ansible-workflow.md

- status: behoben
- schwere: niedrig
- rolle: doku-tests
- ort: ansible/docs/ansible-workflow.md
- regel: orphan-doc
- gefunden: 2026-10-08
- beleg: ansible/docs/ansible-workflow.md - 0 Bytes (`wc -l`), getrackt
- erledigt: 2026-10-09
- commit: 49d0416

### RA-oci-labs-035 - Leere Platzhalter-Doku ansible/docs/architecture-config.md

- status: behoben
- schwere: niedrig
- rolle: doku-tests
- ort: ansible/docs/architecture-config.md
- regel: orphan-doc
- gefunden: 2026-10-08
- beleg: ansible/docs/architecture-config.md - 0 Bytes (`wc -l`), getrackt
- erledigt: 2026-10-09
- commit: 49d0416

### RA-oci-labs-036 - Leere Platzhalter-Doku ansible/docs/profiles-overview.md

- status: behoben
- schwere: niedrig
- rolle: doku-tests
- ort: ansible/docs/profiles-overview.md
- regel: orphan-doc
- gefunden: 2026-10-08
- beleg: ansible/docs/profiles-overview.md - 0 Bytes (`wc -l`), getrackt
- erledigt: 2026-10-09
- commit: 49d0416

### RA-oci-labs-037 - Leere Platzhalter-Doku ansible/inventories/README.md

- status: behoben
- schwere: niedrig
- rolle: doku-tests
- ort: ansible/inventories/README.md
- regel: orphan-doc
- gefunden: 2026-10-08
- beleg: ansible/inventories/README.md - 0 Bytes (`wc -l`), getrackt
- erledigt: 2026-10-09
- commit: 49d0416

### RA-oci-labs-038 - Leere Platzhalter-Doku docs/lab-odb19eng-single.md

- status: behoben
- schwere: niedrig
- rolle: doku-tests
- ort: docs/lab-odb19eng-single.md
- regel: orphan-doc
- gefunden: 2026-10-08
- beleg: docs/lab-odb19eng-single.md - 0 Bytes (`wc -l`), getrackt
- erledigt: 2026-10-09
- commit: 49d0416

### RA-oci-labs-039 - Leere Platzhalter-Doku docs/lab-odb19sec-dg.md

- status: behoben
- schwere: niedrig
- rolle: doku-tests
- ort: docs/lab-odb19sec-dg.md
- regel: orphan-doc
- gefunden: 2026-10-08
- beleg: docs/lab-odb19sec-dg.md - 0 Bytes (`wc -l`), getrackt
- erledigt: 2026-10-09
- commit: 49d0416

### RA-oci-labs-040 - Em-Dashes in docs/runbook-mfa-oma.md

- status: offen
- schwere: niedrig
- rolle: doku-tests
- ort: docs/runbook-mfa-oma.md
- regel: doc-drift
- gefunden: 2026-10-08
- beleg: docs/runbook-mfa-oma.md:22,43,68,70,72,82,89,92,190,194,447,503,538,671,786 - 15 Zeichen U+2014 (am Artefakt
  gezaehlt)

### RA-oci-labs-041 - Em-Dashes in docs/spec-iam-mfa-oma.md

- status: offen
- schwere: niedrig
- rolle: doku-tests
- ort: docs/spec-iam-mfa-oma.md
- regel: doc-drift
- gefunden: 2026-10-08
- beleg: docs/spec-iam-mfa-oma.md:255,257,258 - 3 Zeichen U+2014 (am Artefakt gezaehlt)

### RA-oci-labs-042 - Em-Dash in terraform/modules/iam_mfa_oma/README.md

- status: offen
- schwere: niedrig
- rolle: doku-tests
- ort: terraform/modules/iam_mfa_oma/README.md
- regel: doc-drift
- gefunden: 2026-10-08
- beleg: terraform/modules/iam_mfa_oma/README.md:170 - 1 Zeichen U+2014 (am Artefakt gezaehlt)
