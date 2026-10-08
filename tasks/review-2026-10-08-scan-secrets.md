# Secrets Scan Results - 2026-10-08

<!-- markdownlint-disable MD032 MD034 MD060 -->

**Scan Type:** Mechanical secrets scan of tracked files only  
**Scope:** 184 tracked files per `git ls-files`  
**Patterns:** credentials, API keys, tokens, passwords, private keys, OCI PAR URLs,
OCIDs, fingerprints, private IPs, email addresses, high-entropy strings  
**Reference:** docs/review-lens.md (INV-1 through INV-7), tasks/review-register.md

## Summary

No new credential leaks detected in tracked tree. All known findings from
review-register are confirmed as present or resolved per their status.

**Invariant Status:**
- INV-1 (no credentials): PASS - no token/PAR/password/key literal values found
- INV-2 (lab access expiry): INFO - not mechanically scannable (operational)
- INV-3 (git ls-files .claude): FINDINGS BELOW
- INV-4 (no real OCIDs): PASS - no real OCIDs found (RA-oci-labs-004 resolved)
- INV-5 (no new real OCIDs): PASS - no real OCIDs in current tree
- INV-6 (namespace/tenancy name decision pending): FINDINGS BELOW
- INV-7 (gitignore compliance): PASS - no .env/.tfvars/.tfstate/.ssh tracked

## Pattern Matches (Non-Critical)

### Email Addresses

| Pattern | Count | Files | Redacted Match | Notes |
|---------|-------|-------|---|---|
| stefan.oehrli@oradba.ch | 90 | author headers, docs | `...` | public contact, oradba.ch |
| mfa.notification@oradba.ch | 8 | docs/runbook-mfa-oma.md, docs/spec-iam-mfa-oma.md | `...` | example/template |
| @example.com | 6 | docs templates | `...` | placeholder template |
| @yourdomain.com | 2 | docs templates | `...` | placeholder template |

**Classification:** Author attribution and documentation examples. Not credentials.

## Known Findings - Register Verification

### RA-oci-labs-005 - Object-Storage Namespace in Tracked Tree (OFFEN)

| File | Line(s) | Pattern | Value | Tracked |
|------|---------|---------|-------|---------|
| CHANGELOG.md | (content match) | tenancy name | `<namespace>` | yes |
| docs/runbook-cpu-patch-lab.md | (7 refs) | tenancy name + bucket ref | `<namespace>` | yes |
| tasks/plan-cpu-lab.md | (1 ref) | table content | `<namespace>` | yes |
| tasks/state-2026-08-28.md | (1 ref) | bullet content | `<namespace>` | yes |
| terraform/envs/core/README.md | (1 ref) | text | `<namespace>` | yes |
| terraform/envs/core/terraform.tfvars.example | (1 ref) | comment | `<namespace>` | yes |
| terraform/envs/cpu-patch-test/.env.example | (2 refs) | comments + URL example | `<namespace>` | yes |
| terraform/envs/cpu-patch-test/README.md | (1 ref) | text | `<namespace>` | yes |
| terraform/modules/core/main.tf | (1 ref) | comment | `<namespace>` | yes |
| tools/upload_bootstrap.sh | (1 ref) | comment | `<namespace>` | yes |

**Status:** 12 total references across 10 files. Confirmed per register entry (gefunden:
2026-10-08). Namespace is identifiable from any PAR URL in the repo. Decision
pending: keep or replace with `<namespace>` placeholder. Not a credential, but
identifies the lab tenancy and object storage account.

**Classification:** INV-6 violation (identity, not credential).

## Invariant Violations Detected

### INV-3 - Missing .claude/CLAUDE.md

| File | Status | Issue |
|------|--------|-------|
| .claude/CLAUDE.md | NOT FOUND | Should be in `git ls-files .claude` alongside aitk.toml |
| .claude/aitk.toml | OK | Present and tracked |

**Expected per INV-3:** `git ls-files .claude` returns `CLAUDE.md` and `aitk.toml`  
**Actual:** Returns only `aitk.toml` (CLAUDE.md does not exist)  
**Action:** File does not exist, so no content scan needed. Structural issue only.

### OCI CLI Profile and Compartment Names in Tracked Files

| Pattern | Count | Significance | Notes |
|---------|-------|---|---|
| <profile> | 25 refs | OCI config profile name | Identifies the lab tenancy context |
| <compartment> | 16 refs | Compartment name | Identifies the lab compartment |

**Classification:** Identifiers (profile/compartment names), not credentials.
Visible in any terraform state or describe calls against the tenancy.

## Files Scanned for Secrets (Patterns Without Matches)

- Password patterns: `(password|passwd|pwd)\s*[:=]` — 0 matches
- Secret/token patterns: `(secret|token|api.?key)\s*[:=]` — 0 matches
- Private key blocks: `BEGIN.*PRIVATE KEY` — 0 matches
- OCI PAR URLs with tokens: `objectstorage.*\\.oraclecloud\\.com/p/` — 0 matches
- Real OCIDs: `ocid1\.[a-z]+\.[a-z]+\.[a-z0-9-]*\.[a-z0-9]{40,}` — 0 matches
- API key fingerprints: `fingerprint\s*[:=]` — 0 matches
- Private IPs: `(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)` — 0 matches
- Authorization headers: `(Authorization|Bearer|Basic)\s*:\s*[A-Za-z0-9+/]{20,}` — 0 matches
- High-entropy hex: `[A-Fa-f0-9]{32,}` (excluding .gitleaks.toml) — 0 matches

## Conclusion

**Tracked tree is mechanically clean of credential leaks.** Register entry
RA-oci-labs-005 (namespace in tree) is confirmed present. No new violations.
INV-3 structural issue noted (CLAUDE.md does not exist to be tracked).

## BLOCKIERT Lines

None. All mechanical scans completed; INV-3 (missing CLAUDE.md) is structural,
not a secret leak. Register findings (RA-oci-labs-001 through 013) are
acknowledged as per review-register.md.
