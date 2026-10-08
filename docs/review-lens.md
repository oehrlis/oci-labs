# Review-Linse - oci-labs

> Fuer /repo-audit. Kurz halten (15-35 Zeilen). Invarianten-IDs nie neu vergeben.

## Kronjuwelen

- MOS-Zugangsdaten, SSH-Keys, Lab-Passwoerter, OCI-API-Keys, PAR-Tokens
- Terraform-State und `.env` der Lab-Envs (enthalten Keys, PARs und alle OCIDs)
- Struktur der Lab-Tenancy (OCIDs, Namespace, Compartments) - das Repo ist public

## Invarianten

- INV-1: kein Credential (Token, PAR, Passwort, Private Key) im Baum - Secrets nur per `op read` zur Laufzeit
- INV-2: kein Lab-Zugang ohne Ablauf - PARs mit Ablaufdatum, Bastion-Sessions mit TTL, Labs mit Auto-Stop
- INV-3: `git ls-files .claude` liefert hoechstens `CLAUDE.md` und `aitk.toml` (hier liegt CLAUDE.md im Root)
- INV-4: keine echten OCIDs oder API-Key-Fingerprints im Baum - Platzhalter wie `<compartment_ocid>`
- INV-5: keine echten OCIDs oder Fingerprints in neuen Commits; bekannte Altlasten nur ueber das Register
- INV-6: Tenancy-Namespace und Tenancy-Namen nur nach Owner-Entscheid im Baum
- INV-7: `*.tfstate`, `terraform.tfvars`, `.env`, `.ssh/` bleiben gitignoriert

Zuordnung beim History-Scan: Credential in der Historie -> `history`, Identifikator
(OCID, Fingerprint) in der Historie -> `INV-5`, im Baum -> `INV-1` bzw. `INV-4`.

## Sensible Namen

- Public Repo - hier nur die Klassen, keine Namen: Object-Storage-Namespace und Name des
  Lab-Tenants, OCI-CLI-Profilnamen, Compartment-Namen, Kurznamen von Arbeitgeber und Kunden
- Die konkrete Liste fuer den Hand-Grep liegt privat in
  `~/notes/docs/repo-audit-framework.md`; Fallback-Muster: `ocid1\.|objectstorage\.`

## Bedrohungsmodell

Ein Leser des public Repos (oder seiner Historie) findet ein Credential oder genug
Tenancy-Struktur, um eine vergessene Lab-Instanz anzugreifen. Ein Lab ist schnell
aufgesetzt und lange vergessen - offene Instanz, Default-Passwort, echte Tenancy.

## Nicht-Ziele

- keine Produktionsumgebung, keine Kundendaten, kein Mehrmandanten-Betrieb
- kein Remote-State-Backend - State bleibt lokal und gitignoriert

## Bekannte Altlasten

- Historie: RA-oci-labs-001, RA-oci-labs-002, RA-oci-labs-003 (akzeptiert, siehe Register)

## Verifikation

- `make lint` (terraform fmt/validate, ansible-lint, yamllint, markdownlint, shellcheck, gitleaks)
- `gitleaks git --config .gitleaks.toml --redact --log-opts=--all .`
- `git check-ignore -q terraform/envs/cpu-patch-test/terraform.tfstate`
- `aitk repo hygiene .`
