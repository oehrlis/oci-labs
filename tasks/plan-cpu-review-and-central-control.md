# Review brief: CPU patch tests - process, central control, manual run

> Stand 2026-10-24, fuer das Review offline (Flug). Drei Fragen von Stefan: was lesen,
> was braucht `cpu-patch-tests` fuer eine zentrale Steuerung, wie geht der Ablauf
> 100 % von Hand.

## 1. Was lesen - in dieser Reihenfolge

Vorher `git pull` in `oci-labs` (Branch `feat/cpu-lab`) und `cpu-patch-tests`. Die
Lab-Reports liegen nur lokal (git-ignored) unter `oci-labs/ansible/reports/oradb01/`.

<!-- markdownlint-disable MD013 MD060 -->
| # | Datei | Warum | Zeit |
| --- | --- | --- | --- |
| 1 | `oci-labs/tasks/plan-cpu-2026-10-tests.md` | Methode, Entscheide, Stand A/B/C, alle Befunde | 20 min |
| 2 | `oci-labs/docs/runbook-cpu-patch-lab.md` - Abschnitte Layout, WebLogic, Costs, Step 1-6 | der Ablauf, wie er heute laeuft | 30 min |
| 3 | `ansible/reports/oradb01/cputest-CPUDB-19_32-to-19_33-20261023.md` | Beleg 19c, so sieht ein Report aus | 5 min |
| 4 | `ansible/reports/oradb01/cputest-CPU26-23_26_3-to-23_26_4-20261023.md` | Beleg 26ai | 5 min |
| 5 | `ansible/roles/db19_engineering/defaults/main.yml` - Block `db_release_profiles` | was 19 von 26 unterscheidet, an einer Stelle | 10 min |
| 6 | `ansible/roles/db19_engineering/tasks/patch.yml` | DB-Ablauf: Baseline, Home, analyze, deploy, Listener, oratab | 15 min |
| 7 | `ansible/roles/wls_engineering/tasks/patch.yml`, `rollback.yml` | WLS in place + `opatch nrollback` (2026-10-24) - **noch nie gelaufen** | 15 min |
| 8 | `ansible/roles/wls_engineering/tasks/servers.yml`, `spb.yml` | Start/Stop ueber REST, SPBAT | 10 min |
| 9 | `cpu-patch-tests/patches/test_results_2026-10.csv` (Zeilen db19, db26) | was im Report landet | 5 min |
| 10 | `oci-labs/CHANGELOG.md` - `[Unreleased]` | alles Geaenderte in einem Blick | 10 min |
<!-- markdownlint-restore -->

Fragen, die beim Review entschieden werden sollten:

- **26ai Patch-IDs:** die Periodendaten fuehren 40007731 als "GI RU", im DB-Home steht es
  als "Database Release Update 23.26.4.0.0". Was schreibt der Report fuer 40002013,
  40014644, 40014665 - "covered by 40007731" oder nachtesten?
- **from_version:** 19c-Basis ist `19.32.0.0.261020` (MRP mit 19.33 erschienen), 26ai-Basis
  traegt die MRP-Fixes vom Download-Tag. Akzeptiert, oder Basis-MRP kuenftig pinnen?
- **PDB$SEED READ WRITE nach dem Deploy** - bei 19c und 26ai reproduziert. warn oder Note?
- **Public IP am 19c-Host** (`assign_public_ip = true`): die datasafe-demo-Baseline ist
  ohne. Beim naechsten Neubau auf den Core ohne Public IP?

## 2. Zentrale Steuerung aus cpu-patch-tests - was fehlt

Heute: `cpu-patch-tests` kennt den Zyklus (Advisory, Patch-IDs, Report), `oci-labs` kennt
das Lab. Die Verbindung sind Hand-Schritte (tfvars, group_vars, Uploads) und am Ende
`make import-lab`. Fuer "alles zentral" braucht es in `cpu-patch-tests`:

1. **Lab-Profil pro Periode** - `make lab-profile PERIOD=2026-10` schreibt aus
   `data/2026-10.yaml` eine Datei (z.B. `lab/2026-10.yaml`): je Produkt Basis und Ziel
   (19c: `19.32` + gepinnte MRP -> `19.33`; 26ai: `23.26.3` -> `23.26.4`; WLS je Version
   SPB-Basis und SPB-Ziel als Dateinamen). `oci-labs` liest sie ueber
   `CPU_PATCH_TESTS_DIR`, wie heute schon die AutoUpgrade-Profile der Collection. Damit
   entfallen die tfvars-Aenderungen pro Zyklus und `cpu_wls_hosts.yml` wird generiert
2. **Download und Upload der Nicht-DB-Patches** - `au-download` deckt nur die DB.
   WLS-SPBs und JDKs brauchen einen MOS-Download (heute `make urls` + Hand) und
   `make upload` nach `orarepo` mit stabilen Namen. Ein Ziel `make lab-media PERIOD=...`
   (Download + Upload + Namen ins Lab-Profil) schliesst die Luecke
