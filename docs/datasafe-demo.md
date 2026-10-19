# Runbook - Data Safe Demo LRN6087

Demo-Umgebung fuer die Session LRN6087 an der Oracle AI World 2026 (Di 2026-10-27, 08:00 PDT). Eine OCI-VM
(OL8, x86) traegt Oracle AI Database 26ai Free in Podman und den Data Safe On-Premises Connector. Der Laptop
fuehrt die Demo mit odb_datasafe und der OCI CLI. Die Fleet-Sicht in Schritt 1 kommt aus einem synthetischen
Snapshot (sample data), die Schritte 2-5 laufen live gegen die echten Targets.

Alle Befehle fuehrt Stefan selbst aus. Secrets kommen ausschliesslich aus 1Password (`op read`, einzeilig).

## Zielbild

```text
ACE-Tenancy, eu-zurich-1, bestehendes Compartment (wird nie angelegt oder geloescht)
  VCN vcn-zrh-lab-dsdemo-01 (core-Modul, core_owner = dsdemo), Bastion, kein Public IP
  ci-zrh-lab-dsdemo-01-db-01 (VM.Standard.E4.Flex, 2 OCPU, 16 GB, OL8)
    Podman: dsdemo-db.service -> oracle-free-labs Image (26ai Free)
      CDB FREE: CDB$ROOT, FREEPDB1, ODBSEED, ODBREPO -> 4 Targets
      AIPDB1 -> wird vor der Session angelegt, in Schritt 2 live registriert
    Connector dsc-zrh-lab-dsdemo-01 (systemd, CMAN-Port 1561), nur ausgehend HTTPS
    odb_datasafe 1.2.1 unter /opt/oracle/local/odb_datasafe
Laptop: Bastion-Tunnel 127.0.0.1:2222, eigene odb_datasafe-Kopie, OCI CLI Profil ACE
```

| Datei | Zweck |
| --- | --- |
| `terraform/envs/datasafe-demo/` | Netz, Bastion, VM, Auto-Stop, optional Instance Principal |
| `ansible/playbooks/lab-datasafe-demo.yml` | Playbook, Rolle `datasafe_demo` |
| `demos/datasafe-lrn6087/demo.sh` | Die fuenf Demo-Schritte, `prepare`, `register-base`, `check` |
| `demos/datasafe-lrn6087/reset.sh` | Zurueck zum Startzustand (Default Dry-Run) |
| `demos/datasafe-lrn6087/tunnel.sh` | Bastion-Tunnel oeffnen und pruefen |
| `demos/datasafe-lrn6087/fleet-snapshot/` | Generator und Sample des synthetischen Snapshots |

## Voraussetzungen

