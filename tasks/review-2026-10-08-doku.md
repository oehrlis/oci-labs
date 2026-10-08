# Doku-Review 2026-10-08

<!-- markdownlint-disable MD013 -->

- rolle: doku-tests
- commit: fb5bedb
- datum: 2026-10-08
- modus: quick

Scope: README.md, CLAUDE.md, docs/, CHANGELOG.md, VERSION, Makefile gegen den Code.
Scan-Vorlauf: tasks/review-2026-10-08-scan-markdown.md (Warnhinweis beachtet - siehe unten).

---

## Akzeptierte Befunde (nicht gemeldet)

RA-oci-labs-001, RA-oci-labs-002, RA-oci-labs-003 - Owner-Entscheid dokumentiert.

---

## Behobene Befunde - nicht mehr gefunden

- RA-oci-labs-004 (OCID im Runbook) - behoben in 7769324, Platzhalter bestaetigt.
- RA-oci-labs-006 (kein Secret-Scan in CI) - .github/workflows/gitleaks.yml vorhanden.
- RA-oci-labs-007 (kein Pre-commit-Hook) - tools/git-hooks/pre-commit + make hooks vorhanden.
- RA-oci-labs-008 (make lint ohne Secret-Scan) - lint-secrets-Target vorhanden, kein stiller Skip mehr (Makefile:185 nennt jede uebersprungene Env explizit).
- RA-oci-labs-009 (LICENSE fehlt) - LICENSE vorhanden.
- RA-oci-labs-010 (SECURITY.md fehlt) - SECURITY.md vorhanden.
- RA-oci-labs-011 (kein README) - README.md vorhanden.

---

## Weiterhin offen

### RA-oci-labs-012 - CONTRIBUTING fehlt

- status: offen
- schwere: niedrig
- rolle: doku-tests
- ort: CONTRIBUTING.md
- regel: contributing
- gefunden: 2026-10-08
- gesehen: 2026-10-08
- beleg: kein CONTRIBUTING.md im Root; `ls /oci-labs/CONTRIBUTING* -> MISSING`

### RA-oci-labs-013 - make lint laeuft nicht in der CI

- status: offen
- schwere: mittel
- rolle: doku-tests
- ort: .github/workflows/ci.yml
- regel: ci-gate
- gefunden: 2026-10-08
- gesehen: 2026-10-08
- beleg: .github/workflows/ enthaelt nur gitleaks.yml; kein ci.yml; terraform fmt/validate, ansible-lint, yamllint, markdownlint, shellcheck laufen nur lokal

---

## Neue Befunde

### F-01 - CLAUDE.md enthaelt unfuellte TODO-Platzhalter

- schwere: mittel
- rolle: doku-tests
- ort: CLAUDE.md
- regel: todo
- beleg: CLAUDE.md:5 - `TODO: describe project purpose, tech stack, and main commands.`; CLAUDE.md:9 - `- Build/Test: TODO`
- ausloeser: wenn ein neuer Contributor oder ein Agent die CLAUDE.md liest, bekommt er weder Projektzweck noch Build-Kommandos - der Agent startet ohne Kontext
- aufwand: S
- fix: CLAUDE.md:5 durch zwei Saetze zu IaC-Stack (Terraform + Ansible + Makefile fuer OCI-Lab-Envs) ersetzen; CLAUDE.md:9 durch `make lint` / `make help` ersetzen

### F-02 - CLAUDE.md nennt falsches Lint-Kommando

- schwere: niedrig
- rolle: doku-tests
- ort: CLAUDE.md
- regel: doc-drift
- beleg: CLAUDE.md:10 - `markdownlint docs/` vs Makefile:211-214 - `markdownlint "**/*.md"` mit .markdownlintignore
- ausloeser: wer das dokumentierte Kommando verwendet, prueft nur docs/ und uebersieht terraform/, ansible/, tasks/; die .markdownlintignore wird ausserdem nicht angewendet
- aufwand: S
- fix: CLAUDE.md:10 auf `make lint-markdown` oder `markdownlint "**/*.md"` korrigieren

### F-03 - Makefile-Kopfzeile zeigt Version v0.1.0 statt 0.3.0

- schwere: niedrig
- rolle: doku-tests
- ort: Makefile
- regel: doc-drift
- beleg: Makefile:8 - `# Version....: v0.1.0`; VERSION:1 - `0.3.0`; Makefile:39 liest VERSION korrekt per `$(shell cat VERSION)` - nur der Kopfkommentar ist veraltet
- ausloeser: Leser des Makefile-Headers erhalten die falsche Versionsnummer; die tatsaechliche Auslieferungsversion ist davon nicht betroffen (Makefile:39)
- aufwand: S
- fix: Makefile:8 auf aktuellen Wert aus VERSION setzen; bei version-bump-Targets Kopfzeile mitsynchronisieren oder einen Hinweis einfuegen, dass der Kopf manuell nachgezogen werden muss

### F-04 - 6 leere Platzhalter-.md-Dateien in git getrackt

