# Roadmap: CPU Patch Lab und Lab-Framework

> Stand 2026-08-23, fuer Review am Montagmorgen. Loest `tasks/plan-cpu-lab.md`
> als Steuerdokument ab. Entscheidungen, die ich brauche, stehen in Abschnitt 2
> mit Vor- und Nachteilen. Alles darunter ist Kontext.

## 1. Was seit Freitag passiert ist

Freigegeben war: Schritt 2 (Rollback-Test) und Schritt 3 (Reboot-Test),
nacheinander, ohne Rueckfrage. Gold Image vertagt.

### Ergebnis

| Sache | Stand |
| --- | --- |
| Schritt 2 Rollback-Test | **gruen** - CPUDB 19.31.0.0.0 aus dem Base-Home, 0 invalid Objects, 15 Komponenten |
| Schritt 3 Reboot-Test | **gruen** im dritten Anlauf - 17 s bis die DB offen ist, unbeaufsichtigt |
| oradba | v1.0.1 bis v1.0.4 released, sechs Defekte behoben |
| M0 Doku/Lint/Tag | **abgeschlossen**, `v0.3.0` getaggt und gepusht |
| M1 Report-Konverter | **fertig und gepusht** - Commit `d56b1fe` auf `feat/report-redesign-schema-v5`, nicht auf `main` |
| Befunde B1 bis B6 | **alle behoben**, B2 geschrieben aber noch nicht ausgefuehrt |
| Gold-Image-Test | vertagt, wie entschieden |

`rollback.yml` ist damit nicht mehr ungetestet. Der Flashback auf den
Guaranteed Restore Point, der Home-Wechsel zurueck und die Selbst-Assertion
laufen sauber. Ein `snapshot-rolledback` liegt auf dem Host.

### Der Reboot-Test war die Investition wert

Er hat sechs Defekte in oradba freigelegt, alle vorbestehend in v1.0.0, alle
derselben Klasse: ein bares `${VAR}` unter `set -euo pipefail` bricht das
Skript ab, sobald die Umgebung die Variable nicht kennt. Jede Ebene wurde erst
sichtbar, nachdem die davor gefallen war.

Details und die Requirements-Liste stehen im eigenen Briefing:
`~/Repos/own/oehrlis/oradba/tasks/review-brief-boot-path-2026-08-23.md`

Kurzfassung fuer hier: **die Defekte sind echt, nicht von uns erzeugt.** Was wir
erzeugt haben, ist der Anlass - oradba wurde erstmals in einem Modus benutzt,
den nie jemand ausgeuebt hat: ein unbeaufsichtigter Boot ohne geladenes Profil.

Zwei Fehler gehen auf mein Konto und sind korrigiert: v1.0.1 unterdrueckte das
Log-Rauschen nicht vollstaendig, und v1.0.3 enthielt den Fix nicht, den es
beschrieb - die Aenderung ging zwischen Edit und Commit verloren. Seither
verifiziere ich Tag-Inhalte statt Patch-Ausgaben.

## 2. Entscheidungen, die ich von dir brauche

### E1 - erledigt, keine Entscheidung mehr noetig

Ich hatte drei Varianten vorgelegt und C empfohlen: jetzt taggen, Befunde als
Folgeversion. Es kam anders und besser - die Befunde waren klein genug, um sie
noch vor dem Tag zu erledigen. `v0.3.0` enthaelt sie.

### E2 - Wo leben die geteilten Assets (M3)?

Du hattest gesagt: kommt in oradba, direkt oder per Change Request. Nach der
Nacht sehe ich einen Konflikt, den ich vorlegen will.

oradba ist laut deiner eigenen Definition die **interaktive Toolbox**. Die
Assets, um die es geht - AutoUpgrade-cfg-Vorlagen, Patch-Listen-Vokabular,
MOS-Keystore-Handling, Verifikations-SQL - sind dagegen **Automations-Assets**.
Sie werden von Ansible, von einem Dockerfile und von on-premises-Skripten
konsumiert, nicht von einem Menschen an der Kommandozeile.

