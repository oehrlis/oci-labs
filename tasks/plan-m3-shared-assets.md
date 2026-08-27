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

## 4. Entscheide vom 2026-08-27 und was die Pruefung ergab

**Transport: Paket / Release-Tarball.** Ich hatte als Preis genannt, dass beide
Repos erst einen Release-Prozess fuer Assets brauchen. **Das war falsch, jedenfalls
fuer `odb_autoupgrade`:** dort existiert er vollstaendig.

- `make build` ruft `scripts/build.sh --dist`, und `CONTENT_PATHS` enthaelt
  `etc` und `lib` bereits
- der Release-Workflow haengt `odb_autoupgrade-<VERSION>.tar.gz` **plus
  `.sha256`** an das Release

Der Entscheid kostet fuer dieses Repo also nichts. Fuer `oradba` ist es
unbestaetigt: das Repo liegt mit 21 geaenderten Dateien auf
`fix/boot-path-gates`, und genau `Makefile` und `.github/workflows/release.yml`
sind Teil der Aenderung. **Erst nachpruefen, wenn dieser Branch gelandet ist.**

**Die 15 statischen `download_RU19.*.cfg` werden geloescht.** Zwei Pruefungen
stuetzen das ueber die Begruendung im Entscheid hinaus:

1. **Kein Skript im Repo referenziert sie.** `grep` ueber `bin/` und `lib/`
   findet keinen Konsumenten - sie sind inert, ein Mensch hat sie von Hand an
   AutoUpgrade gegeben. Loeschen bricht keinen Codepfad.
2. **Der parameterisierte Weg existiert dort schon.**
   `bin/run_autoupgrade.sh` loest jede cfg per **`envsubst`** auf und sucht sie
   in `${AUTOUPGRADE_BASE}/etc/`. Die statischen Dateien sind Altlast von vor
   dieser Faehigkeit - eine von ihnen nutzt bereits `$AUTOUPGRADE_BASE`.

Einschraenkung, die ich nicht verschweige: dass sie gegen AutoUpgrade 26.5
scheitern **wuerden**, ist ein Schluss aus dem dokumentierten Lab-Verhalten
(kein `gold_image` gesetzt, Default `AUTO`, Update Advisor antwortet HTTP 500),
kein Test gegen genau diese Dateien.

## 5. Der Vertrag - damit ist der naechste Schritt mechanisch

Die Form der Vorlagen ist damit nicht mehr zu entscheiden, das Repo gibt sie vor:

- **`${VAR}`-Platzhalter, nicht Jinja.** `envsubst` ist der Aufloeser, `etc/`
  der Ort, `run_autoupgrade.sh --cfg <name>` der Aufruf.
- Die Ansible-Rolle konsumiert **dieselbe Datei**: Umgebungsvariablen setzen und
  `envsubst` aufrufen, statt eine zweite Jinja-Kopie zu pflegen. Genau die
  zweite Kopie ist das Problem, das M3 loest.
- Die vier Lab-Vorlagen (`autoupgrade-download`, `-create-home`, `-deploy`,
  `-download-gold`) wandern in dieser Form nach `etc/` und nehmen mit, was das
  Lab teuer gelernt hat: `download_folder` statt `folder`, `target_version`,
  und `gold_image=NO` fuer `target_version=19`.
- Das Lab pinnt eine Tarball-Version und prueft die `.sha256`.

<!-- EOF -->
