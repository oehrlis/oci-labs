# Plan: CPU 2026-10 - Patch-Tests fuer den Report

> Stand 2026-10-22. Ersetzt den Fokus von `plan-cpu-2026-10.md`: dort stand die
> oradba.automation-Collection im Vordergrund, fuer den Report zaehlt nur der Patch.
> Ziel: belegte Testresultate pro Patch-ID in `cpu-patch-tests/patches/test_results_2026-10.csv`.

## Was der Report braucht

Pro Patch eine Zeile: `product, requirement, patch_id, component, platform, from_version,
to_version, os, runtime, result (ok|warn|nok), note_en, note_de`. Die Frage pro Zeile:
**Laesst sich der Patch auf den letzten Stand installieren, welche Issues gibt es, was
muss man tun?** Im Juli stand ueberall `ok`, ohne OS, Laufzeit und Ausgangsversion - das
ist der Massstab, den wir dieses Mal belegen.

Entscheide 2026-10-22 (Stefan): echt getestet werden DB 19c, DB 26ai und WLS/FMW, nur
out-of-place, Ausgang ist das vorherige RU. 21c, Java, OUD, GI und Windows bleiben Review.
Bis Sonntag 2026-10-25 so viel wie moeglich, danach remote aus Las Vegas, Report bis 2026-11-27.

## Testmatrix

<!-- markdownlint-disable MD013 MD060 -->
| Produkt | Patch (ID) | from -> to | Wie | Status heute |
| --- | --- | --- | --- | --- |
| DB 19c | Database RU 19.33 (`39915792`) | 19.32 -> 19.33 | neues Home, deploy, datapatch | Lab steht, DB auf 19.31 |
| DB 19c | OJVM RU 19.33 (`39803650`) | 19.32 -> 19.33 | im selben neuen Home | dito |
| DB 19c | Oracle JDK (`39902051`) | im Home | im selben neuen Home | dito |
| DB 19c | Combo DB + OJVM (`40121635`) | - | deckt sich mit RU + OJVM, Note "covered by" | - |
| DB 19c | MRP 19.33 (falls publiziert) | - | im selben neuen Home | - |
| DB 26ai | DB RU 23.26.4 (`40002013`), Gold Image (`40014644`) | 23.26.3 -> 23.26.4 | neues Home aus Gold Image, deploy | Host fehlt |
| WLS 14.1.2 | SPB (`40125898`) | SPB 2026-07 -> 2026-10 | zweites Oracle Home, SPB, Domain umziehen | Lab fehlt, Installer fehlt |
| WLS 15.1.1 | SPB (`40128310`) | dito | dito | Lab fehlt, Installer fehlt |
| WLS 12.2.1.4 | SPB (`40129641`) | dito | dito | Installer in `orarepo` |
| WLS 14.1.1 | SPB (`40129124`) | dito | dito | Installer in `orarepo` |
| GI RU, Windows Bundle, 21c, Java, OUD | - | - | Review, `result` leer oder per `test_covered_by` | - |
<!-- markdownlint-restore -->

Prioritaet bei Zeitmangel: DB 19c > DB 26ai > WLS 14.1.2 > WLS 15.1.1 > WLS 12.2.1.4 > WLS 14.1.1.

Methode (Stefan, 2026-10-23): getestet wird immer das neue RU. Basis ist der Stand des
Vormonats - vorheriges RU plus letzte MRP davor (Oktober: 19.32 + MRP September; November:
19.33 plain als Basis). Ob monatlich getestet wird, ist offen. **Abweichung 2026-10:** die
Basis traegt MRP 40062896 (19.32.0.0.261020, erschienen mit 19.33), weil
`RECOMMENDED:19.32` gegen den heutigen MOS-Stand aufloest - im Report als
`from 19.32.0.0.261020` benennen. Ab dem naechsten Zyklus die Basis-MRP explizit pinnen.

## Testprotokoll (gleich fuer alle DB-Tests)

