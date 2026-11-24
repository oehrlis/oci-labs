# Stack: mfa_oma_setup

Deployable Terraform stack for Oracle Database Native MFA with OMA Push.
Calls the `iam_mfa_oma` module to provision all OCI-side prerequisites.

## Prerequisites

Self-contained: this directory plus the module `../../modules/iam_mfa_oma` and the
runbook `docs/runbook-mfa-oma.md` of this repository. Nothing else is downloaded
except the OCI provider.

OCI:

- OCI Tenancy with Identity Domain (not classic IAM)
- OCI Email Delivery available in the target region
- Email domain verified in OCI Email Delivery (or let the stack create it with
  `create_email_domain = true` and add the DNS TXT record, see the runbook)
- An OCI user allowed to create IAM users, groups and policies in the tenancy root,
  an integrated application in the Identity Domain, and Approved Senders in the
  target compartment - in a lab tenancy: a tenancy administrator. The role grants
  after the apply (step 2) need Identity Domain administrator rights

Tools:

- Terraform >= 1.3 and OCI provider 8.x (`~> 8.0`, tested with 8.28.0 and
  Terraform 1.17)
- OCI CLI configured (`~/.oci/config`, profile DEFAULT or named)
- `jq` for the output commands below; `python3` for the `oci raw-request`
  role grants in the runbook

Database:

- Oracle AI Database 26ai RU 23.9 or later (tested with 26ai Free 23.26.1,
  23.26.3 and 23.26.4 in a container, ARM64) or Oracle Database 19c RU 19.28 or
  later (DB side not tested with 19c in this repository)
- Outbound HTTPS to the Identity Domain and SMTP (port 587) to OCI Email Delivery
  from the database host
- The Oracle Mobile Authenticator app on a phone for the user's enrollment

## Deployment

```bash
cd terraform/envs/mfa_oma_setup

# 1. Copy and fill config files
cp terraform.tfvars.example terraform.tfvars
cp .env.example .env
# Edit terraform.tfvars and .env with your values

# 2. Load sensitive OCIDs
source .env

# 3. Deploy
terraform init
terraform plan
terraform apply
```

## Post-apply steps

### 1. Save sensitive credentials

```bash
# Show all sensitive outputs
terraform output -json | jq '{
  oauth_client_id:     .oauth_client_id.value,
  oauth_client_secret: .oauth_client_secret.value,
  smtp_username:       .smtp_username.value,
  smtp_password:       .smtp_password.value
}'
```

### 2. Grant OAuth App roles (required for OMA Push)

> Note: Custom apps appear under **Integrated Applications**, not Oracle Cloud Services.

Navigate to: **OCI Console -> Identity & Security -> Domains ->
\<your domain> -> Integrated Applications -> \<app-name> -> Application Roles**

Grant the following roles:

- MFA Client
- User Administrator
- Identity Domain Administrator

See the [Runbook Step 5](../../../docs/runbook-mfa-oma.md#step-5---grant-oauth-app-roles-manual)
for CLI commands using `oci raw-request`.

### 3. Configure Oracle Database

```bash
# Copy-paste ready SQL: MFA parameters and the SMTP credential
terraform output db_mfa_config_commands
```

The database side has three parts (Oracle AI Database 26ai, RU 23.9+):

1. MFA parameters in the PDB - the `ALTER SYSTEM` lines of the output.
2. SMTP credential - `DBMS_CREDENTIAL.CREATE_CREDENTIAL('MFA_SMTP_CREDENTIAL$', ...)`
   in the same PDB (template in the output). 26ai does **not** read SMTP
   credentials from the wallet; without this step `CREATE USER ... AND FACTOR
   'OMA_PUSH'` fails with `ORA-28474`.
3. MFA wallet `WALLET_ROOT/<PDB GUID>/mfa` with the OAuth client only, stored with
   `orapki secretstore create_entry -alias oracle.security.mfa.oma.clientid` and
   `... -alias oracle.security.mfa.oma.clientsecret`.

Then create the user (`CREATE USER ... IDENTIFIED BY ... AND FACTOR 'OMA_PUSH' AS
'<mail>'`) - the enrollment mail with the QR code for the Oracle Mobile
Authenticator app follows. Full procedure, verification and troubleshooting:
[Runbook Steps 6-7](../../../docs/runbook-mfa-oma.md#step-6---configure-oracle-database).
Tested 2026-11-23 with Oracle AI Database 26ai Free 23.26.x in a container.

## Teardown

```bash
source .env
terraform destroy
```

## References

- [Oracle AI Database 26ai Security Guide - Configuring Multi-Factor Authentication](https://docs.oracle.com/en/database/oracle/oracle-database/26/dbseg/configuring-multi-factor-authentication.html)
- [Oracle MFA Tutorial](https://docs.oracle.com/en/learn/mfa-db23ai-oma/) - 23ai era; its SMTP wallet
  aliases are not read by 26ai
- [Module README](../../modules/iam_mfa_oma/README.md)
- [Runbook](../../../docs/runbook-mfa-oma.md)
