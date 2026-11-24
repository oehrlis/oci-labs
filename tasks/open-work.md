# Open work - oci-labs

The one checkbox file of this repo. Re-entry point of the last session: newest `tasks/state-*.md`. Lessons:
`tasks/lessons.md`. Repo-audit findings with stable IDs: `tasks/review-register.md` (0 open on 2026-11-24, all
closed in v0.7.1) - new findings come from the next `/repo-audit` run. Done items leave this file; the record is the
state file and the CHANGELOG.

## Now

- [ ] Morgen 2026-11-25 nach 16:00 (Vortrag 15:00): Data-Safe-Demo-Lab abbauen - `make dsdemo-destroy`, Plan vorher
  zeigen - und `ci-zrh-lab-cpu-db26-01` (Trivadis) stoppen [P1] (due: 2026-11-25)
- [ ] Release v0.7.1: PR `fix/register-hardening` reviewen und mergen, danach Tag `v0.7.1` setzen und pushen; erster
  CI-Lauf von `ci.yml` beobachten [P1]
- [ ] `.env` fuer mfa_oma_setup von Hand anlegen (Session darf `.env` nicht schreiben) - bis dahin die drei OCIDs als
  `TF_VAR_*` (ACE-Tenancy-OCID zweimal, Default-Domain-OCID) [P3]

## Waiting

- [ ] 19c RU 19.28+: MFA-SMTP-Credential (`MFA_SMTP_CREDENTIAL$` oder Wallet) und `DBA_USERS`-MFA-Spalten pruefen,
  KB-TODOs in delphi-oradba `mfa.md` aufloesen - auf einem 19c-Image aus oradba-docker (Lab-Architektur M2, KW48)
  [P2] [wartet: oradba-docker]
- [ ] Windows-AD/CMU-Lab neu bauen fuer den CMU-Test, mit dem gehaerteten Modul (v0.7.1) ueber den OCI-Runner
  (Lab-Architektur M5, KW51); CMU/Kerberos auf dem DB-Server (krb5.conf, sqlnet.ora, keytab) dabei nachholen.
  Vorher in ad-lab: `01_install_ad_role.ps1` loggt das Passwort auf DEBUG [P3]

## CPU lab

- [ ] Vor dem naechsten Neubau: `cpu-patch-test` tfvars auf `assign_public_ip = false`,
  Host am Core statt eigenem Netz [P3]
- [ ] `lab_count = 2` einmal real testen [P3]
- [ ] Verifikations-SQL aus `verify.yml` und `smoke.yml` in eigene Dateien [P3]
- [ ] Runbook-Aussage "19c-Gold-Image ueber den Update Advisor = HTTP 500" mit AutoUpgrade 26.6 abgleichen
  (`docs/runbook-cpu-patch-lab.md` Tabelle bei Zeile 325, `docs/datasafe-demo.md`) [P3]
- [ ] Lab-Stubs `lab-db19eng`, `lab-oudeng`, `lab-wlseng`, `full-lab-bootstrap` und die zwei infra-tools-Skripte:
  fuellen oder loeschen - mit dem Ansible-Umzug nach oradba-ansible (M4) entscheiden [P3]

## Planned, not decided

- Security Central Lab (Nachfolger AVDF) als eigener Stack: Brief `tasks/plan-dbsec-central.md`, Idee in
  `~/notes/ideas.md` (2026-11-17) - geparkt bis nach Lab-Architektur M5 (Entscheid Stefan 2026-11-24)

## Elsewhere (not in this repo)

- Lab-Architektur M4 (KW50, Ansible nach oradba-ansible, E7 Umbenennung) und M5 (KW51, OCI-Runner):
  `~/notes/areas/oci-labs.md`. M4 bleibt KW50, cpu-patch-tests L6 auf 2026-12-11 gezogen (Entscheid 2026-11-24)
- oradba-ansible: Lab-Vorlagen dbca.rsp, tnsnames.ora, listener.ora mit den oradba-Templates zusammenfuehren
  (Change Request `git show fdece8e:tasks/cr-oradba-shared-templates.md`)