3. **Fassade fuer die Laeufe** - `make lab-run PRODUCT=db19|db26|wls VERSION=...` ruft
   `$(MAKE) -C ../oci-labs cpu-lab-start|patch|verify|rollback|stop CPU_ENV=...` in der
   richtigen Reihenfolge, mit frischem Log-Pfad und Stop am Ende. apply bleibt bei Stefan
4. **import-lab erweitern** - heute nur DB (`MAJOR_TO_REQUIREMENT` db19/db26):
   - WLS-Reports (`cputest-WLS-*.json`, anderes Schema) einlesen
   - `from_version` mit MRP (`19.32.0.0.261020`) statt nur RU
   - Notes aus dem Report: Issues (Seed, Doppel-Download), manuelle Schritte, Rollback-Zeit
   - Zuordnung ueber Patch-ID **und** Beschreibung, damit "GI RU 40007731 im DB-Home" nicht
     still auf die falsche Zeile faellt
5. **Patch-ID-Daten** - in `data/2026-10.yaml` die 26ai-Zeilen pruefen (DB RU vs. GI RU)

Was in `oci-labs` bleibt: Terraform, Rollen, Make-Ziele, Runbook - die Infrastruktur.
Die Grenze: `cpu-patch-tests` entscheidet **was** getestet wird, `oci-labs` **wie**.

## 3. 100 % manuell - die Schritte

Alles aus `oci-labs`, `eval $(op signin)` vorher. `BASTION=1` immer.

### DB 19c (Stack `cpu-patch-test`)

```bash
# terraform/envs/cpu-patch-test/terraform.tfvars: db_base_ru, db_target_ru, db_oracle_home_base
make cpu-lab-plan && make cpu-lab-apply          # nur Inventory
make cpu-lab-start
make cpu-lab-patch BASTION=1 ANSIBLE_EXTRA="-e db19_autoupgrade_log_dir=/u00/app/oracle/cfgtoollogs/autoupgrade-<periode>"
make cpu-lab-verify BASTION=1
make cpu-lab-rollback BASTION=1
# GRP danach von Hand droppen (SQL im Runbook), sonst nimmt der naechste Lauf ihn
make cpu-lab-stop
```

### DB 26ai (Stack `cpu-patch-26ai`)

Gleich, mit `CPU_ENV=cpu-patch-26ai` an jedem Ziel. Erstinstallation:
`make cpu-lab-install CPU_ENV=cpu-patch-26ai BASTION=1`.

### WebLogic (Stack `cpu-patch-wls`)

```bash
# 1. Installer, JDK, SPB 2026-07 und 2026-10 nach orarepo hochladen (flach)
# 2. Namen in ansible/playbooks/group_vars/cpu_wls_hosts.yml eintragen
make cpu-lab-repo-par CPU_ENV=cpu-patch-wls REPO_CHECK=<eine hochgeladene Datei>
make cpu-lab-start CPU_ENV=cpu-patch-wls
make cpu-lab-install CPU_ENV=cpu-patch-wls BASTION=1 ANSIBLE_EXTRA="-e wls_only=14.1.2.0.0"
make cpu-lab-patch CPU_ENV=cpu-patch-wls BASTION=1 ANSIBLE_EXTRA="-e wls_only=14.1.2.0.0"
make cpu-lab-rollback CPU_ENV=cpu-patch-wls BASTION=1 ANSIBLE_EXTRA="-e wls_only=14.1.2.0.0"
make cpu-lab-stop CPU_ENV=cpu-patch-wls
make cpu-lab-par-revoke CPU_ENV=cpu-patch-wls
```

### Report

```bash
cd ../cpu-patch-tests
make import-lab PERIOD=<periode> LAB_DIR=<Ordner nur mit dem Report des Laufs> OS_LABEL="Oracle Linux 8.10" [OVERWRITE=1]
# Notes, from_version mit MRP und Issues heute von Hand in patches/test_results_<periode>.csv
```

Was man sieht: jedes `make` zeigt die volle Ansible-Ausgabe. Lange Schritte laufen async,
ihre Ausgabe kommt am Ende des Schritts; live `make cpu-lab-progress` / `cpu-lab-watch`,
Logs `make cpu-lab-logs`.

Stolpersteine, die heute aufgetreten sind:

- Ein abgebrochener AutoUpgrade-Job blockiert den Log-Pfad - jeder Lauf mit eigenem Pfad
- Ein liegengebliebener GRP wird vom naechsten Rollback genommen - nach jedem Lauf droppen
- `cpu-lab-verify` nur nach dem Patch, nicht als Vorher-Aufnahme (heute abgesichert)
- Tunnel-Ports: 2222 (19c), 2224 (26ai), 2225 (WLS) - 2223 gehoert datasafe-demo
