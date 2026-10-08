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
- beleg: 93d3f77 (2026-02-09) infra/stacks/lab-db19c-baseline/terraform.tfvars:25 - objectstorage.<region>.oraclecloud.com/p/.../ (redigiert); Datei in ad47625 13 Minuten spaeter geloescht
- begruendung: PAR zeitlich befristet, laut Stefan abgelaufen; Ablauf nicht technisch verifiziert (Test waere Nutzung des Tokens); keine Rotation, kein History-Rewrite - Stefan Oehrli 2026-10-08

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
- beleg: 93d3f77 infra/stacks/lab-db19c-baseline/terraform.tfvars:16,17,22 - ocid1.{tenancy,user,compartment}.oc1..... ; :18 - fingerprint = ...:...
- begruendung: Identifikatoren, kein Credential (der private API-Key lag nie im Repo, nur sein Pfad); folgt dem Owner-Entscheid ohne History-Rewrite zu 93d3f77 - Stefan Oehrli 2026-10-08

Eigener Befund neben RA-oci-labs-001, damit der Entscheid zur PAR die Identifikatoren
nicht still mit-akzeptiert (`regel` INV-5 statt `history`).

### RA-oci-labs-003 - Echte Compartment- und DRG-OCID in der Historie des AD/CMU-Runbooks
- status: akzeptiert
- schwere: hoch
- rolle: security
- ort: docs/runbook-ad-cmu-lab.md
- regel: INV-5
- gefunden: 2026-10-08
- beleg: f70530f (2026-06-28) docs/runbook-ad-cmu-lab.md:136,144 - ocid1.compartment.oc1..... / ocid1.drg.oc1.eu-zurich-1.... (redigiert)
- begruendung: Identifikatoren, kein Credential; im Baum durch Platzhalter ersetzt (RA-oci-labs-004), die Historie behaelt die alten Werte - kein History-Rewrite, wie bei 93d3f77 - Stefan Oehrli 2026-10-08

### RA-oci-labs-004 - Echte Compartment- und DRG-OCID im AD/CMU-Runbook
- status: offen
- schwere: hoch
- rolle: security
- ort: docs/runbook-ad-cmu-lab.md
- regel: INV-4
- gefunden: 2026-10-08
- beleg: docs/runbook-ad-cmu-lab.md:136 - compartment_ocid = "ocid1.compartment.oc1....."; :144 - drg_id = "ocid1.drg.oc1.eu-zurich-1...."

### RA-oci-labs-005 - Object-Storage-Namespace des Lab-Tenants im Baum
- status: offen
- schwere: mittel
- rolle: security
- ort: docs/review-lens.md
- regel: INV-6
- gefunden: 2026-10-08
- beleg: 13 Zeilen in 10 getrackten Dateien (CHANGELOG.md, docs/runbook-cpu-patch-lab.md, terraform/envs/core/*, terraform/envs/cpu-patch-test/*, terraform/modules/core/main.tf, tools/upload_bootstrap.sh, tasks/*) - Name nicht wiederholt

Kein Credential, aber der Namespace benennt die Tenancy und steht in jeder PAR-URL des
Labs. Owner-Entscheid offen: bewusst stehen lassen (dann hier `akzeptiert` mit
Begruendung) oder durch `<namespace>` ersetzen. `ort` ist die Linse, weil dort der
Entscheid landet.

### RA-oci-labs-006 - Kein Secret-Scan in der CI
- status: offen
- schwere: hoch
- rolle: security
- ort: .github/workflows/gitleaks.yml
- regel: ci-gate
- gefunden: 2026-10-08
- beleg: .github/workflows fehlt; kein gitleaks, trufflehog oder anderer Secret-Scan; keine `.gitleaks.toml`

### RA-oci-labs-007 - Kein lokaler Pre-commit-Secret-Scan
- status: offen
- schwere: mittel
- rolle: security
- ort: tools/git-hooks/pre-commit
- regel: ci-gate
- gefunden: 2026-10-08
- beleg: .git/hooks fehlt, kein core.hooksPath, keine .pre-commit-config.yaml

### RA-oci-labs-008 - make lint ohne Secret-Scan, validate ueberspringt Envs still
- status: offen
- schwere: mittel
- rolle: doku-tests
- ort: Makefile
- regel: lint-gate
- gefunden: 2026-10-08
- beleg: Makefile:180 - `[[ -f "$$env/provider.tf" ]] || continue` (stiller Skip, trifft heute terraform/envs/site2site-udm); Makefile:167 - lint ohne gitleaks

Geprueft und legitim (keine Fehlermaskierung in Lint-Targets): die `|| true` in
Makefile:368, 429, 481, 526, 576, 626, 630, 637, 648, 675, 700 sind Lookups, deren
leeres Ergebnis danach explizit behandelt wird, oder Aufraeum-/Retry-Schritte;
Makefile:720-728 sind `clean`/`clean-terraform`. Kein Lint-Target enthaelt `|| true`.

### RA-oci-labs-009 - LICENSE fehlt
- status: offen
- schwere: mittel
- rolle: doku-tests
- ort: LICENSE
- regel: license
- gefunden: 2026-10-08
- beleg: keine LICENSE-Datei; Makefile-Kopf verweist auf Apache 2.0, ohne Lizenzdatei gilt fuer Leser "all rights reserved"

### RA-oci-labs-010 - SECURITY.md fehlt
- status: offen
- schwere: mittel
- rolle: doku-tests
- ort: SECURITY.md
- regel: security-md
- gefunden: 2026-10-08
- beleg: keine SECURITY.md - kein Meldeweg fuer ein gefundenes Secret

### RA-oci-labs-011 - Kein README im Repo-Root
- status: offen
- schwere: mittel
- rolle: doku-tests
- ort: README.md
- regel: readme
- gefunden: 2026-10-08
- beleg: README.md fehlt - die GitHub-Startseite des public Repos ist leer; Einstieg nur ueber docs/

### RA-oci-labs-012 - CONTRIBUTING fehlt
- status: offen
- schwere: niedrig
- rolle: doku-tests
- ort: CONTRIBUTING.md
- regel: contributing
- gefunden: 2026-10-08
- beleg: keine CONTRIBUTING-Datei; Ein-Personen-Lab-Repo, niedrige Prioritaet

### RA-oci-labs-013 - make lint laeuft nicht in der CI
- status: offen
- schwere: mittel
- rolle: doku-tests
- ort: .github/workflows/ci.yml
- regel: ci-gate
- gefunden: 2026-10-08
- beleg: terraform fmt/validate, ansible-lint, yamllint, markdownlint, shellcheck laufen nur lokal (`make lint`)
