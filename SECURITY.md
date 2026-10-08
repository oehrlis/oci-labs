# Security Policy

## Scope

`oci-labs` builds disposable lab environments on OCI. Relevant reports are, for
example:

- a credential, token, pre-authenticated request (PAR) URL or private key in the
  repository or its git history
- Terraform or Ansible defaults that expose a lab more than documented (public IPs,
  open security lists, buckets, missing expiry on access)
- a Makefile target or script that leaks a secret into logs or files

The labs are not production systems and hold no customer data.

## Reporting

Please do **not** open a public issue for a security problem. Report it privately:

- GitHub: "Report a vulnerability" on the repository's Security tab, if enabled
- E-mail: <stefan.oehrli@oradba.ch>

Include the file and commit, and never the secret value itself. You get an answer
within a few working days.

## Known history

The git history contains reviewed and accepted findings from before the secret scan
existed (an expired, time-limited PAR URL and OCI identifiers). They are documented in
`tasks/review-register.md` and allowlisted in `.gitleaks.toml` by commit, path and rule.
A finding outside that list is new - please report it.

## Safeguards

- `.gitleaks.toml`: gitleaks defaults plus rules for OCI PAR URLs, OCIDs and API key
  fingerprints
- CI: `.github/workflows/gitleaks.yml` scans the full history on every push and pull
  request
- Local: `make hooks` installs the pre-commit scan, `make lint-secrets` runs the history
  scan
