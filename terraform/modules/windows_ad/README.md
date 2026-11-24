# windows_ad module

Provisions a Windows Server 2022 domain controller (stack code `windc`) with an instance NSG.
cloudbase-init sets the Administrator password, downloads the
[ad-lab](https://github.com/oehrlis/ad-lab) scripts, promotes the forest and runs the lab setup in a
second phase after the reboot. Used by [`envs/ad-cmu-test`](../../envs/ad-cmu-test/).

## Network access

The NSG opens RDP, WinRM, LDAP/LDAPS, Kerberos, DNS and the Global Catalog only for:

- `vcn_cidr` - all hosts inside the VCN (skipped when `null`)
- `allowed_cidrs` - explicit external sources, default `[]` (no ingress from outside the VCN)

NSG and Security List rules are evaluated as a union. An NSG rule with source `0.0.0.0/0` would
therefore override every restriction in the subnet Security List - `allowed_cidrs` rejects it.
Home or VPN networks routed via the DRG are already allowed by the Security List of the
[`network`](../network/README.md) module (`home_cidrs`) and need no entry here.

## Inputs

<!-- markdownlint-disable MD013 -->

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `vcn_cidr` | string | `null` | VCN CIDR, NSG source for all AD ports. |
| `allowed_cidrs` | list(string) | `[]` | Additional NSG sources, IPv4 CIDR, never `0.0.0.0/0`. |
| `ad_lab_scripts_ref` | string | pinned commit | Full 40-character commit SHA of ad-lab. Branch names are rejected. |
| `ad_lab_scripts_sha256` | string | hash of the pinned archive | SHA-256 of the archive for that commit; `""` skips the check. |
| `admin_password_secret` | string | - | Administrator password, sensitive. Pass via `TF_VAR_admin_password_secret`. |

<!-- markdownlint-restore -->

The remaining inputs (compartment, subnet, shape, image, domain) are described in
[`variables.tf`](variables.tf).

## Pinned ad-lab scripts

The bootstrap runs the ad-lab scripts as Administrator, so the download is pinned to a commit and
the archive is checked against `ad_lab_scripts_sha256` before it is unpacked. To move to a newer
ad-lab version, set both values together:

```bash
sha=<40-character commit SHA>
curl -sL "https://github.com/oehrlis/ad-lab/archive/${sha}.zip" | shasum -a 256
```

## Administrator password handling

- The password is passed base64-encoded in `user_data`. Base64 is not encryption.
- **Instance metadata stays readable for the lifetime of the instance.** Anyone who can read
  instance metadata (IMDS from inside the DC, or `oci compute instance get` with read access to
  the instance) can recover the password. OCI offers no way to drop `user_data` after the first
  boot. Treat the password as lab-only and rotate it when the DC is kept longer than a demo.
- Phase 1 clears its password variables after setting the account.
- `C:\OraLab\Scripts\00_init_environment.ps1` holds the password while the automatic setup runs.
  At the end of a successful phase 2 the password line is replaced: manual scripts such as
  `27_config_cmu.ps1` then read `$env:LAB_ADMIN_PASSWORD` or prompt for the password. If
  phase 2 fails, the file keeps the password for a re-run - remove it by hand once done.
- Known residue outside this module: the pinned ad-lab `01_install_ad_role.ps1` logs the
  password at DEBUG level (hidden unless debug logging is switched on) - to be fixed in ad-lab.

### Follow-up: password from OCI Vault

The clean fix is to keep the password out of metadata altogether: store it as an OCI Vault
secret, pass only the secret OCID in `user_data`, and let the DC read it at boot with an instance
principal (dynamic group matching the instance, policy `read secret-bundles` on that one secret).
On Windows that needs the OCI CLI or a signed REST call during cloudbase-init. Not built yet.
