# Test Coverage Review - oci-labs (2026-10-08)

<!-- markdownlint-disable MD013 MD060 -->

- rolle: doku-tests
- commit: fb5bedb
- modus: quick

## Vorbedingung

Kein dediziertes Test-Framework im Repo (keine `.tftest.hcl`, keine `.bats`, keine
`test_*.py`). Validation laeuft ausschliesslich ueber statische Analyse (Makefile
lint-Targets) und manuelle Deployment-Tests. Dieser Lauf prueft die Qualitaet und
Luecken dieser Validierungsschicht.

Bekannte offene Register-Befunde dieser Rolle: RA-oci-labs-008 (behoben),
RA-oci-labs-012 (niedrig), RA-oci-labs-013 (offen - CI-Gate fehlt).

Akzeptierte Befunde (nicht gemeldet): RA-oci-labs-001, RA-oci-labs-002, RA-oci-labs-003.

---

## Befunde

### F-01 - terraform/global wird nie validiert

- schwere: mittel
- rolle: doku-tests
- ort: terraform/global
- regel: test-gap
- beleg: Makefile:184 - `for env in $(TF_DIR)/envs/*/` - Glob deckt nur `envs/`, nicht `global/`; terraform/global/provider.tf und terraform/global/versions.tf existieren, werden aber weder von `lint-terraform` noch vom `terraform validate`-Loop erfasst
- ausloeser: wenn `terraform/global/` geaendert wird, erhaelt kein Lint-Lauf einen Fehler - fehlerhafte HCL-Syntax oder inkompatible Provider-Constraints bleiben bis zum naechsten manuellen `terraform init` unentdeckt
- aufwand: S
- fix: in `lint-terraform` den `global/`-Ordner explizit hinzufuegen (`terraform validate` in `terraform/global/`) oder den Glob auf `$(TF_DIR)/envs/* $(TF_DIR)/global` erweitern

### F-02 - terraform/envs/site2site-udm enthaelt keine .tf-Dateien

- schwere: mittel
- rolle: doku-tests
- ort: terraform/envs/site2site-udm
- regel: test-gap
- beleg: terraform/envs/site2site-udm/ - nur README.md vorhanden, keine .tf-Datei; Makefile:185 meldet den Skip jetzt explizit ("SKIPPED: no provider.tf"), aber das Verzeichnis bleibt ein totes Environment ohne jede IaC-Abdeckung
- ausloeser: wenn ein Entwickler IaC fuer site2site-udm hinzufuegt ohne provider.tf anzulegen, wird das Env weiterhin still uebersprungen; bestehende .tf-Dateien ohne provider.tf wuerden nie validiert
- aufwand: S
- fix: entweder provider.tf anlegen (selbst minimal, damit Validation moeglich ist) oder das Verzeichnis entfernen, wenn das Env noch nicht begonnen wurde - leere Env-Verzeichnisse suggerieren fertige Infrastruktur

### F-03 - Ansible playbook syntax-check ist nur mit laufendem Lab ausfuehrbar

- schwere: mittel
- rolle: doku-tests
- ort: Makefile
- regel: test-gap
- beleg: Makefile:197-199 - `lint-ansible-syntax: guard-ansible guard-cpu-env` - `guard-cpu-env` prueft auf CPU_ENV_FILE, das erst nach `make cpu-lab-apply` generiert wird; `make lint` enthaelt `lint-ansible-syntax` nicht (Makefile:172), aber das Ziel ist dokumentiert und wird in README-Flows erwartet
- ausloeser: wenn ein Ansible-Playbook einen Syntaxfehler einfuehrt, schlaegt `lint-ansible` (ansible-lint) nicht an - nur `lint-ansible-syntax` wuerde ihn erkennen, und dieses Ziel ist ohne laufendes Lab nicht aufrufbar
- aufwand: M
- fix: einen statischen Inventory-Stub unter `ansible/tests/inventory-stub/` anlegen, der `lint-ansible-syntax` ohne Live-Lab ausfuehrbar macht; diesen Stub-Syntax-Check in `make lint` integrieren

---

## Lint-Gate-Verifikation (RA-oci-labs-008 Nachpruefung)

RA-oci-labs-008 wurde als behoben markiert. Verifikation der Makefile lint-Targets:

