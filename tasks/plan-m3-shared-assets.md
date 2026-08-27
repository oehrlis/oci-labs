# M3 - Geteilte Assets (Plan, korrigiert 2026-08-27)

> **Diese Datei wurde neu geschrieben.** Die erste Fassung stellte die halbe
> Planung auf `odb_autoupgrade`. Das Lab benutzt dieses Repo nicht - es laedt
> `autoupgrade.jar` direkt von Oracle und ruft `java -jar autoupgrade.jar`.
> Belegt: kein einziger Verweis auf `odb_autoupgrade` im ganzen Repo ausser in
> meinen eigenen Planungsdokumenten. Der Fehler kam daher, dass Option B in
> Roadmap-Abschnitt 2 dieses Repo nannte.

## 1. Was M3 nach der Korrektur ist

Zwei Gruppen, zwei sehr verschiedene Wege.

<!-- markdownlint-disable MD013 MD060 -->

| Asset | Weg | Wer |
| --- | --- | --- |
| `templates/dbca.rsp.j2` | mittelfristig nach `oradba`, dort liegen schon rsp fuer 19c und 26ai | **oradba-Session**, per Change Request von hier |
| `templates/tnsnames.ora.j2` | mittelfristig nach `oradba/src/templates/sqlnet/` | dito |
| `templates/listener.ora.j2` | mittelfristig nach `oradba/src/templates/sqlnet/` - **kein Gegenstueck**, waechst neu zu | dito |
| `templates/autoupgrade-*.cfg.j2` (4) | **bleiben im Lab** | hier |
| `templates/load_mos_password.exp.j2` | **bleibt im Lab** | hier |
| Patch-Listen-Vokabular in `defaults/main.yml` | **bleibt im Lab** | hier |
| Verifikations-SQL | liegt inline in `verify.yml`/`smoke.yml`, keine Datei | offen, eigene Arbeit |

<!-- markdownlint-restore -->

`odb_autoupgrade` ist gestrichen. Der Entscheid, dessen 15 statische
`download_RU19.*.cfg` zu loeschen, ist damit **gegenstandslos** - er beruhte auf
meiner falschen Annahme. Falls dort aufgeraeumt werden soll, ist das
unabhaengige Hausarbeit in einem Repo, das dieses Lab nicht konsumiert.

## 2. Die Folge, die zaehlt: M4 ist nicht mehr blockiert

Die Roadmap fuehrte M4 (26ai) als "wartet auf M3". Das galt, solange die
dbca-Vorlage aus einer geteilten Quelle kommen sollte. Wenn die
AutoUpgrade-Assets im Lab bleiben und die dbca-Vorlage **temporaer** ebenfalls,
dann braucht 26ai nichts von M3.

`oradba/src/templates/dbca/26ai/` existiert schon - das ist der Grund, den
Change Request trotzdem zu stellen, aber es ist kein Blocker mehr.

## 3. Was von der Duplikation uebrig bleibt

Die AutoUpgrade-Download-Konfiguration existiert weiterhin **zweimal**, und die
zwei widersprechen sich fachlich:

- **Lab**: eine parameterisierte Vorlage, traegt `download_folder`,
  `target_version`, `gold_image=NO`, laedt das Target mit
  `RECOMMENDED:<ru>,JDK`
- **`cpu-patch-tests/patches/au/`**: 5 Dateien pro Periode, absolute Pfade auf
  `/Users/stefan.oehrli/...`, `folder=` statt `download_folder`, kein
  `gold_image`, laedt mit expliziter Liste `RU:19.32,OJVM,OPATCH,DPBP,JDK`

Der Unterschied in der Patch-Liste ist dieselbe Klasse wie die JDK-Abweichung
aus Roadmap-Abschnitt 4b: zwei Auswahlmechanismen, ein Report. **Das gehoert
der Report-Session** - `cpu-patch-tests` wird dort parallel bearbeitet.

## 4. Was hier zu tun ist

1. Change Request an die oradba-Session stellen -
   `tasks/cr-oradba-shared-templates.md`. **Kein Edit in `oradba` von hier.**
2. Die drei Vorlagen bleiben bis dahin im Lab und funktionieren. Kein
   Zeitdruck.
3. Der Patch-Listen-Widerspruch aus Abschnitt 3 an die Report-Session melden.

<!-- EOF -->
