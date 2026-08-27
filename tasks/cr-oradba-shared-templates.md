# Change Request an oradba - drei Vorlagen aufnehmen

> Von der oci-labs-Session, 2026-08-27. **Kein Edit in `oradba` von hier** -
> dort arbeitet eine eigene Session, aktuell mit 21 geaenderten Dateien auf
> `fix/boot-path-gates`. Dieser Text ist als Prompt fuer diese Session gedacht.

## Worum es geht

Das CPU-Patch-Lab in `oci-labs` fuehrt drei Vorlagen, die inhaltlich nach
`oradba` gehoeren, weil oradba auf jedem Lab-System ohnehin installiert ist und
zwei der drei Ziele dort bereits existieren. Heute sind es Jinja-Vorlagen der
Ansible-Rolle `db19_engineering`.

<!-- markdownlint-disable MD013 MD060 -->

| Quelle in oci-labs | Ziel in oradba | Status des Ziels |
| --- | --- | --- |
| `ansible/roles/db19_engineering/templates/dbca.rsp.j2` | `src/templates/dbca/19c/`, `src/templates/dbca/26ai/` | **existiert** - dort liegen fertige rsp, die das Lab heute ignoriert |
| `ansible/roles/db19_engineering/templates/tnsnames.ora.j2` | `src/templates/sqlnet/tnsnames.ora.template` | **existiert** |
| `ansible/roles/db19_engineering/templates/listener.ora.j2` | `src/templates/sqlnet/` | **kein Gegenstueck** - waechst neu zu |

<!-- markdownlint-restore -->

## Warum es nicht dringend ist

Die drei funktionieren im Lab. Es gibt keinen Blocker dahinter: M4 (26ai) wartet
nach der Korrektur vom 2026-08-27 **nicht** mehr auf diese Zusammenfuehrung.
Der Grund es trotzdem zu tun ist schlicht Doppelarbeit - `oradba` fuehrt fertige
dbca-rsp fuer 19c und 26ai, und das Lab baut sich daneben eigene.

## Was ich von der oradba-Session brauche

1. **Entscheid zur Form.** Die Lab-Vorlagen sind Jinja (`{{ var }}`). oradba
   liefert Templates heute als statische Dateien mit Platzhaltern aus. Welche
   Form soll die zusammengefuehrte Fassung haben - und wie parametrisiert ein
   Konsument sie? Solange das offen ist, kann das Lab nicht umstellen.
2. **Entscheid zum Transportweg.** Fuer geteilte Assets wurde am 2026-08-27
   "Release-Tarball" entschieden. Fuer `oradba` ist **unbestaetigt**, ob der
   Release-Workflow Assets ausliefert - genau `Makefile` und
   `.github/workflows/release.yml` liegen auf `fix/boot-path-gates` in Arbeit.
   Bitte nach dem Landen dieses Branches beantworten: haengt ein oradba-Release
   ein Archiv mit `src/templates/` an, mit Checksumme?
3. **Aufnahme oder Ablehnung.** Wenn die rsp in oradba fachlich besser sind als
   die des Labs, sagt das - dann wirft das Lab seine weg und konsumiert. Das
   waere das beste Ergebnis.

## Kontext, den ihr nicht raten muesst

- Die Lab-Vorlagen entstanden fuer eine Single-Instance auf Oracle Linux,
  Out-of-place-Patching, 19c mit Zielrichtung 26ai.
- Zum `listener.ora` gehoert ein Befund aus dem Reboot-Test (B1 bis B6 in
  `oci-labs/tasks/roadmap-cpu-lab.md`): die Datenbank registrierte sich nach
  einem Home-Wechsel nicht wieder beim Listener. Wer die Vorlage aufnimmt,
  sollte diesen Fall kennen.
- Das Briefing zum Boot-Pfad liegt bei euch:
  `oradba/tasks/review-brief-boot-path-2026-08-23.md`.

<!-- EOF -->