Das Werkzeug fuer das neue Home ist Mittel, nicht Testgegenstand. Fuer die DB nehmen wir
den Weg, der im Lab belegt ist: die Lab-Rolle `db19_engineering` (AutoUpgrade
`create_home` + `deploy`, MOS-Download auf dem Host). Pro Lauf festhalten:

1. Vorher: Version, `dba_registry_sqlpatch`, invalide Objekte, Komponentenstatus, PDB-Status
2. Patch-Set: was tatsaechlich im neuen Home liegt (`opatch lspatches`), OPatch-Version
3. Laufzeit getrennt: Download, Home bauen, Downtime (deploy bis DB offen), datapatch
4. Nachher: Version, SQL-Patch-Status je Container, invalide Objekte, `utlrp`, Alert-Log-Fehler
5. Issues: Konflikte, Warnungen, manuelle Schritte, MOS-Notes
6. Rollback auf das alte Home (datapatch zurueck) - belegt, dass der Rueckweg geht

Ergebnis: `cputest-*.json` / `.md` (macht die Lab-Rolle heute schon), importiert mit
`cpu-patch-tests make import-lab LAB_DIR=... OS_LABEL=...`.

## Arbeitspakete

### A - DB 19c: 19.32 -> 19.33 (Fr 2026-10-23)

- [x] Baseline 19.32 herstellen (2026-10-23, 09:45-10:24): **frisches Home**
  `product/19.32-rec/dbhome_1` per Lab-Rolle, `RECOMMENDED:19.32,JDK` = RU 19.32 +
  OJVM + DPBP + OPatch 54 + MRP 40062896 (19.32.0.0.261020, `release 19.32.0.0.0DBRU`) +
  JDK 39902051. Log-Pfad `autoupgrade-2026-10-base`. 19.31 -> 19.32, 0 invalid, datapatch
  leer, harte Kriterien PASS. GRP `AU_PATCHING_9212_CPUDB1931000` danach gedroppt.
  Die vorhandenen Homes fielen im `analyze` durch: AU 26.6 loest `OPATCH`/`MRP`/`JDK`
  gegen den heutigen MOS-Stand auf. `product/19.32/dbhome_1` (August) fehlen OPatch 54,
  MRP, JDK 2610; `RU:19.32,OJVM,DPBP` ohne OPATCH lehnt AU ab ("OPATCH must be included").
  `product/19.32.0.0` (Lauf A) fehlt die MRP 40062896
- [x] tfvars `db_base_ru = "19.32"`, `db_target_ru = "19.33"`,
  `db_oracle_home_base = ".../product/19.32-rec/dbhome_1"`; `make cpu-lab-plan`:
  nur `local_file.ansible_inventory` (1 add / 1 destroy), `moved` egress_all, Outputs
- [x] `make cpu-lab-apply` - Stefan, nur Inventory
- [x] `make cpu-lab-patch` 2026-10-23 11:07-11:45, Log-Pfad `autoupgrade-2026-10`,
  **PASSED** - 19.33.0.0.0, 30 sqlpatch-Zeilen SUCCESS, 0 -> 0 invalid, 15 Komponenten,
  Smoke PL/SQL / OJVM (JDK 1.8.0_511) / Data Pump PASS. Patch-Set: RU 39915792, OJVM
  39803650, DPBP 40057600, JDK 39902051, OPatch 54, `MRP: no` (zu 19.33 gibt es im Oktober
  keine). Laufzeit: Download 3 min (MOS, kein Fallback), Home 20 min, analyze 1 min,
  **Downtime 1 min** (11:34:45 Shutdown - 11:35:32 open), datapatch 5 min (CDB 3, PDBs 2),
  Postchecks 1.5 min
- [x] `make cpu-lab-rollback` 11:57-11:59 (1.5 min): Flashback auf
  `AU_PATCHING_9212_CPUDB1932000`, CPUDB 19.32.0.0.0 aus `19.32-rec`, 0 invalid, oratab
  zurueck auf `:Y`. **Offen beim naechsten Start:** PDB$SEED-Modus, GRP noch da,
  `dba_registry_sqlpatch` nach dem Rollback - der Tunnel war beim Nachcheck schon zu