- schwere: niedrig
- rolle: doku-tests
- ort: ansible/docs/ansible-workflow.md
- regel: orphan-doc
- beleg: ansible/docs/ansible-workflow.md:0 Zeilen; ansible/docs/architecture-config.md:0 Zeilen; ansible/docs/profiles-overview.md:0 Zeilen; ansible/inventories/README.md:0 Zeilen; docs/lab-odb19eng-single.md:0 Zeilen; docs/lab-odb19sec-dg.md:0 Zeilen - alle via `wc -l` bestaetigt
- ausloeser: Links auf diese Dateien liefern leere Seiten; ein Leser findet Platzhalter statt Inhalt; markdownlint meldet keine Verletzung (leere Datei loest MD041 nicht aus - der Scan-Vorlauf hatte das als MD041-Befund eingetragen, was falsch ist)
- aufwand: S per Datei, oder loeschen wenn kein Inhalt geplant
- fix: entweder Mindestinhalt (H1 + ein Satz zum Scope) einfuegen oder Dateien entfernen und aus git untracking

### F-05 - Em-Dashes in Markdown-Dateien statt Bindestrich

- schwere: niedrig
- rolle: doku-tests
- ort: docs/runbook-mfa-oma.md
- regel: doc-drift
- beleg: docs/runbook-mfa-oma.md - 15 Em-Dash-Zeichen (U+2014) bestaetigt via grep; docs/spec-iam-mfa-oma.md - 3 Instanzen; terraform/modules/iam_mfa_oma/README.md - 1 Instanz; insgesamt 19 Instanzen in 4 Dateien (Scan-Vorlauf: docs/runbook-mfa-oma.md:22,43,68,70,72,82,89,92,190,194,447,503,538,671,786; docs/spec-iam-mfa-oma.md:255,257,258; terraform/modules/iam_mfa_oma/README.md:170)
- ausloeser: .claude/rules/markdown-lint.md schreibt "hyphen-minus ` - ` only, never em-dash" vor; Verletzung nicht durch markdownlint abgefangen
- aufwand: S
- fix: sed-Ersetzung `s/—/ - /g` auf betroffene Dateien; Sonderfall Mermaid-Diagrammstrings (runbook-mfa-oma.md:22,43) auf Korrektheit pruefen, da Em-Dash dort in einem String-Literal steht

---

## Scan-Vorlauf-Korrekturen

Der Vorlauf tasks/review-2026-10-08-scan-markdown.md enthielt zwei unrichtige Behauptungen:

1. **MD041-Befunde falsch klassifiziert**: Die 6 gemeldeten Dateien haben nicht "leere erste Zeile" - sie sind vollstaendig leer (0 Bytes). Leere Dateien loesen MD041 nicht aus. Markdownlint v0.49.1 mit der Repo-Config bestaetigt 0 Verletzungen. Der korrekte Befund ist orphan-doc (F-04), nicht MD041.

2. **197 bare fences unzutreffend**: Das grep auf `^\`\`\`$` trifft schliessende Fences, die per Markdown-Syntax keine Sprache enthalten. Markdownlint (MD040, via `default: true`) meldet 0 Verletzungen auf docs/runbook-mfa-oma.md (50 gemeldete Fences) - oeffnende Fences in diesem File haben Sprachangaben. Die 197 sind kein echter Befund.

---

## Was gut ist

- **README.md**: praezise Beschreibung, alle 5 Dokument-Links auf existierende Dateien verifiziert (`docs/architecture-overview.md`, `docs/namingconcept.md`, drei Runbooks).
- **CHANGELOG.md**: Keep-a-Changelog-Format konsequent eingehalten; [Unreleased]-Sektion dokumentiert post-0.3.0-Arbeit vollstaendig (20 Commits, inhaltlich abgedeckt).
- **VERSION vs CHANGELOG**: VERSION=0.3.0, letztes Release-Tag [0.3.0] - konsistent. [Unreleased] korrekt fuer uncommittete Releases.
- **make lint**: vollstaendiger lokaler Gate (terraform, ansible, yaml, markdown, shell, secrets) ohne `|| true` in Lint-Targets (RA-oci-labs-008 korrekt behoben).
- **CI gitleaks**: Versionen gepinnt (gitleaks 8.30.1 + SHA-256, checkout via Commit-SHA), Full-History-Scan, Allowlist fuer bekannte Altlasten.
- **README Secrets-Sektion**: beschreibt `op read`, gitignore und Pre-commit-Hook korrekt und stimmig mit dem Code.
- **SECURITY.md, LICENSE**: vorhanden und inhaltlich korrekt.
- **Runbook-Platzhalter**: docs/runbook-ad-cmu-lab.md verwendet nach RA-oci-labs-004-Fix `<compartment_ocid>` und `<drg_ocid>` statt echter OCIDs - bestaetigt.

---

## BLOCKIERT

Keine BLOCKIERT-Zeilen in diesem Lauf. Alle geprueften Targets waren zugaenglich.

---

## Offene Fragen

OFFENE FRAGE: Sind die 6 leeren .md-Dateien bewusste Platzhalter fuer geplante Inhalte oder vergessene Stuempfe? - Annahme: Stuempfe, daher als orphan-doc gemeldet.