| Option | Vorteil | Nachteil |
| --- | --- | --- |
| **A: alles nach oradba** | ein Ort, schon installiert auf jedem Lab-System | vermischt interaktive Toolbox mit Automations-Assets; oradba waechst um Dinge, die interaktiv nie gebraucht werden |
| **B: dbca-rsp und sqlnet nach oradba** (dort schon vorhanden), AutoUpgrade-Assets nach `odb_autoupgrade` | jedes Repo behaelt seinen Zweck; `odb_autoupgrade` ist genau dafuer gebaut | zwei Quellen statt einer, beide muessen auf dem Zielsystem liegen |
| **C: neues schlankes Repo** nur fuer Automations-Assets | sauberste Trennung | ein Repo mehr zu pflegen, und die Verifikations-SQL braucht Oracle-Kontext |

Meine Empfehlung: **B**. `oradba/src/templates/dbca/` enthaelt bereits fertige
rsp fuer 19c und 26ai, die das Lab heute ignoriert - das ist schlicht
Doppelarbeit und gehoert zusammengefuehrt. Die AutoUpgrade-Seite dagegen hat
mit der interaktiven Toolbox nichts zu tun.

### E3 - Braucht oradba einen generellen Review?

Deine Frage. Meine Antwort: **ja, aber gezielt, nicht als Rundumschlag.**

Dafuer spricht: sechs Defekte einer Klasse an einem Abend, sieben Testfehler,
die drei getaggte Releases ueberlebt haben, und ein Release-Workflow, der eine
rote Suite durchlaesst. Das sind Symptome fehlender Gates, nicht Zufall.

Dagegen spricht ein voller Architektur-Review: die Architektur hat sich in
dieser Nacht als **richtig** erwiesen. `oradba_dbctl.sh` laedt `oraenv.sh`
selbst und leitet `ORACLE_HOME` aus `oratab` ab - genau dein Requirement 3.
Kaputt war die Ausfuehrung, nicht der Entwurf.

Vorschlag fuer den Zuschnitt, in dieser Reihenfolge:

1. **Gates** - Release-Workflow bricht bei roter Suite ab, CI ebenso.
2. **Boot-Pfad-Regressionstest** - ein Container, der
   `oradba_services.sh start --force` ohne Profil aufruft. Haette die ganze
   Kaskade in einem Lauf gefunden.
3. **Profil-Verdrahtung** - dein Requirement 2 ist auf dem Lab heute nicht
   erfuellt, siehe Befund B1.
4. **Die sieben Testfehler** triagieren.
5. Erst danach die Asset-Frage aus E2.

### E4 - Gold-Image-Test, jetzt entscheiden oder weiter vertagen?

Du hattest vertagt, bis Schritt 2 und 3 durch sind. Schritt 2 ist durch,
Schritt 3 laeuft.

| Option | Vorteil | Nachteil |
| --- | --- | --- |
| **A: zweite Instanz, `lab_count=2`** | Beweis-Host bleibt, Gate 5 gratis mitgetestet | eine zusaetzliche 8-OCPU-Instanz fuer ca. 30 Minuten |
| **B: aktuellen Host ersetzen** | billiger | Forensik weg, `lab_count>1` bleibt ungetestet |
| **C: weiter vertagen** | nichts kostet etwas | die 2-Minuten-Behauptung fuer den Gold-Image-Install bleibt unbelegt |

Meine Empfehlung weiterhin **A**.

## 3. Milestones

| M | Inhalt | Aufwand | Status |
| --- | --- | --- | --- |
| M0 | v0.3.0 einfrieren: Rollback, Reboot, Doku, Lint, Tag | M | **fertig**, getaggt und gepusht |
| M1 | JSON zu CSV Konverter in `cpu-patch-tests/tools/` | S | **fertig**, gepusht auf `feat/report-redesign-schema-v5`; Merge nach `main` offen |
| M2 | Core als Modul, implizites Bauen mit Besitzregel, tenant-faehig | M | **`envs/core` angewendet** 2026-08-27, kein Drift; Migration von `cpu-patch-test` offen |
| M3 | Geteilte Assets herausloesen | M | **wartet auf E2** |
| M4 | 26ai (P1) | M | wartet auf M3 |
| M5 | MOS-Spike, dann WLS und OUD (P2) | M-L | Spike jederzeit moeglich |
| M6 | Alle-Tests-Prozess und Zeitsteuerung | M | wartet auf M4, M5 |

