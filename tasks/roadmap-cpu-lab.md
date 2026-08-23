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
| Schritt 3 Reboot-Test | **in Arbeit** - Durchlauf 3 laeuft, Durchlaeufe 1 und 2 waren rot und produktiv |
| oradba | v1.0.1 bis v1.0.4 released, sechs Defekte behoben |
| Gold-Image-Test | vertagt, wie entschieden |
| M0 Doku/Lint/Tag | offen |

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

### E1 - Wie weit soll M0 gehen, bevor wir taggen?

Der Reboot-Test hat mehr aufgedeckt als geplant. Damit stellt sich die Frage,
ob v0.3.0 den heutigen Stand einfriert oder erst die Folgebefunde aufraeumt.

| Option | Vorteil | Nachteil |
| --- | --- | --- |
| **A: Jetzt taggen** mit Doku, Lint und den bereits gefixten Punkten | Definierter Stand ist da, M1 und M2 koennen starten | Vier bekannte oci-labs-Befunde bleiben offen im Tag |
| **B: Befunde zuerst** (siehe Abschnitt 4), dann taggen | Der Tag ist wirklich sauber | Verzoegert alles Weitere um schaetzungsweise einen halben Tag |
| **C: Jetzt taggen, Befunde als v0.3.1** | Schnell und ehrlich, Befunde sind dokumentiert statt versteckt | Zwei Tags in kurzer Folge |

Meine Empfehlung: **C**. Die vier Befunde sind klein und unabhaengig
voneinander, und ein Tag, der den verifizierten Zustand festhaelt, ist mehr
wert als einer, der auf Aufraeumarbeiten wartet.

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
| M0 | v0.3.0 einfrieren: Rollback, Reboot, Doku, Lint, Tag | M | Rollback gruen, Reboot laeuft, Rest offen |
| M1 | JSON zu CSV Konverter in `cpu-patch-tests/tools/` | S | bereit, CSV als Vertrag entschieden |
| M2 | Core als Modul, implizites Bauen mit Besitzregel, tenant-faehig | M | entschieden, nicht begonnen |
| M3 | Geteilte Assets herausloesen | M | **wartet auf E2** |
| M4 | 26ai (P1) | M | wartet auf M3 |
| M5 | MOS-Spike, dann WLS und OUD (P2) | M-L | Spike jederzeit moeglich |
| M6 | Alle-Tests-Prozess und Zeitsteuerung | M | wartet auf M4, M5 |

Zu M2 und M6 ist in der Nacht ein Argument dazugekommen, siehe Befund B4:
die Bastion ist als Transportweg fuer unbeaufsichtigte Laeufe derzeit
untauglich. Das trifft M6 direkt.

## 4. Befunde fuer oci-labs aus der Nacht

Alle vier wurden erst durch den Reboot-Test sichtbar. Keiner ist gefixt ausser
B3.

### B1 - oradba wird nie ins Profil des oracle-Users eingebunden

`/home/oracle/.bash_profile` auf `oradb01` ist die unveraenderte
Oracle-Linux-Vorlage. `su - oracle -c 'echo $ORACLE_HOME $ORACLE_SID
$TNS_ADMIN $ORADBA_BASE'` liefert vier leere Werte.

Ursache: die Rolle ruft den Installer mit `become: true` auf, also als root.
`oradba_install.sh` schreibt seine Profilzeile nach `${HOME}` - und das ist
`/root`. Dein Requirement "muss by default installiert sein, damit man es
interaktiv nutzen kann" ist damit auf dem Lab nicht erfuellt.

Zu klaeren: Installer-Flag, dokumentierter Nachschritt, oder Aufgabe der Rolle.
Steht auch im oradba-Briefing als M1.

### B2 - `rollback.yml` laesst das Lab ohne Autostart zurueck

Es setzt `oratab` auf `:N`, damit waehrend des Flashbacks nichts auf gepatchten
Binaries hochkommt - richtig gedacht - stellt aber nie auf `:Y` zurueck. Nach
einem erfolgreichen Rollback startet die Datenbank bei einem Reboot nicht mehr.

Haette ich das vor dem Reboot nicht bemerkt, waere der Test gruen gewesen, ohne
irgendetwas zu beweisen. Ein falsches Gruen ist schlimmer als ein Rot.

### B3 - Makefile: Tunnel ohne `IdentitiesOnly` (gefixt)

Eine Bastion-Session akzeptiert genau den Schluessel, mit dem sie erzeugt
wurde, und schliesst die Verbindung nach dem ersten falschen. Ohne
`IdentitiesOnly=yes` bietet ssh zuerst jede Identitaet aus dem Agent an. Bei
dir ging es bisher nur, weil dein Agent den Lab-Key an zweiter Stelle anbot.
Das war Glueck, kein Verhalten.

### B4 - Bastion-Sessions sind wackliger als das Makefile annimmt

Zwei Beobachtungen aus einem Abend: eine frisch erstellte Session akzeptiert
SSH erst nach einigen Sekunden, und eine Session war nach drei Minuten im
Zustand `DELETED`, obwohl die TTL auf drei Stunden stand. Mehrere
Ansible-Laeufe brachen mitten in der Arbeit mit `UNREACHABLE` ab.

Die Targets behandeln Session und Tunnel als Einmalvorgang ohne Wiederholung.
**Fuer M6 ist das ein Blocker**: ein naechtlicher, unbeaufsichtigter Lauf ueber
die Bastion wuerde reproduzierbar scheitern, und zwar nicht am Test, sondern am
Transportweg.

### B5 - Der oradba-Rollout kann nicht aktualisieren

Die Rolle prueft nur, ob das Verzeichnis existiert, und ueberspringt dann die
Installation. Ein Upgrade braucht `db19_oradba_force_install=true`, was
nirgends dokumentiert ist. Fuer frische Hosts unkritisch, aber sobald oradba
selbst Teil des Testgegenstands ist - wie in dieser Nacht - ist es eine Falle.

### B6 - `/var/log/oracle` wird beim Rollout nicht angelegt

Weder angelegt noch an `oracle:oinstall` uebergeben. Seit oradba 1.0.1 ist das
nicht mehr fatal, aber die Service-Logs bleiben leer.

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
