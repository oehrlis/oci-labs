# Plan: Lab fuer CPU 2026-10 und oradba.automation v0.2.0

> Stand 2026-10-22 abends. Lauf A durch bis `rollback home` - mit Engine-Hotfix und
> Workarounds, 10 Befunde unten. Lauf B nicht gestartet. Instanz STOPPED. Kein apply.

## Stand 2026-10-22

- `origin/main` nach `feat/cpu-lab` gemergt (Konflikt nur CHANGELOG). `terraform plan`
  vorher und nachher: **0 to add, 0 to change, 0 to destroy** - nachher nur der
  `moved`-Block von `egress_https_only` und der bekannte Output
- Patch-Quelle entschieden: **MOS auf dem Host bleibt primaer**, RECOMMENDED bleibt.
  PAR-Fallback gebaut (`make cpu-lab-patch-par PATCH_PREFIX=...`, Runbook "Fallback -
  target RU from the bucket"). Live geprueft: Listing nur im Praefix, Download vom
  Host, Objekt ausserhalb HTTP 401. Nicht geprueft: AU mit `download=no` + RECOMMENDED
- `cpu-lab-bastion-tunnel` scheiterte 3x ("Permission denied (publickey)" auf einer
  frischen Session) - behoben, erster Versuch klappt jetzt. Wichtig fuer remote
- `cpu-lab-par-revoke` hat zwei noch gueltige Base-Image-PARs vom August widerrufen
- Baseline-Abweichungen auf CPUDB: **GRP `AU_PATCHING_9212_CPUDB1931000` vom
  2026-08-21** (2.6 GB, FRA 7.5/20 GB) - belegt den offenen August-Deploy-Job, Lauf B
  daher zwingend mit eigenem Log-Pfad. **PDB1 war MOUNTED ohne Saved State** - geoeffnet
  und `save state` gesetzt
- Neu: AU 26.6 laedt ein **19c Gold Image** von MOS (`db_goldimage_19_32_*.zip`, 5 GB).
  Der Update-Advisor-500 vom August ist damit vermutlich weg -
  `db19_try_gold_image` in der Lab-Rolle neu bewerten
- Auf dem Host liegt: Collection-Engine 0.6.1 + Keystore, neues Home
  `/u00/app/oracle/product/19.32.0.0` (RU 19.32 + OJVM + DPBP + JDK + OCW + MRP-Fixes,
  OPatch 54, im Inventory, mit `uniaud_on` nachgelinkt), Engine mit Lab-Hotfix
  (`lib/au_env.sh`, Original `lib/au_env.sh.orig-0.6.1`). Der August-GRP ist gedroppt
  (Stefan, 2026-10-22). DB nach `rollback home` auf 19.31, kein GRP

### Lauf A - Befunde an oradba.automation 0.2.0 / odb_autoupgrade 0.6.1

Alle mit Verbindungsuser `opc` + sudo, so wie beim Kunden ueblich. Molecule laeuft als
root mit dry-run und sieht keinen davon.

<!-- markdownlint-disable MD013 MD060 -->
| # | Wo | Befund | Workaround im Lab |
| --- | --- | --- | --- |
| 1 | Collection | 24 stat/slurp/find-Tasks ohne `become` - scheitern an `keystore/` (0700), `patches/`, `logs/` (0750) | `-e ansible_become=true` |
| 2 | Engine | `au_render_cfg` wirft `global.keystore` weg, wenn nicht `-mode download` - `au_keystore.sh --create` (`-load_password`) kann nie gehen | Keystore direkt mit AU angelegt |
| 3 | Engine | Expect-Dialog sendet `exit` statt `save` - AU scheitert in `getAutoLoginOption` mit EIO (auch mit 26.5). Die Lab-Rolle macht `save` zuerst, das geht | wie Lab-Rolle |
| 4 | Engine | `au_patch_verify.sh` verlangt `bug-map.json` - AU 26.5/26.6 schreibt keine (auf dem ganzen Host keine) | `patch_download_verify=false`, `autoupgrade_preflight_verify_folder=false` |
| 5 | Collection | `target_home.yml` erwartet `releaseUpdate` 4-stellig, AU 26.6 schreibt `19.32`. Dazu: `oracle_home_create_target_home` erbt `oradba_patch_target_home` nicht | beide Variablen explizit |
| 6 | Engine | `au_home_verify.sh` zaehlt OPatch (6880880) zur Patch-Liste - immer FAIL | `oracle_home_create_verify=false`, `autoupgrade_preflight_verify_home=false` |
| 7 | Engine | analyze/deploy ohne `global.keystore` (siehe 2) und ohne `patch1.download` - mit `gold_image=YES` aus dem Profil oder `MRP`/`OPATCH` in der Liste: "Download query failed". **Blockiert den Deploy** | Lab-Hotfix in `lib/au_env.sh` (Stefan freigegeben): Keystore fuer alle Modi ausser `create_home`. `AU_GOLD_IMAGE=NO` ist falsch - ohne Base Image im Ordner braucht es das Gold Image |
| 8 | Collection | `oracle_home_create` gibt kein Source-Home mit - die Binary Options werden nicht uebernommen. 19.31 mit `uniaud_on`, Gold-Image-Home ohne: analyze lehnt ab | `make -f ins_rdbms.mk uniaud_on ioracle` im neuen Home |
| 9 | Collection | Ein explizites `source_home` in `oradba_patch_databases` wird fuer **jedes** State-Lesen genommen, auch nach dem Switch - die DB wirkt DOWN. Folge: Primary-Play nach erfolgreichem Switch rot, zweites `apply` rot mit irrefuehrender Meldung | `source_home` weglassen - der Switch Record reicht fuer den Rollback |
| 10 | Collection | Der Deploy behaelt keinen GRP (AU-Default `drop_grp_after_patching`). `restore` nimmt den neuesten GRP **irgendeiner** Herkunft - hier waere es der vom August gewesen. Datenverlust-Risiko | August-GRP gedroppt, `restore` bricht dann sauber ab (`changed=0`) |
<!-- markdownlint-restore -->

Ergebnis gegen die Pass-Kriterien (Runbook):

<!-- markdownlint-disable MD013 MD060 -->
| Schritt | Ergebnis |
| --- | --- |
| `setup` | gruen ab dem zweiten Lauf, idempotent (`changed=0`) - nur mit Befund 1-3 |
| `download` | gruen mit `patch_download_verify=false` (Befund 4), MOS inkl. 19c Gold Image |
| `home` | Home korrekt, Verify rot (Befund 5, 6), Binary Options falsch (Befund 8) |
| `apply` | **Switch korrekt**: oratab 19.32, Listener aus dem neuen Home, datapatch CDB + PDB1, 0 invalid, Switch Record. Play danach rot (Befund 9). PDB$SEED stand danach READ WRITE |
| `rollback restore` | nicht testbar - kein GRP (Befund 10) |
| zweites `apply` | ohne `source_home` gruen, klar: "already runs from ... - switch skips it" |
| `rollback home` | **gruen**: oratab `19.31/dbhome_1:Y`, 19.31, RU 19.32 ROLLBACK in CDB und PDB1, 0 invalid, Listener alt, PDB$SEED READ ONLY |
<!-- markdownlint-restore -->

Fuer die USZ heisst das: Switch und `rollback home` funktionieren, aber nur mit dem
Engine-Hotfix (7) und mehreren Variablen-Workarounds. `restore` ist mit 0.2.0 nicht
nutzbar. Fixe gehoeren in odb_autoupgrade 0.6.2 (2, 3, 4, 6, 7) und oradba.automation 0.2.1
(1, 5, 8, 9, 10).

## Zweck

1. **Lauf A - oradba.automation v0.2.0** gegen eine echte DB, vor dem
   USZ-Fenster (due 2026-10-27). Quelle: `odb_autoupgrade/tasks/state-2026-10-14.md`,
   P1 "Lab test oradba.automation v0.2.0".
2. **Lauf B - CPU 2026-10**, Release Di 2026-10-20, RU 19.33. Quelle:
   `cpu-patch-tests/tasks/state-2026-10-12.md`, P1 "Cycle 2026-10".

## plan-cpu-lab.md - Gate-Stand

`tasks/plan-cpu-lab.md` ist seit 2026-08-23 durch `tasks/roadmap-cpu-lab.md`
abgeloest. Die Gates sind gebaut, hier nur der Abgleich:

<!-- markdownlint-disable MD013 MD060 -->
| Gate | Inhalt | Stand |
| --- | --- | --- |
| 1 | Terraform VCN + Compute OL8 | fertig, Stack laeuft seit 2026-08-21 (STOPPED). Heute: Plan wollte die Instanz **ersetzen** - behoben, siehe unten |
| 2 | Ansible 19c-Install | fertig, `db19_engineering` |
| 3 | AutoUpgrade Base -> Target out-of-place | fertig, Referenzlauf 19.31 -> 19.32 am 2026-08-21 |
| 4 | Make-Workflow + Runbook | fertig, `make cpu-lab-*`, `docs/runbook-cpu-patch-lab.md` |
| 5 | `lab_count` + Doku | Doku fertig; `lab_count > 1` weiter **ungetestet** (E4 offen) |
| 6+ | Docker, RM-Stack, 26ai | nicht Teil dieses Laufs |
<!-- markdownlint-restore -->

## Heute gefunden und behoben

- **`terraform plan` haette die DB-Instanz ersetzt.** `~/.ssh/id_ed25519.pub`
  ist seit dem Dotfiles-Umbau ein anderer Key (`stefan.oehrli@accenture.com`
  statt `M4 2026-06`). `metadata.ssh_authorized_keys` erzwingt eine Ersetzung,
  obwohl cloud-init den Wert nur beim ersten Boot liest. Fix in
  `modules/oracle_db_host`: `ignore_changes` auf diesen Schluessel. Plan danach:
  **keine Infrastruktur-Aenderung**, nur der Output `ssh_authorized_key_comments`.
  Folge: der neue Workstation-Key ist auf dem Host **nicht** autorisiert - Ansible
  und Tunnel nutzen ohnehin den Lab-Key `.ssh/cpu-lab`.
- **`BASTION=1` plus `ANSIBLE_EXTRA="..."` verlor den Tunnel still.** Ein
  `ANSIBLE_EXTRA` auf der Kommandozeile ersetzte das Make-interne `+=`, Ansible
  ging an die Public IP. Fix: `override`. Lauf B braucht genau diese Kombination.

## Neu gebaut

- `ansible/playbooks/lab-oradba-automation.yml` - duennes Szenario, importiert
  die Collection-Playbooks, je Schritt ein Tag, Rollback nur per Tag
- `ansible/inventories/cpu-patch-test/` - Gruppendeklaration + `group_vars` mit
  den Collection-Variablen (Engine 0.6.1 per sha256, Profil
  `2026-09_db19_linux` aus `cpu-patch-tests`, `CPUDB`, `LISTENER`)
- `make cpu-lab-coll-install | -check | cpu-lab-coll STEP=... |
  cpu-lab-coll-rollback MODE=...`
- `docs/runbook-oradba-automation-lab.md`

Offline verifiziert: Collection-Tarball sha256 ok, `--syntax-check`, `--list-tasks`
je Tag (jeder STEP waehlt genau seine Plays, Rollback nur mit Tag),
Variablen-Aufloesung inkl. Profil-Datei, `make lint` gruen. **Nicht verifiziert:**
alles auf dem Host - dafuer muss die Instanz laufen.

## Reihenfolge

Lauf A zuerst: er braucht den neuen RU nicht, und Befunde an der Collection
haben dann bis zum 27.10. Zeit fuer einen Fix-Release.

### Lauf A - Collection, ab sofort moeglich

```bash
eval $(op signin)
make cpu-lab-start
make cpu-lab-coll-install && make cpu-lab-coll-check
make cpu-lab-coll STEP=verify BASTION=1      # Baseline: 19.31, kein Restore Point, df
make cpu-lab-coll STEP=setup BASTION=1
make cpu-lab-coll STEP=download BASTION=1
make cpu-lab-coll STEP=home BASTION=1
make cpu-lab-coll STEP=apply BASTION=1
make cpu-lab-coll-rollback MODE=restore BASTION=1
make cpu-lab-coll STEP=apply BASTION=1
make cpu-lab-coll-rollback MODE=home BASTION=1
make cpu-lab-stop
```

Endzustand: CPUDB wieder auf 19.31 aus dem Lab-Base-Home. Restore Point danach
von Hand droppen (SQL im Runbook). Pass-Kriterien: Runbook-Tabelle.

### Lauf B - CPU 19.33, ab 2026-10-20

Voraussetzung in `cpu-patch-tests` (dort, nicht hier): `make cycle-start
PERIOD=2026-10`.

```bash
# terraform.tfvars: db_target_ru = "19.33" (db_base_ru bleibt 19.31)
make cpu-lab-plan          # erwartet: nur local_file.ansible_inventory
make cpu-lab-apply         # Stefan - aendert keine OCI-Ressource, nur die Inventory
make cpu-lab-start
make cpu-lab-patch BASTION=1 ANSIBLE_EXTRA="-e db19_autoupgrade_log_dir=/u00/app/oracle/cfgtoollogs/autoupgrade-2026-10"
make cpu-lab-verify BASTION=1
make cpu-lab-rollback BASTION=1     # beweist endlich B2 (oratab zurueck auf :Y)
make cpu-lab-stop
```

- **Base 19.31 statt 19.32.** Die DB steht auf 19.31, das Base-Home ist mit der
  expliziten Liste gebaut (Kontrollgruppe). 19.31 laesst sich nach dem 20.10.
  nicht mehr herunterladen, muss es aber nicht - das Home liegt schon da. Ein
  Sprung ueber zwei RUs ist fuer den Report unschaedlich, er testet das Target.
- **Eigener Log-Pfad.** Ob im Lab-Log-Pfad noch ein offener Deploy-Job vom
  August liegt, ist unbelegt. Liegt einer, wuerde `analyze` ihn tolerieren und
  `deploy` den **alten** 19.32-Job fortsetzen. Ein frischer Log-Pfad schliesst das
  aus. Dank des `override`-Fixes geht der Tunnel dabei nicht verloren.
- Danach in `cpu-patch-tests`: `make import-lab`, `make au-profiles PERIOD=2026-10`.

## Tenant

**Empfehlung: im Accenture-Tenant bleiben** (Profil `TRIVADIS`, wo der Stack
heute steht).

- Dort liegen Instanz, DB, Base-Home 19.31, Home 19.32 und der `orarepo`-Bucket
  mit Base-Image und Gold Image. Ein Umzug in den eigenen Tenant heisst
  Neubau: ca. 1.5 h Instanzzeit fuer Install + DB, bezahlt aus den knappen
  eigenen Credits, plus Base-Image-Upload
- Die Accenture-Standards sind erzwungen: PV-Encryption in transit, IMDSv2,
  Flow Logs auf allen Subnetzen, Bastion
- **Restrisiko Monitoring:** `assign_public_ip = true` steht noch in
  `terraform.tfvars` (der Code-Default ist seit August `false`). Eine Public IP
  mit SSH-NSG ist der wahrscheinlichste Incident-Ausloeser. Umstellen erzwingt
  eine Ersetzung der Instanz - also **nicht jetzt**, sondern beim naechsten
  Neubau. Alle Make-Ziele laufen mit `BASTION=1` ohnehin ueber die Bastion

Wenn die Incidents in den letzten Wochen von **dieser** Instanz kamen, kippt die
Abwaegung - dann Lauf A und B im eigenen Tenant als Neubau. Das weiss nur Stefan.

## Kosten pro Lauf

OCI-Listenpreise in USD, Stand meiner Kenntnis, **heute nicht gegen die
Preisliste geprueft**: E4.Flex 0.025 pro OCPU-Stunde, 0.0015 pro GB-Stunde RAM,
Block Volume 0.0255 pro GB-Monat plus 10 VPU Balanced (0.0017 pro VPU-GB-Monat).
Bastion, VCN, NAT und IGW kosten nichts; Logging bleibt im Freikontingent.

<!-- markdownlint-disable MD013 MD060 -->
| Posten | Rechnung | Betrag |
| --- | --- | --- |
| Instanz laufend, 8 OCPU / 32 GB | 8 x 0.025 + 32 x 0.0015 | ca. 0.25 pro Stunde |
| Boot Volume 200 GB, auch gestoppt | 200 x (0.0255 + 0.017) | ca. 8.50 pro Monat, 0.28 pro Tag |
| Lauf A, ca. 3 h inkl. zweitem Apply | 3 x 0.25 | ca. 0.75 |
| Lauf B, ca. 1.5 h inkl. Rollback | 1.5 x 0.25 | ca. 0.40 |
| Parken bis 2026-10-27, 12 Tage | 12 x 0.28 | ca. 3.40 |
| **Summe bis zum USZ-Fenster** | | **ca. 5** |
<!-- markdownlint-restore -->

Die Rechenzeit ist nicht der Kostentreiber. Das Boot Volume ist es: der Stack
steht seit dem 2026-08-28 gestoppt, das waren bisher ca. 14. Der groesste Hebel
ist also ein Destroy nach Lauf B, nicht weniger OCPUs.

## Teardown

1. Parken zwischen den Laeufen: `make cpu-lab-stop`. Kostet nur das Boot Volume
2. Nach Lauf B Beweise sichern: Report und Snapshots liegen nach `cpu-lab-verify`
   unter `ansible/reports/`; `make cpu-lab-goldimage-push` nur, wenn das 19.33-Home
   mit `db19_gold_image_create=true` gebaut wurde
3. `make cpu-lab-par-revoke` - PARs auf dem Base-Image-Bucket widerrufen
4. `make cpu-lab-destroy` - fragt nach `destroy`. Entfernt Instanz, Boot Volume,
   VCN, Bastion und Flow Logs des Stacks. Der Core-Stack (`envs/core`,
   `core_owner = "core"`) und der `orarepo`-Bucket liegen nicht in diesem State
   und bleiben
5. Pruefen: `terraform -chdir=terraform/envs/cpu-patch-test state list` leer,
   `oci --profile TRIVADIS compute instance list --compartment-id <ocid>`
   ohne `ci-chzh-l-cpupt-01-*` (ausser im Zustand TERMINATED)

Mit dem Destroy sind die 19.31/19.32-Homes und die DB weg. Ein naechster
Zyklus baut neu (Base-Image aus `orarepo`, ca. 1.5 h) - dann mit
`assign_public_ip = false`, und E4 (`lab_count = 2`) kann gleich mitlaufen.

## Offen fuer Stefan

- [ ] Tenant bestaetigen (Empfehlung: Accenture; Lauf A lief dort, ausdruecklich bestaetigt ist es nicht)
- [x] Lauf A freigeben - gefahren 2026-10-22 bis `rollback home`
- [ ] Befunde 1-10 an oradba-ansible / odb_autoupgrade geben, vor dem USZ-Fenster
  2026-10-27 entscheiden: Fix-Release oder USZ mit Workarounds [P1]
- [ ] Ab 2026-10-20: `db_target_ru = "19.33"`, `make cpu-lab-apply` (nur Inventory) -
  dann Lauf B wie oben, MOS auf dem Host [P1]
- [ ] Nach Lauf B: Destroy oder bis zum naechsten Zyklus parken
