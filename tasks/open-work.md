# Open work - oci-labs

The one checkbox file of this repo (replaces `tasks/todo.md`). Re-entry point of the last session:
newest `tasks/state-*.md`. Lessons: `tasks/lessons.md`. Repo-audit findings with stable IDs: `tasks/review-register.md`
(22 open on 2026-11-23) - the items below name only those worth scheduling.

## Now

- [x] MFA-Live-Demo (OMA Push) fuer UKOUG S4 auf base26 - steht, Stand `tasks/state-2026-11-24.md`
- [ ] mfa_oma_setup: Terraform-State sichern, dann `terraform apply` (nur Output) [P1] (due: 2026-11-25)
- [ ] Data-Safe-Demo-Lab nach der UKOUG-Session stoppen oder abbauen
  (`make dsdemo-stop` / `make dsdemo-destroy`) [P2] (due: 2026-11-26)
- [ ] ACE: geloeschte ADBs als TERMINATED pruefen, Restbetrag in der Konsole gegen `--credits` abgleichen [P2]

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
- [ ] orarepo-Kandidaten (jdk-11.0.20, jdk-17.0.9, jdk-11.0.10.rpm, wls_lite_slim, grid 19.3 Home)
  behalten oder loeschen [P3]

## Windows AD / CMU lab (ad-cmu-test)

- [ ] Stand pruefen: laeuft der DC noch (einmal angewendet, kein lokaler State), WinRM vom Home-Lab ueber DRG [P3]
- [ ] CMU/Kerberos auf dem DB-Server nachholen (krb5.conf, sqlnet.ora, keytab),
  ad-lab-Skripte auf `oradba.ch` pruefen [P3]

## Elsewhere (not in this repo)

- oradba-ansible: Lab-Vorlagen dbca.rsp, tnsnames.ora, listener.ora mit den oradba-Templates zusammenfuehren
  (`~/notes/areas/oci-labs.md`, Change Request `git show fdece8e:tasks/cr-oradba-shared-templates.md`)
- Lab-Architektur M4 (Ansible nach oradba-ansible) und M5 (OCI-Runner): `~/notes/areas/oci-labs.md`