- [x] `make import-lab` (OVERWRITE=1, nur der 19.33-Report als LAB_DIR): RU, OJVM, JDK
  `ok`/`tested`, from 19.32, to 19.33.0.0.0, OL 8.10, Laufzeit aufgeteilt. Ersetzt die
  unbelegten `ok`-Platzhalter
- [ ] Notes in `test_results_2026-10.csv` ergaenzen - **Stefan / cpu-patch-tests-Session**
  (import-lab kann es nicht): from `19.32.0.0.261020` statt `19.32`; PDB$SEED nach dem
  Deploy READ WRITE (manueller Schritt); Rollback per GRP in 1.5 min belegt

Issues aus dem Lauf, fuer den Report:

- **PDB$SEED READ WRITE nach dem Deploy** (auch Lauf A). Alert-Log: AU oeffnet den Seed
  nach seinem Restart 11:43:08 READ ONLY und 11:43:10 wieder READ WRITE - passt zu
  "Resetting the database's state", AU stellt vermutlich den Zustand her, den es um 11:33:02
  fuer GRP/Fixups selbst gesetzt hat. Manuell: Seed schliessen, READ ONLY oeffnen
- AU meldet "Drop GRP [CPUDB] SUCCESS", der GRP bleibt aber (korrekt bei
  `drop_grp_after_patching=no`) - irrefuehrende Meldung
- `OLD_TIME_ZONES_EXIST` - Fixup wie konfiguriert uebersprungen, DST ist nicht Teil des Patches

### B - DB 26ai: 23.26.3 -> 23.26.4 (Fr/Sa)

Entscheide 2026-10-23 (Stefan): ein VCN + eine Bastion fuer das Thema CPU, getrennte
Hosts pro Version/Produkt; OL9; eine Rolle mit Release als Variable (nur `19` | `26`);
Basis = vorherige MRP oder RU, was geht (fuer 26ai gibt es MRPs und Gold Images).

Nachtrag 2026-10-23 (Stefan): Basisdienste (VCN, Bastion, Bucket) kommen aus dem
**Core-Stack `envs/core`**, Host-Envs fuer db19 / db26 / wlsXX haengen daran (19c zieht beim
naechsten Neubau nach). Gold Image als Default-Weg **jetzt** fuer 19 und 26 (heute baute
`create_home` aus `LINUX.X64_193000_db_home.zip` + Patches). 26ai-Host wie 19c (8 OCPU /
32 GB), WLS-Hosts 4 OCPU, Summe < 0.5 USD/h; **Kostenaufstellung inkl. Storage in die Doku**.
Autonomie wie A (apply Stefan).

Bestand (Survey 2026-10-23): alle Hosts im Stack `cpu-patch-test` sind identisch (Shape,
Image, Rolle skalar), das Inventory hat eine Gruppe mit 19c-Variablen, `oracle_db_native`
erzwingt OL8 und Data-Safe-Variablen, **kein 26ai-Deploy-Flow existiert**.

Weg - kein Umbau am 19c-Stack, kein Plan auf Host 01:

1. **Neues Env `terraform/envs/cpu-patch-26ai`**: nutzt VCN, DB-Subnetz und Bastion aus
   `envs/core` per `terraform_remote_state` (lokaler State), baut nur Host + Key +
   Inventory (`oracle_db_host`-Modul, OL9-Image, 8 OCPU / 32 GB, Gruppe `cpu_patch_26ai`).
   Spaeter WLS-Hosts (4 OCPU) nach demselben Muster
2. **Makefile**: `CPU_ENV ?= cpu-patch-test` steuert Env-Dir, Inventory, Playbook; alle
   `cpu-lab-*`-Ziele inkl. Bastion-Tunnel laufen mit `CPU_ENV=cpu-patch-26ai`. Tunnel-Port
   je Env (2222 / 2223), damit beide parallel gehen
