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

- [ ] Baseline 19.32 herstellen: CPUDB per Lab-Rolle auf das vorhandene Home
  `product/19.32/dbhome_1` (August-Referenzlauf), tfvars `db_base_ru = "19.32"`.
  Frischer AutoUpgrade-Log-Pfad (offener August-Job)
- [ ] `db_target_ru = "19.33"`, `make cpu-lab-plan` (erwartet nur Inventory) -
  **apply durch Stefan**
- [ ] `make cpu-lab-patch` (MOS auf dem Host), `cpu-lab-verify`, `cpu-lab-rollback`
- [ ] Ergebnis nach `cpu-patch-tests`: `make import-lab`, Notes je Zeile

### B - DB 26ai: 23.26.3 -> 23.26.4 (Fr/Sa)

- [ ] Zweiter Host im Stack `cpu-patch-test` (OL9, 4 OCPU / 32 GB) - **plan/apply durch Stefan**
- [ ] 26ai-Home 23.26.3 + CDB/PDB ueber `oracle_db_native` (Gold Image von MOS)
- [ ] Patch auf 23.26.4 out-of-place mit derselben Messung wie A, Rollback
- [ ] Import nach `cpu-patch-tests`

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

### Ausserhalb des kritischen Pfads

Die zehn Befunde an oradba.automation 0.2.0 / odb_autoupgrade 0.6.1 aus Lauf A
(`plan-cpu-2026-10.md`) betreffen das USZ-Fenster, nicht den Report. Sie gehen als Issues an
die beiden Repos; auf dem Lab-Host bleibt die Engine mit Hotfix liegen, stoert die
Lab-Rolle nicht (eigener Pfad unter `/u00/app/oracle/local`).

## Was Stefan entscheiden oder tun muss

- [ ] tfvars-Aenderungen + `make cpu-lab-apply` fuer A (nur Inventory) und B (neuer Host)
- [ ] WLS-Installer 14.1.2 und 15.1.1 von eDelivery
- [ ] Freigabe der Laufzeitkosten: 19c-Host ca. 0.25 USD/h, 26ai- und WLS-Host je ca. 0.15 USD/h