- OCI CLI mit Profil `ACE` in `~/.oci/config`, Terraform >= 1.5, Ansible (`ansible-core` >= 2.14), `jq`, `op`
- Data Safe in der ACE-Tenancy und in `eu-zurich-1` aktiviert
- Ein bestehendes Compartment fuer die Demo, dessen OCID bekannt ist
- 1Password-Eintrag fuer das Data-Safe-Secret (C##DS_ADMIN / DS_ADMIN), z. B. `datasafe-demo-ds-admin`,
  Feld `password`. Oracle-Passwortregeln: mit Buchstabe beginnen, mindestens 12 Zeichen, keine Anfuehrungszeichen

## Aufbau

### Variablen setzen

```bash
cd terraform/envs/datasafe-demo
cp .env.example .env
cp terraform.tfvars.example terraform.tfvars
chmod 600 .env terraform.tfvars
$EDITOR .env terraform.tfvars
```

In `.env` mindestens `TF_VAR_compartment_ocid` und `DSDEMO_OP_DS_SECRET` (nur die Referenz) setzen. Fuer den
Instance-Principal-Weg in `terraform.tfvars` `enable_instance_principal = true` und `tenancy_ocid` setzen.

### Infrastruktur

```bash
make dsdemo-plan
make dsdemo-apply
make dsdemo-tunnel
```

`dsdemo-plan` schreibt `tfplan`, `dsdemo-apply` wendet genau diesen Plan an. Das Inventory landet git-ignoriert in
`ansible/inventories/generated/datasafe-demo/hosts.yml`, der Lab-Key in `terraform/envs/datasafe-demo/.ssh/`.

### Connector-Weg waehlen

- **Instance Principal** (`enable_instance_principal = true`): Ansible ruft `ds_connector_create.sh` auf dem Host
  auf - Connector in OCI anlegen, Bundle laden, `setup.py install`, danach `install_datasafe_service.sh`.
- **Ohne Instance Principal** (Default): Connector und Bundle vom Laptop anlegen, Bundle auf den Host kopieren,
  Ansible installiert es. Siehe [Connector ohne Instance Principal](#connector-ohne-instance-principal).

### Host installieren

```bash
eval $(op signin)
make dsdemo-install
```

Der Lauf installiert Podman, python3.11 (als `python3`), Java 17, baut das oracle-free-labs-Image auf
`container-registry.oracle.com/database/free:latest`, startet `dsdemo-db.service`, wartet auf FREEPDB1, ODBSEED,
ODBREPO (erster Start 10-15 Minuten), legt C##DS_ADMIN und DS_ADMIN per `ds_database_prereqs.sh --all` an und
installiert den Connector. Einzelne Schritte: `make dsdemo-step TAG=<tag>` mit `prereq`, `odb_datasafe`,
`container`, `ds_prereqs`, `connector`, `verify`.

ODBSEED und ODBREPO entstehen leer aus PDB$SEED, ausser die oracle-free-labs-Archive `pdb26ai_odbseed.pdb` und
`pdb26ai_odbrepo.pdb` liegen vor dem ersten Containerstart in `/u01/dsdemo/pdbarch` auf dem Host.

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

Ohne Bundle meldet der Connector-Schritt `SKIPPED connector install` mit diesem Befehl - er schweigt nicht.

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

### Tag-Namespace und Start-Targets

Einmalig, danach ist der Startzustand erreicht (4 Targets, getaggt, Audit Trails laufen):

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

Erwartet: `dsdemo-db.service` running, Connector-Service running, FREEPDB1, ODBSEED und ODBREPO READ WRITE (PDB$SEED READ
ONLY), `ds_database_prereqs.sh --check` ohne Fehler, in der Konsole die vier Targets ACTIVE. Schritt 1 zeigt
55 Sample-Targets: 45 ACTIVE, 7 NEEDS_ATTENTION, 3 INACTIVE.

## Demo fahren

Vor der Session (Host starten, Tunnel, AIPDB1 bereitstellen):

```bash
make dsdemo-start
make dsdemo-tunnel
demos/datasafe-lrn6087/demo.sh prepare
demos/datasafe-lrn6087/demo.sh --dry-run run
```

Live, mit Pause vor jedem Befehl (Enter):

```bash
demos/datasafe-lrn6087/demo.sh run
```

Fuer das Recording ohne Pausen `--no-pause`, einzelne Schritte mit `demo.sh step <1-5>`. Schritt 2 zeigt zuerst
den Plan (Dry-Run), dann die Registrierung. Schritt 3 zeigt `ds_target_update_tags.sh` erst ohne, dann mit
`--apply`.

Danach zurueck zum Startzustand:

```bash
demos/datasafe-lrn6087/reset.sh
demos/datasafe-lrn6087/reset.sh --apply
```

## Kosten - Stop und Start

Ein gestoppter Host kostet nur Block Storage. Container, PDBs, Connector und Targets ueberleben den Stop; beide
systemd-Units starten beim Boot. Die Bastion-Session ueberlebt den Stop nicht.

```bash
make dsdemo-stop
make dsdemo-start
make dsdemo-tunnel
```

Zusaetzlich stoppt der Resource Scheduler den Host taeglich um 21:00 UTC (`auto_stop_cron`). Data Safe fuer
Compute-Datenbanken ist bis 2027-02-28 ohne Gebuehren (Promotion); Audit ueber dem inkludierten Volumen kostet.

## Teardown

Zuerst Data Safe aufraeumen, dann die Infrastruktur:

```bash
export ODB_DATASAFE_BASE=~/demo/odb_datasafe-1.2.1
$ODB_DATASAFE_BASE/bin/ds_target_delete.sh -c "<demo-compartment-name>" -s ACTIVE,NEEDS_ATTENTION,INACTIVE --dry-run
$ODB_DATASAFE_BASE/bin/ds_target_delete.sh -c "<demo-compartment-name>" -s ACTIVE,NEEDS_ATTENTION,INACTIVE --force
CONN=$(oci --profile ACE data-safe on-prem-connector list --compartment-id "$(terraform -chdir=terraform/envs/datasafe-demo output -raw compartment_ocid)" --all --query "data[?\"display-name\"=='dsc-zrh-lab-dsdemo-01'].id | [0]" --raw-output)
oci --profile ACE data-safe on-prem-connector delete --on-prem-connector-id "$CONN" --wait-for-state SUCCEEDED
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
  `DATABASE_CLOUD_SERVICE` / `CLOUD_AT_CUSTOMER`, `-H` wird ueber DB-Nodes und VM-Cluster aufgeloest. Fuer
  diesen Container braucht es `INSTALLED_DATABASE` mit `instanceId` (oder `ipAddresses`), `listenerPort`,
  `serviceName` und `connectionOption` `ONPREM_CONNECTOR`. `demo.sh` registriert deshalb per Default mit der
  OCI CLI (`DEMO_REGISTER_MODE=oci`) und zeigt auf dem Bildschirm die Folienzeile. Vorschlag fuer odb_datasafe:
  Optionen `--db-type installed`, `--instance-id`, `--ip`, `--infra-type`, Host-Aufloesung bei `installed`
  ueberspringen. Danach `DEMO_REGISTER_MODE=odb`.
- **Kein Instance Principal in odb_datasafe.** Die Skripte uebergeben immer `--config-file` und `--profile`; der
  Host bekommt deshalb ein schluesselloses `~/.oci/config` (nur Region) und `OCI_CLI_AUTH=instance_principal`.
  Vorschlag: `OCI_CLI_AUTH` / `--auth` explizit unterstuetzen.
- **`--input-json` mit `-A`** schreibt eine WARN-Zeile ("ignoring OCI selection flags"). `demo.sh` zeigt deshalb
  auf dem Bildschirm `-A --count`, ruft aber ohne `-A` auf.
- **Subnet-Security-List** des core-Moduls erlaubt weiterhin DNS, NTP, HTTP 80 und HTTPS 443 ausgehend; Security
  Lists und NSGs wirken als Vereinigung. Die NSG des Hosts erlaubt nur 443 und VCN-intern.

## Offen

- **Namen auf Folie 21:** Platzhalter `CDB01` -> real `FREE` (Free laeuft nur mit SID FREE), `lab` -> echter
  Compartment-Name. Folie anpassen oder `DEMO_SID` bewusst als Anzeigename verwenden?
- **Registrierungsweg Schritt 2:** odb_datasafe vor dem 27.10. um `INSTALLED_DATABASE` erweitern (Folie bleibt
  wahr) oder OCI-CLI-Fallback mit Folienzeile auf dem Bildschirm?
- **Infrastructure-Type:** `ORACLE_CLOUD` + `instanceId` (Compute-Datenbank, faellt unter die Promotion) mit
  On-Premises Connector - in der Data Safe Doku verifizieren; sonst `DEMO_INFRA_TYPE=ON_PREMISES` (Kosten pruefen).
- **Connector-Weg:** Instance Principal (Dynamic Group in der ACE-Tenancy) oder Laptop-Fallback?
- **Connector-Voraussetzungen:** Java 17 und python3.11 auf OL8 fuer den Connector verifizieren (Connector-Doku);
  `JAVA_HOME` ist `/usr/lib/jvm/jre-17-openjdk`.
- **Environment-Tag:** `DS_ENV_COMP_REGEX` fuer den Compartment-Namen - ohne Regex wird `Environment` zu `undef`
  und `ContainerStage` zu `undef`. Regex festlegen oder in Schritt 3 `--stage` setzen.
- **PDB-Archive:** `pdb26ai_odbseed.pdb` und `pdb26ai_odbrepo.pdb` auf den Host stagen (Demo-Inhalte) oder leere
  PDBs akzeptieren?
- **Region:** `eu-zurich-1` (entschieden) - Latenz aus dem Konferenz-WLAN vor Ort pruefen, Recording als Fallback.
- **Namenskonvention:** das naming-Modul erzeugt `ci-zrh-lab-dsdemo-01-db-01` (Instanz im Kern, Praefix `ci`),
  nicht `vm-zrh-lab-dsdemo-db-01`. Modul anpassen oder so belassen?
- **Auto-Stop:** 21:00 UTC passt fuer Abend-Recordings und den 27.10.; vor langen Sessions pruefen.