Zu M2 und M6 ist in der Nacht ein Argument dazugekommen, siehe Befund B4:
die Bastion ist als Transportweg fuer unbeaufsichtigte Laeufe derzeit
untauglich. Das trifft M6 direkt.

## 4. Befunde aus der Nacht - Stand

Alle sechs wurden erst durch den Reboot-Test sichtbar. Alle sind behoben.

| # | Befund | Stand |
| --- | --- | --- |
| B1 | oradba nie im Profil des oracle-Users | **behoben und bewiesen** |
| B2 | `rollback.yml` laesst `oratab` auf `:N` | behoben, **noch nicht ausgefuehrt** |
| B3 | Tunnel ohne `IdentitiesOnly` | behoben |
| B4 | Bastion-Sessions instabil, `UNREACHABLE` mitten im Lauf | **behoben und bewiesen** |
| B5 | Rollout kann nicht aktualisieren | dokumentiert |
| B6 | `/var/log/oracle` fehlt | behoben und bewiesen |

### B1 - jetzt erfuellt

Der Installer verdrahtet ein Profil, schreibt aber nach `${HOME}`, und die Rolle
ruft ihn als root auf. Die Zeile landete in `/root/.bash_profile`, waehrend
`/home/oracle/.bash_profile` die unveraenderte Oracle-Linux-Vorlage blieb. Auf
`oradb01` gemessen, vorher vier leere Werte, jetzt:

```text
ORADBA_BASE=[/u00/app/oracle/local/oradba]
ORACLE_SID=[CPUDB]
ORACLE_HOME=[/u00/app/oracle/product/19.31/dbhome_1]
```

Damit ist dein Requirement 2 - oradba muss auf Lab-Systemen interaktiv nutzbar
sein - erfuellt. **Offene Frage fuer die oradba-Session:** wessen Aufgabe ist
das eigentlich? Die Rolle macht es jetzt explizit, aber ein Installer-Flag
(`--profile-user oracle`) waere der sauberere Ort. Steht im Briefing als M1.

### B2 - behoben, aber unbewiesen

`rollback.yml` stellt `oratab` am Ende wieder auf `:Y`. Ausfuehren konnte ich es
nicht: dafuer braucht es einen Guaranteed Restore Point, und den gibt es erst
nach einem erneuten Patch-Lauf. Der wiederum braucht MOS-Zugangsdaten aus
1Password, und `op` ist in einer nicht-interaktiven Sitzung nicht angemeldet.

Damit steht B2 genau dort, wo `rollback.yml` vor dem Wochenende stand:
sorgfaeltig geschrieben, nie ausgefuehrt. Das ist bewusst so benannt.

### B4 - der eigentliche Blocker fuer M6

Ein lauschender lokaler Port ist kein Beweis fuer einen nutzbaren Tunnel. Die
Bastion verwirft Sessions ohne Vorwarnung - eine war drei Minuten nach dem
Start im Zustand `DELETED`, bei drei Stunden TTL - und ssh haelt den lokalen
Listener, waehrend die Gegenseite weg ist. `nc` meldet Erfolg, der naechste
Ansible-Lauf stirbt an `UNREACHABLE`. Das ist mir an einem Abend dreimal
passiert.

Jede Pruefung fuehrt jetzt ein echtes Kommando auf dem Host aus, der Tunnel
wiederholt und legt bei Bedarf eine neue Session an, und ssh-Keepalives sind
aktiv. Dazu `BASTION=1`, das Host und Port setzt und den Tunnel zur
Vorbedingung macht:

```bash
make cpu-lab-step TAG=oradba BASTION=1
```

Ohne diesen Fix waere jeder naechtliche Lauf aus M6 reproduzierbar
gescheitert - nicht am Test, sondern am Transportweg.