- Makefile:172 - `lint:` aggregiert alle Sub-Targets; kein `|| true`
- Makefile:180-189 - `lint-terraform`: kein `|| true`; fehlende Tools beenden mit `exit 1`
- Makefile:191-195 - `lint-ansible`: fehlendes Tool -> `exit 1`; kein `|| true`
- Makefile:201-205 - `lint-yaml`: fehlendes Tool -> `exit 1`; kein `|| true`
- Makefile:211-214 - `lint-markdown`: fehlendes Tool -> `exit 1`; kein `|| true`
- Makefile:216-222 - `lint-shell`: fehlendes Tool -> `exit 1`; kein `|| true`
- Makefile:228-232 - `lint-secrets`: fehlendes Tool -> `exit 1`; kein `|| true`
- Makefile:234-238 - `check-version`: `|| (echo ...; exit 1)`; kein `|| true`

Alle `|| true` im Makefile liegen in operativen Targets (Bastion-Cleanup, PAR-Lookup,
clean/*), nicht in Lint-Targets. RA-oci-labs-008 bestaetigt behoben.

---

## RA-oci-labs-013 (weiterhin offen)

`.github/workflows/ci.yml` fehlt weiterhin. Nur `gitleaks.yml` laeuft in CI.
`terraform validate`, `ansible-lint`, `shellcheck`, `yamllint`, `markdownlint` laufen
nur lokal. Befund besteht ungaendert - der Status `offen` bleibt korrekt.

---

## Was gut ist

- Alle Lint-Targets schlagen bei fehlendem Tool mit explizitem Fehler und `exit 1` ab -
  kein stilles Ueberspringen.
- Skip fuer `site2site-udm` gibt jetzt eine sichtbare Meldung aus (Makefile:185) -
  statt dem alten `continue` ohne Ausgabe.
- `gitleaks` laeuft sowohl in CI (`.github/workflows/gitleaks.yml`) als auch als
  Pre-commit-Hook - Secret-Scan ist doppelt abgesichert.
- Alle zehn Ansible-Rollen und sieben Playbooks werden von `ansible-lint` erfasst.
- Alle Shell-Skripte in `tools/` und `bootstrap/` werden von `shellcheck` geprueft.
- `check-version` verhindert ein Release mit ungueltigem SemVer-Format.

---

## Required Regression Tests

<!-- markdownlint-disable MD013 -->

| ID | Ziel-Funktion/Pfad | Szenario | Erwartete Assertion |
|----|--------------------|----------|---------------------|
| RT-01 | Makefile lint-terraform / terraform/global | `terraform/global/versions.tf` wird mit ungueltigem HCL gespeichert und `make lint-terraform` laeuft | Exit non-zero; Fehlerausgabe nennt `terraform/global` |
| RT-02 | Makefile lint-terraform / terraform/envs/site2side-udm | Provider.tf wird in site2site-udm angelegt, enthaelt Syntaxfehler | `make lint-terraform` schlaegt fehl; kein stiller Skip |
| RT-03 | Makefile lint-ansible-syntax (Stub) | Ansible-Playbook mit Syntaxfehler wird eingecheckt; kein Live-Lab vorhanden | `make lint-ansible-syntax` schlaegt ohne OCI-Zugang fehl und nennt den fehlerhaften Playbook |
| RT-04 | CI (.github/workflows/ci.yml) | PR mit kaputtem `terraform fmt` wird geoeffnet | CI-Check schlaegt fehl; Merge wird blockiert |
| RT-05 | CI (.github/workflows/ci.yml) | PR mit shellcheck-Warnung wird geoeffnet | CI schlaegt fehl; Merge wird blockiert |

<!-- markdownlint-restore -->

---

## BLOCKIERT

BLOCKIERT: `terraform validate` fuer `terraform/global` - laeuft lokal nicht ohne
initialisierte Provider (`terraform init` erfordert OCI-Credentials) - naechster
Schritt: `cd terraform/global && terraform init -backend=false -input=false &&
terraform validate` mit OCI-CLI-Profil.

BLOCKIERT: `lint-ansible-syntax` - benoetigt generierten Inventory aus `make
cpu-lab-apply`; ohne laufendes Lab nicht ausfuehrbar - naechster Schritt:
`make cpu-lab-apply` gefolgt von `make lint-ansible-syntax`.