3. **Rolle `db19_engineering` versionieren**: `db_release: 19 | 26` (23.x-RU-Strings ->
   26, explizit). Je Release: OS-Assert (19: OL8, 26: OL8/OL9), Preinstall-RPM
   (`oracle-database-preinstall-19c` | `-23ai`), Base-Image/Gold-Image-Weg, Default-
   Patch-Listen, AU `target_version`. Patch, Verify, Smoke, Rollback, Report bleiben
   gemeinsam - gleiche Messung wie A. Umbenennen in `db_engineering` erst nach dem Zyklus
4. **Basis 26ai**: Home aus dem Gold Image der Basis (23.26.3 bzw. letzte MRP davor),
   per AU `create_home`; CDB + PDB1 per dbca wie bei 19c. Ziel 23.26.4: RU 40002013 bzw.
   Gold Image 40014644
5. Lauf: plan/apply **Stefan**, dann install, patch, verify, rollback, stop, `import-lab`

- [x] 1-3 gebaut, offline geprueft (`bc48733`); Plan 15 add / 0 change / 0 destroy, apply Stefan
- [x] Install 2026-10-23, 7 Anlaeufe bis gruen (15:13-15:26): Host `ci-chzh-l-cpu26-01-db-01`,
  OL 9.8, CDB `CPU26` + PDB1 auf **23.26.3.0.0** aus Gold Image (Oracle-Build 2026-10-21:
  RU 39578879 + OCW 39578859 + 25 MRP-Fixes), 0 invalid, 14 Komponenten. Befunde unterwegs:
  `getent_passwd` (ansible-core), Gold-Download fehlte `dl1.gold_image=YES`, create_home nutzte das
  Gold Image nicht, abgebrochene AU-Jobs blockieren den Log-Pfad
- [x] Patch 23.26.3 -> 23.26.4 (2. Lauf 16:43-17:10, Deploy mit `gold_image=YES`): **PASSED** -
  4 harte Kriterien PASS, 0 -> 0 invalid, 14 Komponenten, Smoke PL/SQL / OJVM (JDK 11.0.33) /
  Data Pump PASS. Ziel-Home: **RU 40007731** (23.26.4.0.0) + OCW 40007723. **Downtime 9 s**
  (16:58:33 - 16:58:42), datapatch 6.5 min (CDB 3.5, PDBs 2.5). Weiches Kriterium "binary patch
  set" FAIL ist ein Rollen-Fehler (Manifest las 23.26.3), behoben, nicht auf dem Host gelaufen
- [x] Rollback 17:11-17:12 (1 min): Flashback auf `AU_PATCHING_9212_CPU262326300`, 23.26.3, 0
  invalid, oratab `:Y`, sqlpatch nur 39578879, PDB$SEED READ ONLY. **GRP noch da** - vor dem
  naechsten Lauf droppen. Instanz STOPPED
- [ ] Import nach `cpu-patch-tests` - **blockiert, Stefan**: die Periodendaten fuehren 40002013
  als "Database RU" und **40007731 als "GI RU"**, im DB-Home meldet `opatch` 40007731 als "Database
  Release Update : 23.26.4.0.0". `import-lab` (Dry-Run) fuellt deshalb keine Zeile, ein
  `OVERWRITE=1` haette die GI-Zeile als getestet markiert. Erst Patch-IDs klaeren, dann
  `make import-lab PERIOD=2026-10 LAB_DIR=<nur der CPU26-Report> OS_LABEL="Oracle Linux 9.8"`

Issues 26ai fuer den Report: PDB$SEED nach dem Deploy READ WRITE (17:07:11 RO, 17:07:12 RW) -
wie bei 19c, also AutoUpgrade-Verhalten ueber beide Releases; Basis enthaelt die MRP-Fixes vom
Download-Tag (Gold Image); Deploy laedt das Gold Image ein zweites Mal (ca. 5 GB).

Nicht in B: 19c auf OL9 (Stefan: sollte gehen - heute scheitert das Base-Image 19.3.0 an
OL9, Weg ueber Gold Image/`-applyRU`; eigener Punkt nach dem Zyklus).

### C - WLS/FMW (Sa/So, Rest aus Las Vegas)

