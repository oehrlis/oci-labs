# Open work - oci-labs

The one checkbox file of this repo. Re-entry point of the last session: newest `tasks/state-*.md`. Lessons:
`tasks/lessons.md`. Repo-audit findings with stable IDs: `tasks/review-register.md` (22 open on 2026-11-24) - the
items below name only those worth scheduling. Done items leave this file; the record is the state file and the
CHANGELOG.

## Now

- [ ] Data-Safe-Demo-Lab nach der UKOUG-Session (Mi 2026-11-25 15:00) stoppen oder abbauen, nicht frueher
  (`make dsdemo-stop` / `make dsdemo-destroy`) [P2] (due: 2026-11-26)
- [ ] 19c RU 19.28+: MFA-SMTP-Credential (`MFA_SMTP_CREDENTIAL$` oder Wallet) und `DBA_USERS`-MFA-Spalten pruefen,
  KB-TODOs in delphi-oradba `mfa.md` aufloesen [P2]
- [ ] ACE: geloeschte ADBs als TERMINATED pruefen, Restbetrag in der Konsole gegen `--credits` abgleichen [P2]
- [ ] `.env` fuer mfa_oma_setup von Hand anlegen (Session darf `.env` nicht schreiben) - bis dahin die drei OCIDs als
  `TF_VAR_*` (ACE-Tenancy-OCID zweimal, Default-Domain-OCID) [P3]
- [ ] Release v0.7.1 aus `[Unreleased]` (MFA-Fixes, tasks-Bereinigung) vor dem Ansible-Umzug [P3]

## Security and repo hygiene (review-register)

- [ ] `windows_ad`: NSG auf VCN-/Home-CIDR begrenzen, Passwort-Datei auf dem DC loeschen, `no_log` in der Rolle,
  ad-lab-Skripte auf einen Tag pinnen (RA-oci-labs-016/017/022/023) [P2]
- [ ] `modules/network`: Default von `allowed_ssh_cidrs` von 0.0.0.0/0 auf leer (RA-oci-labs-021) [P2]
- [ ] Gold-Image-Push: Write-PAR per Datei statt im argv, Laufzeit begrenzen, per `trap` widerrufen
  (RA-oci-labs-015/019) [P2]
- [ ] CI: `make lint` als GitHub-Workflow neben gitleaks (RA-oci-labs-013) [P2]
- [ ] Kleinkram aus dem Register in einem Zug: `.gitignore` (auto.tfvars, tfplan), gitleaks-OCID-Regel und Basis-Config,
  Secrets-Doku ohne argv, CONTRIBUTING.md, CLAUDE.md (Build/Test, Lint-Kommando), Makefile-Kopf-Version,
  `terraform/global` im Lint, `site2site-udm` loeschen, Em-Dashes in der MFA-Doku
  (RA-oci-labs-012, 020, 024-033, 040-042) [P3]

## CPU lab

- [ ] Vor dem naechsten Neubau: `cpu-patch-test` tfvars auf `assign_public_ip = false`,
  Host am Core statt eigenem Netz [P3]
- [ ] `lab_count = 2` einmal real testen [P3]
- [ ] Verifikations-SQL aus `verify.yml` und `smoke.yml` in eigene Dateien [P3]
- [ ] Runbook-Aussage "19c-Gold-Image ueber den Update Advisor = HTTP 500" mit AutoUpgrade 26.6 abgleichen
  (`docs/runbook-cpu-patch-lab.md` Tabelle bei Zeile 325, `docs/datasafe-demo.md`) [P3]
- [ ] Lab-Stubs `lab-db19eng`, `lab-oudeng`, `lab-wlseng`, `full-lab-bootstrap` und die zwei infra-tools-Skripte:
  fuellen oder loeschen - mit dem Ansible-Umzug nach oradba-ansible (M4) entscheiden [P3]

## Windows AD / CMU lab (ad-cmu-test)

- [ ] Stand pruefen: laeuft der DC noch (einmal angewendet, kein lokaler State), WinRM vom Home-Lab ueber DRG [P3]
- [ ] CMU/Kerberos auf dem DB-Server nachholen (krb5.conf, sqlnet.ora, keytab),
  ad-lab-Skripte auf `oradba.ch` pruefen [P3]

## Planned, not decided

- Security Central Lab (Nachfolger AVDF) als eigener Stack: Brief `tasks/plan-dbsec-central.md`, Idee in
  `~/notes/ideas.md` (2026-11-17) - erst nach Entscheid bauen

## Elsewhere (not in this repo)

- Lab-Architektur M4 (KW50, Ansible nach oradba-ansible, E7 Umbenennung) und M5 (KW51, OCI-Runner):
  `~/notes/areas/oci-labs.md`. Termin-Widerspruch: cpu-patch-tests L6 (gleicher Umzug) due 2026-12-18
- oradba-ansible: Lab-Vorlagen dbca.rsp, tnsnames.ora, listener.ora mit den oradba-Templates zusammenfuehren
  (Change Request `git show fdece8e:tasks/cr-oradba-shared-templates.md`)
