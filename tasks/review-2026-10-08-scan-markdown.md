# Markdown Scan - 2026-10-08

**Date:** 2026-10-08  
**Commit:** fb5bedb  
**Tool:** markdownlint v0.49.1  
**Config:** `.markdownlint.json` (line_length: 120, MD013 disabled for code_blocks/tables, MD033: false)  
**Ignore file:** `.markdownlintignore` (ansible/reports/, node_modules/, .terraform/)  
**Tracked .md files:** 41  

## Markdownlint Rule Violations

<!-- markdownlint-disable MD013 MD060 -->

| Rule         | Count | Examples       |
| ------------ | ----- | -------------- |
| **(all)** | **0** | None - clean run |

<!-- markdownlint-restore -->

## MD041: First Line Not H1 Heading

**Count:** 6 files with empty or non-heading first line

<!-- markdownlint-disable MD013 MD060 -->

| File                               | First Line Content |
| ---------------------------------- | ------------------ |
| ansible/docs/ansible-workflow.md   | (empty)            |
| ansible/docs/architecture-config.md | (empty)           |
| ansible/docs/profiles-overview.md  | (empty)            |
| ansible/inventories/README.md      | (empty)            |
| docs/lab-odb19eng-single.md        | (empty)            |
| docs/lab-odb19sec-dg.md            | (empty)            |

<!-- markdownlint-restore -->

## Missing Code Block Language Specifiers

**Count:** 197 bare triple-backtick code fences (no language specified)

<!-- markdownlint-disable MD013 MD060 -->

| File                            | Count | Line Examples                                             |
| ------------------------------- | ----- | --------------------------------------------------------- |
| docs/architecture-overview.md   | 10    | 59, 69, 98, 152, 175, 194, 214, 228, 248, 255            |
| docs/namingconcept.md           | 13    | 22, 28, 114, 121, 129, 135, 141, 148, 154, 170, 187, ... |
| docs/runbook-ad-cmu-lab.md      | 29    | 58, 120, 126, 151, 160, 168, 181, 192, 201, 225, 245, ... |
| docs/runbook-cpu-patch-lab.md   | 32    | (30+ instances)                                            |
| docs/runbook-mfa-oma.md         | 50    | (50+ instances)                                            |
| docs/spec-iam-mfa-oma.md        | 12    | (12 instances)                                             |
| tasks/plan-cpu-lab.md           | 6     | (6 instances)                                              |
| tasks/roadmap-cpu-lab.md        | 3     | (3 instances)                                              |
| tasks/state-2026-08-24.md       | 1     | (1 instance)                                               |
| tasks/state-2026-08-28.md       | 1     | (1 instance)                                               |
| tasks/state-cpu-lab-2026-08-19.md | 2   | (2 instances)                                              |
| tasks/state-cpu-lab-2026-08-21.md | 4   | (4 instances)                                              |
| tasks/state-cpu-lab-2026-08-23.md | 5   | (5 instances)                                              |
| tasks/todo.md                   | 1     | (1 instance)                                               |
| terraform/envs/core/README.md   | 2     | (2 instances)                                              |
| terraform/envs/cpu-patch-test/README.md | 5 | (5 instances)                                          |
| terraform/envs/mfa_oma_setup/README.md | 4 | (4 instances)                                         |
| terraform/modules/iam_mfa_oma/README.md | 9 | (9 instances)                                        |
| terraform/modules/naming/README.md | 1  | (1 instance)                                               |
| terraform/modules/network/README.md | 1 | (1 instance)                                               |
| terraform/modules/oracle_db_host/README.md | 2 | (2 instances)                                   |

<!-- markdownlint-restore -->

*Note:* Bare fences should specify language (bash, sql, hcl, yaml, json, markdown, etc.)
per `.claude/rules/markdown-lint.md`.

## Em-Dash / En-Dash Characters (— instead of -)

**Count:** 19 instances in 4 files (em-dash U+2014)

<!-- markdownlint-disable MD013 MD060 -->

| File                            | Line | Context                                                    |
| ------------------------------- | ---- | ---------------------------------------------------------- |
| docs/runbook-mfa-oma.md         | 22   | `subgraph OCI["OCI Tenancy — Terraform-managed"]`         |
| docs/runbook-mfa-oma.md         | 43   | `subgraph ODB["Oracle Database 23.9+ — manual steps"]`    |
| docs/runbook-mfa-oma.md         | 68   | Table header with em-dash in description                 |
| docs/runbook-mfa-oma.md         | 70   | Table header with em-dash in description                 |
| docs/runbook-mfa-oma.md         | 72   | Table header with em-dash in description                 |
| docs/runbook-mfa-oma.md         | 82   | `Phase 1 — Create domain + sender`                        |
| docs/runbook-mfa-oma.md         | 89   | `Phase 2 — Verify domain in OCI Console`                 |
| docs/runbook-mfa-oma.md         | 92   | `Phase 3 — Enable DKIM`                                   |
| docs/runbook-mfa-oma.md         | 190  | Heading with em-dash separator                            |
| docs/runbook-mfa-oma.md         | 194  | Heading with em-dash separator                            |
| docs/runbook-mfa-oma.md         | 447  | password and store in 1Password — needed for ...          |
| docs/runbook-mfa-oma.md         | 503  | Oracle DB TLS stack uses MFA wallet — not OS CA ...       |
| docs/runbook-mfa-oma.md         | 538  | Verify — wallet must show four secret store ...           |
| docs/runbook-mfa-oma.md         | 671  | automatically — manual cleanup only when ...              |
| docs/runbook-mfa-oma.md         | 786  | Table cell with em-dash in content                       |
| docs/spec-iam-mfa-oma.md        | 255  | Domain-Verifizierung (DKIM/DNS) — manuell oder ...        |
| docs/spec-iam-mfa-oma.md        | 257  | Cisco Duo Integration — separates Modul später            |
| docs/spec-iam-mfa-oma.md        | 258  | Certificate-based MFA — separates Modul später            |
| terraform/modules/iam_mfa_oma/README.md | 170 | credentials as username/password — NOT separate ...   |

<!-- markdownlint-restore -->

*Note:* Per `.claude/rules/markdown-lint.md`, use hyphen-minus ` - ` only, never
em-dash or en-dash.

## Broken Relative Links (./path syntax)

**Count:** 0 relative links found

## Tracked .md Files Excluded by .markdownlintignore

**Count:** 0

The ignore file excludes `ansible/reports/`, `node_modules/`, and `.terraform/`, but
these contain no tracked markdown files (tracked files verified via `git ls-files`).

## Summary

- **markdownlint rule violations:** 0 (clean run, all rules)
- **MD041 (no H1):** 6 files
- **Missing code block language:** 197 bare code fences
- **Em-dash/en-dash usage:** 19 instances across 4 files
- **Broken relative links:** 0
- **Tracked files excluded by ignore:** 0

## Known Register Entries

Not re-reported:

- RA-oci-labs-013: markdownlint runs locally but not in CI (separate finding)