- [ ] Installer 14.1.2 und 15.1.1 von eDelivery nach `orarepo` - **Stefan (Lizenz-Login)**
- [ ] Rolle `wls_engineering`: JDK, WLS-Home in der Ausgangsversion (SPB 2026-07), einfache
  Domain mit AdminServer + Managed Server, Smoke (Konsole, Deploy einer Test-App)
- [ ] SPB 2026-10 out-of-place: zweites Home klonen, `spbat`/OPatch, Domain auf das neue
  Home zeigen, Start, Smoke; Laufzeit und Issues wie bei der DB
- [ ] Patches: MOS-Download in `cpu-patch-tests`, Upload nach `orarepo/patches/2026-10/`,
  Host zieht per PAR (Mechanik von heute, generalisiert auf beliebige Ziele)
- [ ] Reihenfolge 14.1.2, 15.1.1, 12.2.1.4, 14.1.1

### D - Infrastruktur und Ablauf (parallel, nur was die Tests braucht)

- [x] Bastion-Tunnel startet zuverlaessig (2026-10-22)
- [x] PAR-Mechanik fuer Patches aus `cpu-patch-tests` (2026-10-22, DB-Rolle)
- [ ] Remote-Robustheit: lange Schritte laufen auf dem Host per `async`; ein abgerissener
  Tunnel darf den Lauf nicht toeten. Pruefen mit einem gewollten Tunnel-Abbruch waehrend
  `create_home`, `cpu-lab-progress` zum Wiederanhaengen. Faellt das durch: Lauf unter
  `nohup` auf dem Host starten, Ansible nur noch zum Einsammeln
- [ ] Kosten: Instanzen nach jedem Lauf stoppen; `enable_auto_stop` bleibt aus (Abbruch
  mitten im Patch). Destroy nach dem Report
- [ ] Abstimmung mit der `cpu-patch-tests`-Session: `data/2026-10.yaml` ist dort
  uncommitted (cycle-start laeuft) - ich schreibe dort nichts ausser per `import-lab`

### Befunde Lab-Rolle (2026-10-23)

- [x] `cpu-lab-verify` taugt nicht als Vorher-Aufnahme: der Smoke-Test laeuft mit
  `oracle_home_target`, bevor die oratab-Assertion greift - `expdp` aus 19.32 gegen die
  DB auf 19.31 hing > 10 min. Fix: oratab-Assertion vor den Smoke ziehen [P2]
- [x] Smoke-Passwort `CPUSMOKE` steht in `ps`: das Parfile hilft nicht, weil das ganze
  Script als Argument von `bash -c` laeuft (`ansible.builtin.shell`). Fix: Script als
  Datei (template, 0700) oder Passwort per stdin [P2]
- [x] Report: Basis-Zeile zeigte `db19_patch_list_base` statt des Basis-Homes, AU-Zeile ein
  rohes Dict, OS-Zeile umbrochen
- Alle drei behoben in `0299329` und `60fa2e5` (Merge `73eb698`), lint gruen, **auf dem
  Host noch nicht gelaufen** - kommt mit dem naechsten Verify

### Ausserhalb des kritischen Pfads

Die zehn Befunde an oradba.automation 0.2.0 / odb_autoupgrade 0.6.1 aus Lauf A
(`plan-cpu-2026-10.md`) betreffen das USZ-Fenster, nicht den Report. Sie gehen als Issues an
die beiden Repos; auf dem Lab-Host bleibt die Engine mit Hotfix liegen, stoert die
Lab-Rolle nicht (eigener Pfad unter `/u00/app/oracle/local`).

## Was Stefan entscheiden oder tun muss

- [ ] tfvars-Aenderungen + `make cpu-lab-apply` fuer A (nur Inventory) und B (neuer Host)
- [ ] WLS-Installer 14.1.2 und 15.1.1 von eDelivery
- [ ] Freigabe der Laufzeitkosten: 19c-Host ca. 0.25 USD/h, 26ai- und WLS-Host je ca. 0.15 USD/h
