# M3 - Geteilte Assets herausloesen (Plan, Entscheid E2 = B)

> Stand 2026-08-27. Bestandsaufnahme abgeschlossen, **noch nichts verschoben.**
> Braucht Freigabe, weil drei Repos betroffen sind und `cpu-patch-tests`
> parallel bearbeitet wird.

## 1. Der Befund, der M3 umdreht

E2 war die Frage "wohin gehoeren die Assets". Die Bestandsaufnahme zeigt ein
groesseres Problem: die AutoUpgrade-Download-Konfiguration existiert **dreimal**,
in drei Verfallsstadien, und die drei widersprechen sich fachlich.

<!-- markdownlint-disable MD013 MD060 -->

| Ort | Form | Zustand |
| --- | --- | --- |
| `oci-labs` `templates/autoupgrade-download.cfg.j2` | eine parameterisierte Vorlage | aktuell, traegt `download_folder`, `target_version`, `gold_image=NO` |
| `odb_autoupgrade/etc/download_RU19.*.cfg` | 15 statische Dateien, eine pro RU | **endet bei 19.29**, zwei Quartale hinterher; kein `download_folder`, kein `target_version`, kein `gold_image=NO` |
| `cpu-patch-tests/patches/au/au_2026-07_19*.cfg` | 5 statische Dateien pro Periode | absolute Pfade auf `/Users/stefan.oehrli/...`, `folder=` statt `download_folder`, kein `gold_image=NO` |

<!-- markdownlint-restore -->

Zwei Konsequenzen, die schwerer wiegen als die Doppelarbeit:

1. **Die beiden statischen Saetze wuerden gegen AutoUpgrade 26.5 mit
   `target_version=19` scheitern.** Ohne `gold_image=NO` laeuft die Aufloesung
   ueber den Oracle Update Advisor, und der antwortet HTTP 500. Das Lab weiss
   das und schreibt es in den Vorlagenkopf; die anderen zwei nicht.
2. **Sie testen nicht dasselbe.** `cpu-patch-tests` laedt mit der expliziten
   Liste `RU:19.32,OJVM,OPATCH,DPBP,JDK`, das Lab mit
   `RECOMMENDED:19.32,JDK`. Das ist dieselbe Klasse wie die JDK-Abweichung aus
   Abschnitt 4b der Roadmap: zwei Auswahlmechanismen, ein Report.

## 2. Was wohin geht

Entscheid E2 = **B**.

### Nach `oradba` (interaktive Toolbox, hat die Ziele schon)

| Lab-Asset | Ziel in oradba | Anmerkung |
| --- | --- | --- |
| `templates/dbca.rsp.j2` | `src/templates/dbca/19c/`, `26ai/` | oradba fuehrt dort bereits fertige rsp - zusammenfuehren, nicht daneben legen |
| `templates/tnsnames.ora.j2` | `src/templates/sqlnet/tnsnames.ora.template` | Ziel existiert |
| `templates/listener.ora.j2` | `src/templates/sqlnet/` | **kein Gegenstueck** - waechst neu zu |

### Nach `odb_autoupgrade` (Automations-Assets)

| Lab-Asset | Ziel | Anmerkung |
| --- | --- | --- |
| `templates/autoupgrade-*.cfg.j2` (4) | `etc/` als Vorlagen | **ersetzt** die 15 statischen `download_RU19.*.cfg` - ein Quartal wird eine Variable, keine Datei |
| Patch-Listen-Vokabular (`db19_patch_list_base`/`_target`) | `lib/` oder `etc/` | die Semantik "explizit fuer Base, RECOMMENDED fuer Target" ist der eigentliche Wert |
| `templates/load_mos_password.exp.j2` | zu `bin/create_mos_keystore.sh` | dort existiert bereits MOS-Keystore-Handling - Overlap zuerst pruefen |

### Bleibt im Lab

`cputest-report.md.j2` und `oradba-services.service.j2` sind lab-spezifisch.
Die Verifikations-SQL liegt heute **inline** in `verify.yml` und `smoke.yml`,
nicht als Datei - sie muesste erst extrahiert werden. Das ist eigene Arbeit und
gehoert nicht in denselben Schritt.

## 3. Reihenfolge

1. `odb_autoupgrade`: Vorlagen aufnehmen, die 15 statischen cfg ausser Dienst
   stellen, `gold_image=NO` und `download_folder` als Kenntnis mitnehmen. Das
   ist der Schritt mit dem messbaren Gewinn.
2. `oradba`: dbca-rsp und sqlnet zusammenfuehren.
3. `oci-labs`: die Rolle konsumiert beide Quellen statt eigener Vorlagen.
4. `cpu-patch-tests`: die 5 Perioden-cfg auf die geteilte Quelle umstellen -
   **zuletzt**, und nur abgestimmt, weil dort parallel gearbeitet wird.

## 4. Was zu entscheiden bleibt

- **Wie kommen die Assets auf das Zielsystem?** Zwei Quellen statt einer war
  der bewusst akzeptierte Preis von B - aber der Weg (Git-Clone der Rolle,
  Submodul, Paket) ist offen. Das ist die eigentliche offene Frage von M3.
- **Duerfen die 15 statischen `download_RU19.*.cfg` weg?** Sie sind
  moeglicherweise dokumentarisch wertvoll, auch wenn sie nicht mehr laufen.

<!-- EOF -->
