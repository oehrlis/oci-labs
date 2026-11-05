# Runbook: oradba.automation Lab Test

Lab test of the Ansible collection
[`oradba.automation`](https://github.com/oehrlis/oradba-ansible) against the real
database `CPUDB` of the `cpu-patch-test` lab. Collection v0.2.0 ships the roles
`oracle_home_switch` and `oracle_home_rollback`, which so far have only run
against molecule stubs with the engine in dry-run mode. This test runs them
against a real database before the USZ window.

The lab provides the host, the database, the tunnel and the secrets. The
collection brings its own tree on the host, so the two do not touch each other:

<!-- markdownlint-disable MD013 MD060 -->
| | Lab role `db19_engineering` | Collection `oradba.automation` |
| --- | --- | --- |
| AutoUpgrade | `/opt/autoupgrade/autoupgrade.jar`, plain `java -jar` | engine `odb_autoupgrade` 0.6.1 under `/u00/app/oracle/local/odb_autoupgrade` |
| Log directory | `/u00/app/oracle/cfgtoollogs/autoupgrade` | below the engine base |
| Homes | `product/<RU>/dbhome_1` | `product/<RU>.0.0` |
| Patch list | `db19_patch_list_*` in the role | profile from `cpu-patch-tests/profiles/` |
| Entry point | `make cpu-lab-*` | `make cpu-lab-coll*` |
<!-- markdownlint-restore -->

Separate log directories matter: a deploy that keeps its restore point leaves an
open AutoUpgrade job behind, and that job blocks every later job that uses the
same log directory (see the lab runbook, "A pending deploy job blocks every later
AutoUpgrade job").

## What is under test

- `site_setup`: groups and GIDs, user, layout, engine 0.6.1 pinned by sha256, MOS
  keystore
- `patch_download`: profile `2026-09_db19_linux` (RU 19.32 + OJVM + MRP + JDK +
  DPBP, gold image), pin file, verification
- `home_create`: `create_home` from the profile folder, root scripts,
  `au_home_verify.sh`
- `patch_apply`: preflight, then `oracle_home_switch` in phase `standalone`.
  This is the part that has never run on a real database
- `patch_rollback`, both modes: `restore` (flashback to the deploy restore point)
  and `home` (previous home plus datapatch). Also never run on a real database

Profile `2026-09_db19_linux` is RU 19.32, a level this lab has already patched
to on 2026-08-21. A failure therefore points at the collection rather than at a
new Release Update. AutoUpgrade serves only the current and the previous RU, so
19.32 can still be downloaded after the October CPU (19.33 current, 19.32
previous).

## Prerequisites

- The lab exists and is stopped or running (`make cpu-lab-output`)
- `eval $(op signin)` for the steps `setup` and `download` - the MOS
  credentials come from `op://secrets/Oracle-MOS`. The MOS password was rotated
  in October 2026; the keystore picks up whatever 1Password holds
- `cpu-patch-tests` checked out next to `oci-labs`, or `CPU_PATCH_TESTS_DIR`
  pointing at it. Read only - nothing is written there
- The collection on the controller, once:

```bash
make cpu-lab-coll-install    # downloads v0.2.0, checks sha256, installs to ansible/collections
make cpu-lab-coll-check      # offline: syntax, resolved variables, profile file present
```

## Sequence

Every step takes `BASTION=1`, which builds and probes the tunnel first. Run the
read-only state report after every step that changes something - it prints the
oratab entry, `version_full`, open mode, restore points, the last SQL patch and
the number of invalid objects.

```bash
make cpu-lab-start
make cpu-lab-coll STEP=verify BASTION=1               # baseline: 19.31, no restore point
make cpu-lab-coll STEP=setup BASTION=1
make cpu-lab-coll STEP=download BASTION=1
make cpu-lab-coll STEP=home BASTION=1
make cpu-lab-coll STEP=apply BASTION=1                # switch 19.31 -> 19.32.0.0
make cpu-lab-coll-rollback MODE=restore BASTION=1     # flashback, back to 19.31
make cpu-lab-coll STEP=apply BASTION=1                # second switch
make cpu-lab-coll-rollback MODE=home BASTION=1        # old home plus datapatch, data kept
```

Before the first step, look at the baseline. If it reports a restore point, or if
`df -h /u00` shows less than about 40 GB free, sort that out first: the profile
download includes a gold image, and the new home needs about 10 GB.

The second `apply` is deliberate. After a `restore` rollback the deploy job of
the first switch is still open in the engine's log directory. Whether the
collection starts a new deploy or AutoUpgrade resumes the old one is exactly the
behaviour molecule cannot show.

## Pass criteria

<!-- markdownlint-disable MD013 MD060 -->
| Step | Expected |
| --- | --- |
| `setup` | no GID mismatch reported, engine `VERSION` 0.6.1, `au_keystore.sh --check` ok; a second run changes nothing |
| `download` | pin file `au_patch.env` in `.../patches/2026-09_db19_linux`, `au_patch_verify.sh` ok |
| `home` | `/u00/app/oracle/product/19.32.0.0` registered in `/u00/app/oraInventory`, `au_home_verify.sh` ok |
| `apply` | oratab -> `19.32.0.0`, `version_full` 19.32, listener `LISTENER` up from the new home, `tnsnames.ora` copied, 0 new invalid objects, switch record `logs/home_switch_CPUDB.json` |
| `rollback restore` | oratab -> `19.31/dbhome_1`, `version_full` 19.31, PDBs open, autostart back on |
| second `apply` | same as the first, or a clear message why not |
| `rollback home` | oratab -> `19.31/dbhome_1`, `version_full` 19.31, last SQL patch is the 19.31 RU, utlrp done |
<!-- markdownlint-restore -->

Every deviation is a collection finding, not a lab finding. File it as an issue
in `oehrlis/oradba-ansible` (rule 7) - do not patch the installed collection.

## Clean up

The collection does not drop the restore point of a deploy (`patch-apply.md`,
"The restore point stays until it is dropped"). After the last rollback, drop it
so the fast recovery area does not fill and the next lab deploy starts clean:

```sql
-- as SYSDBA from the base home; names from the state report
select name from v$restore_point where guarantee_flashback_database = 'YES';
drop restore point <name>;
```

The collection homes and the engine tree may stay on the host until the lab is
destroyed. To reclaim space earlier, detach `product/19.32.0.0` from the
inventory and delete it. Never delete it while oratab still points at it.

## Troubleshooting

- `Unable to parse .../inventories/cpu-patch-test`: the group declaration
  `inventories/cpu-patch-test/hosts.yml` is missing
- `profile_file_exists: false` in `cpu-lab-coll-check`: `CPU_PATCH_TESTS_DIR`
  does not point at a `cpu-patch-tests` checkout
- `couldn't resolve module/action` or `unable to find playbook
  oradba.automation.*`: run `make cpu-lab-coll-install`; `ansible/ansible.cfg`
  lists `./collections` first in `collections_path`
- `UNREACHABLE` mid-run: the Bastion session was dropped - rerun with
  `BASTION=1`, which re-creates it
