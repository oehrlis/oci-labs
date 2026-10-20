# Runbook - Data Safe Demo LRN6087

Demo-Umgebung fuer die Session LRN6087 an der Oracle AI World 2026 (Di 2026-10-27, 08:00 PDT). Eine OCI-VM
(OL8, x86, 4 OCPU, 32 GB) traegt nativ installiert Oracle Database 19c EE (CDB19) und Oracle AI Database 26ai EE
(CDB26) sowie den Data Safe On-Premises Connector, der mit OraDBA verwaltet wird. Der Laptop fuehrt die Demo mit
odb_datasafe und der OCI CLI. Die Fleet-Sicht in Schritt 1 kommt aus einem synthetischen Snapshot (sample data),
die Schritte 2-6 laufen live gegen die echten Targets.

Alle Befehle fuehrt Stefan selbst aus. Secrets kommen ausschliesslich aus 1Password (`op read`, einzeilig).

Lizenz: Beide Datenbanken laufen fuer diese Demo unter der Oracle Technology Network (OTN) Developer License -
Entwicklung, Test und Demonstration, kein produktiver Betrieb.

## Zielbild

```text
ACE-Tenancy, eu-zurich-1, bestehendes Compartment (wird nie angelegt oder geloescht)
  VCN vcn-zrh-lab-dsdemo-01 (core-Modul, core_owner = dsdemo), Bastion, kein Public IP, NSG egress nur 443
  ci-zrh-lab-dsdemo-01-db-01 (VM.Standard.E4.Flex, 4 OCPU, 32 GB, OL8)
    Boot Volume 150 GB: /u00 (ORACLE_BASE, beide Homes), /u02 (FRA), /opt/stage (Medien)
    Data Volume 100 GB: /u01 (Datafiles, xfs, LABEL=u01data)
    19c EE Home (RU 19.32)  -> CDB19: CDB$ROOT, PDB19A, PDB19B   -> 3 Targets
    26ai EE Home (RU latest) -> CDB26: CDB$ROOT, PDB26A, PDB26B  -> 3 Targets
      AIPDB1 -> wird in Schritt 2 live in CDB26 angelegt und registriert, reset.sh entfernt sie
    LISTENER (26ai Home, Port 1521) fuer beide CDBs
    OraDBA (oradba-services.service), odb_datasafe 1.2.1
    Connector dsc-zrh-lab-dsdemo-01 (systemd, CMAN-Port 1561), in OraDBA als dscon1 registriert
  Resource Scheduler: Start 07:00 / Stopp 22:00 Lokalzeit (schedule_profile)
Laptop: Bastion-Tunnel 127.0.0.1:2222, eigene odb_datasafe-Kopie, OCI CLI Profil ACE
```

| Datei | Zweck |
| --- | --- |
| `terraform/envs/datasafe-demo/` | Netz, Bastion, VM, Data Volume, Start/Stopp-Schedules, optional Instance Principal |
| `ansible/playbooks/lab-datasafe-demo.yml` | Playbook, Rolle `oracle_db_native` |
| `ansible/roles/oracle_db_native/` | Homes, CDBs, PDBs, OraDBA, Data-Safe-Accounts, Connector; nutzt `db19_engineering` |
| `demos/datasafe-lrn6087/demo.sh` | Die sechs Demo-Schritte, `register-base`, `prepare`, `check` |
| `demos/datasafe-lrn6087/reset.sh` | Zurueck zum Startzustand (Default Dry-Run) |
| `demos/datasafe-lrn6087/tunnel.sh` | Bastion-Tunnel oeffnen und pruefen |
| `demos/datasafe-lrn6087/fleet-snapshot/` | Generator und Sample des synthetischen Snapshots |

## Voraussetzungen