## 4b. Neue Befunde aus M1

Zwei Dinge, die erst der Konverter sichtbar gemacht hat. Beide betreffen
`cpu-patch-tests`, nicht dieses Repo.

### Die Ergebnismatrix wurde nie automatisch gefuellt

`import_test_results.py` bildet das Produkt `db` auf den Familientoken
`oracle database` ab. Jede Periode seit 2025-04 beschriftet ihre Matrix-Zeilen
aber mit `RDBMS 19.0.0.0`. Es hat also nie gepasst. Der Importer sagte das bei
jedem Lauf - `no oracle database matrix row for version ... - left as is` - und
niemand hat es gelesen, weil die Matrix von Hand gepflegt wurde.

Behoben und durch Vergleich belegt: mit Fix
`matrix 'RDBMS 19.0.0.0'.lnx: empty -> ok`, ohne Fix die alte Meldung.

### Lab und Periodendaten testen nicht dasselbe

Der Konverter gleicht jetzt beide Richtungen ab und meldet sie:

```text
period data lists 39329591 (Oracle JDK) - not in the lab home
lab home carries 39791916 - no row in the period data
lab home carries 39657094 - no row in the period data
```

Combo-Patches, GI RU und Windows Bundle fehlen zu Recht - das Lab ist eine
Single-Instance auf Linux. Aber der JDK-Patch weicht ab, und den DPBP `39657094`
testet das Lab, ohne dass der Report ihn fuehrt. **Zu klaeren:** ist die
Periodendatei veraltet, oder testet das Lab die falsche Patch-Liste?

## 4c. Was ich am Montag zuerst von dir brauche

In dieser Reihenfolge, weil das eine das andere blockiert.

1. **`eval $(op signin)`** - danach kann ich den Patch-Lauf fahren, der den
   B2-Fix beweist und das Lab wieder in den getesteten Zielzustand bringt.
2. **E2 entscheiden** - wo die geteilten Assets leben. Blockiert M3 und damit
   M4 (26ai).
3. **Den JDK-Unterschied klaeren** - Periodendaten sagen 39329591, das Lab
   installiert 39791916. Eines von beiden ist falsch.
4. **`cpu-patch-tests` pushen oder nicht** - dort liegt mein M1-Commit lokal,
   neben deinen unfertigen Aenderungen an `VERSION` und `data/2026-07.yaml`,
   die ich nicht angefasst habe.

## 5. Offene Punkte aus dem alten Stand

- `INJECT_FACTS_AS_VARS` Deprecation - die Rolle nutzt `ansible_date_time` und
  Verwandte durchgaengig als Top-Level-Variablen. Mechanisch, rollenweit.
- Lint-Schulden: 7 ansible-lint-Findings, 14 fehlerhafte markdownlint-Marker in
  `docs/` und `terraform/modules/iam_mfa_oma/README.md`.
- Konsument des Report-JSON weiter unbeantwortet - solange niemand es liest,
  ist das Schema billig zu aendern. M1 beantwortet das.
- `assign_public_ip = false` als Default, gehoert zu M2.
- Die PAR-Frist ist **kein** Termindruck. Es existieren zwei PARs, und ein
  neues Minten ist ein einzelner Make-Aufruf. Das hatte ich aus dem alten
  State-Dokument uebernommen, ohne es zu pruefen.

## 6. Bewusst nicht im Plan

- In-place-Patching per opatchauto. Out-of-place ist der Fokus und laut Oracle
  Best Practice.
- Verifikationstiefe ueber den heutigen Stand hinaus. Der Report konsumiert
  `result` aus drei Werten und `product_state` aus vier.
- Replikation der Gold Images ueber Tenants hinweg. Neu bauen kostet 20 Minuten
  und ist billiger als jede Replikationsmechanik.
- Konsolidierung des AutoUpgrade-**Aufrufs**. Eine Zeile, keine Abstraktion
  wert. Geteilt gehoeren die Daten, nicht die Aufrufschicht.

<!-- EOF -->