- OCI CLI mit Profil `ACE` in `~/.oci/config`, Terraform >= 1.5, Ansible (`ansible-core` >= 2.14), `jq`, `op`
- Data Safe in der ACE-Tenancy und in `eu-zurich-1` aktiviert
- Ein bestehendes Compartment fuer die Demo, dessen OCID bekannt ist
- 1Password-Eintrag fuer das Data-Safe-Secret (C##DS_ADMIN / DS_ADMIN), z. B. `datasafe-demo-ds-admin`,
  Feld `password`. Oracle-Passwortregeln: mit Buchstabe beginnen, mindestens 12 Zeichen, keine Anfuehrungszeichen
- MOS-Zugang fuer AutoUpgrade: 1Password Vault `secrets`, Eintrag `Oracle-MOS`, Felder `username` und `password` -
  dieselben Referenzen wie beim CPU-Lab (`OP_MOS_USER` / `OP_MOS_PASS` im Makefile)
- Das 19c-Basis-Image `LINUX.X64_193000_db_home.zip` in einem Object-Storage-Bucket (Default `orarepo`); fuer den
  Bucket braucht es ein OCI-CLI-Profil der Tenancy, der er gehoert (`DSDEMO_PAR_PROFILE`)

## Herkunft der Oracle-Software

- **19c EE:** AutoUpgrade laedt RU 19.32 und OPatch von MOS (`db19_engineering` download/create_home). Das
  Basis-Image 19.3 liefert AutoUpgrade fuer 19c nie - es kommt per kurzlebigem PAR aus dem Bucket
  (`make dsdemo-par`). AutoUpgrade bietet nur das aktuelle und das vorherige RU an; `db19_ru` jedes Quartal anheben.
- **26ai EE:** AutoUpgrade `create_home` mit `download=yes` und `target_version=23` laedt das RU als Gold Image von
  MOS - ein vollstaendiges Home, kein Basis-Image noetig. `db26_ru = ""` heisst "neuestes RU" (`patch=RU,OPATCH`);
  nach dem ersten Lauf das aufgeloeste RU (Report von `opatch lsinventory`) in `db26_ru` festschreiben.
  Quellen: [oracle-base, AutoUpgrade download and install](https://oracle-base.com/articles/misc/autoupgrade-download-and-install-oracle-database-software),
  [dbi services, 26ai mit AutoUpgrade](https://www.dbi-services.com/blog/autoupgrade-powered-easy-download-and-installation-of-oracle-ai-database-26ai-on-linux/),
  [AutoUpgrade Parameter](https://docs.oracle.com/en/database/oracle/oracle-database/26/upgrd/autoupgrade-command-line-parameters.html).
- **26ai Fallback (`db26_install_method = "zip"`):** Image-Zip von
  [OTN](https://www.oracle.com/database/technologies/oracle26ai-linux-downloads.html) oder eDelivery
  (`LINUX.X64_2326100_db_home.zip`, 23.26.1) in den Bucket legen, `make dsdemo-par DB26_ZIP=1`, dann
  `runInstaller -silent` (Software only). Das Home steht dann auf dem RU des Zips.

## Aufbau

### Variablen setzen

```bash
cd terraform/envs/datasafe-demo
cp .env.example .env
cp terraform.tfvars.example terraform.tfvars
chmod 600 .env terraform.tfvars
$EDITOR .env terraform.tfvars
```

In `.env` mindestens `TF_VAR_compartment_ocid`, `DSDEMO_OP_DS_SECRET` (nur die Referenz) und `DSDEMO_PAR_PROFILE`
setzen. In `terraform.tfvars` das `schedule_profile` passend zur Woche waehlen (siehe
[Start und Stopp](#start-und-stopp---schedule_profile)). Fuer den Instance-Principal-Weg zusaetzlich
`enable_instance_principal = true` und `tenancy_ocid`.

Wer den frueheren Free-Container-Stand bereits deployed hat: zuerst `make dsdemo-destroy`, dann neu aufbauen. Ein
In-Place-Update wuerde den alten Podman-Stand auf dem Boot Volume stehen lassen.

### Infrastruktur

```bash
make dsdemo-plan
make dsdemo-apply
make dsdemo-par
make dsdemo-tunnel
```

`dsdemo-plan` schreibt `tfplan`, `dsdemo-apply` wendet genau diesen Plan an. Das Inventory landet git-ignoriert in
`ansible/inventories/generated/datasafe-demo/hosts.yml`, der Lab-Key in `terraform/envs/datasafe-demo/.ssh/`.
`dsdemo-par` legt einen ObjectRead-PAR (Default 3 Tage, `DSDEMO_PAR_DAYS`) auf das 19c-Basis-Image und schreibt die
URL als `DSDEMO_DB19_BASE_IMAGE_URL` in `.env` - der Token erscheint nie in der Ausgabe.

### Connector-Weg waehlen

- **Instance Principal** (`enable_instance_principal = true`): Ansible ruft `ds_connector_create.sh` auf dem Host
  auf - Connector in OCI anlegen, Bundle laden, `setup.py install`, danach `install_datasafe_service.sh`.
- **Ohne Instance Principal** (Default): Connector und Bundle vom Laptop anlegen, Bundle auf den Host kopieren,
  Ansible installiert es. Siehe [Connector ohne Instance Principal](#connector-ohne-instance-principal).

### Host installieren

Waehrend der Installation darf kein Stopp-Schedule greifen: entweder vor 22:00 Lokalzeit fertig werden oder vorher
`make dsdemo-schedule PROFILE=off && make dsdemo-apply` und danach das Profil wieder setzen.

```bash
eval $(op signin)
make dsdemo-install
make dsdemo-par-revoke
```

Der Lauf (rund 1.5-2.5 Stunden) formatiert und mountet das Data Volume auf `/u01`, setzt die OL8-Voraussetzungen
(`db19_engineering` os_prereq: Preinstall-RPM, Benutzer, SELinux permissive, THP aus, Root-FS vergroessern), das
26ai-Preinstall-RPM (falls im Repository vorhanden, sonst eine Meldung), Java 17, python3.11 als `python3`, OraDBA mit
`oradba-services.service`, AutoUpgrade mit MOS-Keystore, das 19c-Home und das 26ai-Home, den Listener im 26ai-Home,
CDB26 und CDB19 per dbca (erste PDB) plus die weiteren PDBs per `dsdemo-pdb create`, odb_datasafe 1.2.1, C##DS_ADMIN
und DS_ADMIN per `ds_database_prereqs.sh --all` in beiden CDBs, den Connector samt systemd-Unit und registriert ihn
in OraDBA (`oradba_homes.sh add --type datasafe`, danach `ds_connector_register_oradba.sh`).

Einzelne Schritte: `make dsdemo-step TAG=<tag>` mit `storage`, `prereq`, `oradba`, `homes`, `home19`, `home26`,
`databases`, `odb_datasafe`, `ds_prereqs`, `connector`, `verify`.

Auf dem Host:

| Helfer | Zweck |
| --- | --- |
| `sudo dsdemo-sql [SID]` | SQL von stdin als SYSDBA (Default CDB26) |
| `sudo dsdemo-pdb --db SID list\|create\|drop\|prereqs\|check\|drop-user` | PDBs und Data-Safe-User, Secret nur via stdin |
| `sudo dsdemo-connector status\|start\|stop\|restart\|services` | `oradba_dsctl.sh` fuer den Connector `dscon1` |

`dsdemo-pdb drop` verweigert die Start-PDBs (PDB19A, PDB19B, PDB26A, PDB26B, PDB$SEED).

### Connector ohne Instance Principal

Auf dem Laptop, Profil `ACE`. Der Bundle-Key wird lokal erzeugt und nie getippt.

```bash
COMP=$(terraform -chdir=terraform/envs/datasafe-demo output -raw compartment_ocid)
oci --profile ACE data-safe on-prem-connector create --compartment-id "$COMP" --display-name dsc-zrh-lab-dsdemo-01 --wait-for-state SUCCEEDED
CONN=$(oci --profile ACE data-safe on-prem-connector list --compartment-id "$COMP" --all --query "data[?\"display-name\"=='dsc-zrh-lab-dsdemo-01'].id | [0]" --raw-output)
umask 077; KEY="Ds$(openssl rand -hex 12)Aa1"; printf '%s' "$KEY" | base64 > dsc-zrh-lab-dsdemo-01_pwd.b64
oci --profile ACE data-safe on-prem-connector generate-on-prem-connector-configuration --on-prem-connector-id "$CONN" --password "$KEY" --file dsc-zrh-lab-dsdemo-01.zip
unset KEY
```

Bundle und Key auf den Host kopieren und den Connector-Schritt nachholen:

```bash
KEYFILE=$(terraform -chdir=terraform/envs/datasafe-demo output -raw lab_private_key_path)
scp -i "$KEYFILE" -o IdentitiesOnly=yes -P 2222 dsc-zrh-lab-dsdemo-01.zip dsc-zrh-lab-dsdemo-01_pwd.b64 opc@127.0.0.1:/tmp/
ssh -i "$KEYFILE" -o IdentitiesOnly=yes -p 2222 opc@127.0.0.1 'sudo install -d -o oracle -g oinstall -m 0700 /home/oracle/connector-bundle && sudo install -o oracle -g oinstall -m 0600 /tmp/dsc-zrh-lab-dsdemo-01.* /tmp/dsc-zrh-lab-dsdemo-01_pwd.b64 /home/oracle/connector-bundle/ && rm -f /tmp/dsc-zrh-lab-dsdemo-01*'
rm -f dsc-zrh-lab-dsdemo-01.zip dsc-zrh-lab-dsdemo-01_pwd.b64
make dsdemo-step TAG=connector
```

Ohne Bundle melden der Connector-Schritt und die OraDBA-Registrierung `SKIPPED` mit diesem Befehl - sie schweigen
nicht.

### Laptop vorbereiten

Fuer die Demo eine **eigene** odb_datasafe-Kopie, nie die Alltags-Installation: `demo.sh` und `reset.sh` setzen
`ORADBA_ETC` zurueck und brechen ab, wenn die Kopie ein `etc/datasafe.conf` mitbringt. So kann keine andere
Tenancy-Konfiguration auf dem Bildschirm landen.

```bash
mkdir -p ~/demo/odb_datasafe-1.2.1
gh release download v1.2.1 -R oehrlis/odb_datasafe -p 'odb_datasafe-1.2.1.tar.gz*' -D ~/demo
(cd ~/demo && shasum -a 256 odb_datasafe-1.2.1.tar.gz)
tar xzf ~/demo/odb_datasafe-1.2.1.tar.gz -C ~/demo/odb_datasafe-1.2.1
cp demos/datasafe-lrn6087/odb_datasafe.env.example ~/demo/odb_datasafe-1.2.1/.env
chmod 600 ~/demo/odb_datasafe-1.2.1/.env
$EDITOR ~/demo/odb_datasafe-1.2.1/.env
cp demos/datasafe-lrn6087/demo.env.example demos/datasafe-lrn6087/demo.env
$EDITOR demos/datasafe-lrn6087/demo.env
```

Die Pruefsumme muss `fba0cd8dfc49e0ab42037c590799c3cbf86855f67d48c1d17ba2db4638ad7401` lauten. Die `.env` muss
`0600` sein: odb_datasafe ignoriert eine group- oder world-schreibbare `.env` und meldet das als ERROR.

Sobald ein odb_datasafe-Release `ds_target_register.sh --type compute|onprem` enthaelt (Branch
`feat/register-onprem`), dafuer eine neue Kopie anlegen und `DEMO_ODB_BASE` darauf zeigen. `demo.sh` erkennt die
Option ueber `--help` (`DEMO_REGISTER_MODE=auto`) und registriert dann mit odb_datasafe statt mit der OCI CLI;
`demo.sh check` zeigt den gewaehlten Weg.

### Tag-Namespace und Start-Targets

Einmalig, danach ist der Startzustand erreicht (6 Targets, getaggt, Audit Trails laufen):

```bash
export ODB_DATASAFE_BASE=~/demo/odb_datasafe-1.2.1
$ODB_DATASAFE_BASE/bin/ds_tag_namespace.sh -f demos/datasafe-lrn6087/dbsec-tag-namespace.json --oci-profile ACE
$ODB_DATASAFE_BASE/bin/ds_tag_namespace.sh -f demos/datasafe-lrn6087/dbsec-tag-namespace.json --oci-profile ACE --apply
demos/datasafe-lrn6087/demo.sh check
demos/datasafe-lrn6087/demo.sh --dry-run register-base
demos/datasafe-lrn6087/demo.sh register-base
```

## Verifikation

```bash
make dsdemo-verify
demos/datasafe-lrn6087/demo.sh check
demos/datasafe-lrn6087/demo.sh step 1
```

Erwartet: Listener up mit den Services beider CDBs, PDB19A/PDB19B und PDB26A/PDB26B READ WRITE (PDB$SEED READ
ONLY), `ds_database_prereqs.sh --check` pro CDB mit rc 0, Connector-Service running und `oradba_dsctl.sh status` fuer
`dscon1`, in der Konsole die sechs Targets ACTIVE. Schritt 1 zeigt 55 Sample-Targets: 45 ACTIVE, 7 NEEDS_ATTENTION,
3 INACTIVE.

## Demo fahren

Vor der Session (Host laeuft ab 07:00 Lokalzeit per Schedule, sonst starten), Tunnel, Probelauf:

```bash
make dsdemo-start
make dsdemo-tunnel
demos/datasafe-lrn6087/demo.sh check
demos/datasafe-lrn6087/demo.sh --dry-run run
```

Live, mit Pause vor jedem Befehl (Enter):

```bash
demos/datasafe-lrn6087/demo.sh run
```

| Schritt | Inhalt |
| --- | --- |
| 1 | Fleet-Zustand und Probleme aus dem synthetischen Snapshot (sample data) |
| 2 | AIPDB1 live in CDB26 anlegen, DS_ADMIN anlegen und pruefen, Registrierung erst als Plan, dann echt |
| 3 | Tags: ungetaggte Targets finden, `ds_target_update_tags.sh` ohne und mit `--apply` |
| 4 | Audit Trail: Zustand, Start fuer AIPDB1, Kontrolle |
| 5 | Security Assessment refresh und HIGH-Findings mit der OCI CLI |
| 6 | Connector mit OraDBA verwaltet: `oradba_dsctl.sh services` und `status` (`DEMO_CONNECTOR_RESTART=TRUE` zeigt zusaetzlich `restart`) |

Fuer das Recording ohne Pausen `--no-pause`, einzelne Schritte mit `demo.sh step <1-6>`. Dauert das Anlegen von
AIPDB1 live zu lange, vor der Session `demo.sh prepare` - Schritt 2 erkennt die vorhandene PDB und macht weiter.

Fleet-Mix als Gespraechsstoff: CDB19 (19c) neben CDB26 (26ai) im selben Compartment, die Target-Beschreibung nennt das
Release. SQL Firewall gibt es nur in 26ai - in der Konsole bei einem CDB26-Target zeigen, bei CDB19 fehlt sie.

Danach zurueck zum Startzustand:

```bash
demos/datasafe-lrn6087/reset.sh
demos/datasafe-lrn6087/reset.sh --apply
```

## Kosten - Start und Stopp

Ein gestoppter Host kostet nur Block Storage (Boot und Data Volume). Homes, CDBs, PDBs, Connector und Targets
ueberleben den Stop; `oradba-services.service` startet Listener und CDBs (oratab `:Y`), die Connector-Unit den
Connector. Die Bastion-Session ueberlebt den Stop nicht.

```bash
make dsdemo-stop
make dsdemo-start
make dsdemo-tunnel
```

### Start und Stopp - schedule_profile

Zwei Resource-Scheduler-Schedules starten den Host taeglich um 07:00 und stoppen ihn um 22:00 Lokalzeit. OCI rechnet
die Cron-Ausdruecke in UTC, deshalb uebersetzt Terraform das Profil in UTC:

| Profil | Wann | Start UTC | Stopp UTC | Lokal |
| --- | --- | --- | --- | --- |
| `cest` | bis Sa 2026-10-24 (Schweiz, Sommerzeit UTC+2) | `0 5 * * *` | `0 20 * * *` | 07:00-22:00 CEST |
| `cet` | ab So 2026-10-25, falls in der Schweiz (UTC+1) | `0 6 * * *` | `0 21 * * *` | 07:00-22:00 CET |
| `pdt` | Reisewoche Las Vegas, PDT bis 2026-11-01 (UTC-7) | `0 14 * * *` | `0 5 * * *` | 07:00-22:00 PDT |
| `off` | Installation, Sonderfaelle | - | - | nur `dsdemo-start` / `dsdemo-stop` |

Beim Profil `pdt` faellt der Stopp um 22:00 PDT auf 05:00 UTC des **Folgetags**. Als taeglicher Cron ist das einfach
`0 5 * * *`; der erste Stopp nach dem Umschalten kommt am naechsten Morgen UTC. Solange Stefan noch in Europa ist,
laeuft der Host mit `pdt` von 16:00 bis 07:00 CEST.

Diese Woche gilt `cest`. Vor der Abreise (spaetestens 2026-10-25) auf `pdt` umstellen:

```bash
make dsdemo-schedule PROFILE=pdt
make dsdemo-apply
```

`dsdemo-schedule` schreibt `schedule_profile` in `terraform.tfvars` und plant, `dsdemo-apply` schaltet die beiden
Schedules um. `schedule_start_cron` / `schedule_stop_cron` ueberschreiben einzelne Zeiten. Die Session am 2026-10-27
um 08:00 PDT (15:00 UTC) liegt im `pdt`-Fenster; fuer eine Probe vor 07:00 PDT von Hand starten.

Damit die Schedules die Instanz ueberhaupt starten und stoppen duerfen, legt Terraform die Policy
`pol-zrh-lab-dsdemo-01-sched-01` an (`create_scheduler_policy`, Principal-Typ `resourceschedule`).

### Kostenrelevant

- VM.Standard.E4.Flex mit 4 OCPU und 32 GB statt 2 OCPU und 16 GB - etwa doppelte Compute-Kosten pro Laufstunde,
  durch das 15-Stunden-Fenster (Start/Stopp) begrenzt.
- Boot Volume 150 statt 100 GB, neu ein Data Volume 100 GB mit 10 VPU/GB - Block Storage laeuft auch im Stop weiter.
- Data Safe fuer Compute-Datenbanken ist bis 2027-02-28 ohne Gebuehren (Promotion); Audit ueber dem inkludierten
  Volumen kostet.
- Lizenz: OTN Developer License (siehe oben), keine Lizenzkosten fuer die Demo.

## Teardown

Zuerst Data Safe aufraeumen, dann die Infrastruktur:

```bash
export ODB_DATASAFE_BASE=~/demo/odb_datasafe-1.2.1
$ODB_DATASAFE_BASE/bin/ds_target_delete.sh -c "<demo-compartment-name>" -s ACTIVE,NEEDS_ATTENTION,INACTIVE --dry-run
$ODB_DATASAFE_BASE/bin/ds_target_delete.sh -c "<demo-compartment-name>" -s ACTIVE,NEEDS_ATTENTION,INACTIVE --force
CONN=$(oci --profile ACE data-safe on-prem-connector list --compartment-id "$(terraform -chdir=terraform/envs/datasafe-demo output -raw compartment_ocid)" --all --query "data[?\"display-name\"=='dsc-zrh-lab-dsdemo-01'].id | [0]" --raw-output)
oci --profile ACE data-safe on-prem-connector delete --on-prem-connector-id "$CONN" --wait-for-state SUCCEEDED
make dsdemo-par-revoke
make dsdemo-destroy
```

Das Compartment bleibt bestehen. Der Tag-Namespace `DBSec` bleibt ebenfalls (Namespaces lassen sich nur
retiren, nicht sofort loeschen).

## Synthetischer Snapshot

Der Snapshot hat exakt das Format von `ds_target_list.sh --save-json` (`{"data": [...]}` mit den kebab-case-Feldern
von `oci data-safe target-database list`). Alle Werte sind erfunden und als Sample markiert (`description`
SAMPLE DATA, Freeform-Tag `sample=true`, Namen `demo-cluNN_cdbNN_<pdb>`, Compartment
`ocid1.compartment.oc1..samplecompartment...`).

```bash
python3 -I demos/datasafe-lrn6087/fleet-snapshot/gen_fleet_snapshot.py -o demos/datasafe-lrn6087/fleet-snapshot/fleet-snapshot-sample.json
```

Gegen odb_datasafe 1.2.1 offline geprueft (OCI CLI durch einen Stub ersetzt, null Aufrufe): `--count` und
`--problems` laufen mit `--input-json` ohne OCI-Zugriff.

## Bekannte Grenzen

- **`ds_target_register.sh` (1.2.1) kennt nur ExaCC/Cloud Service.** Der Payload ist fest
  `DATABASE_CLOUD_SERVICE` / `CLOUD_AT_CUSTOMER`. Mit 1.2.1 registriert `demo.sh` deshalb per OCI CLI
  (`INSTALLED_DATABASE`, `instanceId`, `ipAddresses`, `listenerPort`, `serviceName`, `ONPREM_CONNECTOR`) und zeigt
  auf dem Bildschirm die Folienzeile. Mit einem Release, das `--type compute|onprem` kennt, nimmt `demo.sh` den
  odb_datasafe-Weg automatisch.
- **Kein Instance Principal in odb_datasafe.** Die Skripte uebergeben immer `--config-file` und `--profile`; der
  Host bekommt deshalb ein schluesselloses `~/.oci/config` (nur Region) und `OCI_CLI_AUTH=instance_principal`.
- **`--input-json` mit `-A`** schreibt eine WARN-Zeile ("ignoring OCI selection flags"). `demo.sh` zeigt deshalb
  auf dem Bildschirm `-A --count`, ruft aber ohne `-A` auf.
- **Subnet-Security-List** des core-Moduls erlaubt weiterhin DNS, NTP, HTTP 80 und HTTPS 443 ausgehend; Security
  Lists und NSGs wirken als Vereinigung. Die NSG des Hosts erlaubt nur 443 und VCN-intern - MOS, yum, GitHub und
  Data Safe laufen alle ueber 443.
- **AutoUpgrade und 19c-Gold-Images:** fuer `target_version=19` antwortet der Oracle Update Advisor mit HTTP 500
  (siehe `db19_engineering`), deshalb Basis-Image plus RU. 26ai ist davon nicht betroffen.

## Offen

- **Folien 20/21:** Platzhalter `CDB01` -> real `CDB26` (Live-PDB) bzw. `CDB19`, `lab` -> echter Compartment-Name;
  die Demo hat jetzt einen sechsten Schritt (Connector mit OraDBA) - Folie 20 ergaenzen oder Schritt 6 nur zeigen?
- **odb_datasafe mit `--type`:** Release vor dem 27.10. (dann Laptop-Kopie und Host-Version `oradb_odb_datasafe_version`
  plus SHA256 nachziehen) oder OCI-CLI-Weg mit Folienzeile auf dem Bildschirm?
- **Infrastructure-Type:** `ORACLE_CLOUD` + `instanceId` (`--type compute`, faellt unter die Promotion) mit
  On-Premises Connector - in der Data Safe Doku verifizieren; sonst `DEMO_INFRA_TYPE=ON_PREMISES` (Kosten pruefen).
- **Connector-Weg:** Instance Principal (Dynamic Group in der ACE-Tenancy) oder Laptop-Fallback?
- **Connector-Voraussetzungen:** Java 17 und python3.11 auf OL8 fuer den Connector verifizieren (Connector-Doku);
  `JAVA_HOME` ist `/usr/lib/jvm/jre-17-openjdk`. AutoUpgrade laeuft bewusst auf `/usr/lib/jvm/jre-11-openjdk` (verify:
  Pfad auf dem OL8-Image).
- **OraDBA und der Connector:** `oradba_dsctl.sh start/stop` neben der systemd-Unit `oracle_datasafe_<name>` - live
  nur `status` und `services` zeigen oder auch `restart` (`DEMO_CONNECTOR_RESTART`)? Einmal vorab proben.
- **Listener nach Reboot:** OraDBA startet den Default-Listener aus dem ersten Home in `/etc/oratab` (CDB26 steht
  deshalb zuerst). Nach dem ersten `dsdemo-stop`/`dsdemo-start` pruefen, dass `lsnrctl status` aus dem 26ai-Home
  beide CDBs zeigt.
- **26ai-RU festschreiben:** nach dem ersten Lauf `db26_ru` auf das aufgeloeste RU setzen (sonst zieht ein Neuaufbau
  ein neueres RU und einen anderen Home-Pfad).
- **19c-RU:** das Oktober-2026-RU (19.33) erscheint um den 2026-10-20 - bei 19.32 bleiben (getestet) oder anheben?
- **26ai-Preinstall-RPM:** Name `oracle-ai-database-preinstall-26ai` auf OL8 verifizieren; fehlt es, meldet der Lauf
  das und arbeitet mit dem 19c-RPM weiter.
- **Zip-Fallback:** die Response-File-Keys von `db_install_26ai.rsp.j2` (Schema v23.0.0) beim ersten Einsatz pruefen.
- **Scheduler-Policy:** Statement `request.principal.type = 'resourceschedule'` gegen die Resource-Scheduler-Doku
  verifizieren; ohne Recht auf Policies im Compartment `create_scheduler_policy = false` und eine bestehende Policy
  nutzen.
- **Environment-Tag:** `DS_ENV_COMP_REGEX` fuer den Compartment-Namen - ohne Regex wird `Environment` zu `undef`
  und `ContainerStage` zu `undef`. Regex festlegen oder in Schritt 3 `--stage` setzen.
- **Region:** `eu-zurich-1` (entschieden) - Latenz aus dem Konferenz-WLAN vor Ort pruefen, Recording als Fallback.
- **Namenskonvention:** das naming-Modul erzeugt `ci-zrh-lab-dsdemo-01-db-01` (Instanz im Kern, Praefix `ci`),
  nicht `vm-zrh-lab-dsdemo-db-01`. Modul anpassen oder so belassen?
