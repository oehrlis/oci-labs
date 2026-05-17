# Runbook: mfa_oma_setup

Runbook for the `mfa_oma_setup` Terraform stack that provisions all OCI-side
prerequisites for Oracle Database Native MFA with OMA Push (Oracle Mobile Authenticator).

The stack calls the `iam_mfa_oma` module and creates:

- OAuth Confidential Application in the OCI Identity Domain
- Dedicated SMTP IAM User and SMTP Credential
- OCI Email Delivery Approved Sender
- IAM Policy granting the SMTP user access to the email-family

DB-side configuration (ALTER SYSTEM, orapki wallet, user creation) is performed
manually after the Terraform apply using outputs from this stack.

---

## Prerequisites

Before deploying this stack, verify the following:

<!-- markdownlint-disable MD013 MD060 -->
| Requirement | Detail |
| --- | --- |
| OCI Tenancy with Identity Domain | Classic IAM tenancies are not supported |
| OCI Email Delivery available | Must be enabled in the target region (e.g. eu-zurich-1) |
| Verified email domain | The sender domain must be verified in OCI Email Delivery before or after apply |
| Terraform >= 1.3 | Check with `terraform version` |
| OCI CLI configured | `~/.oci/config` with DEFAULT or named profile |
| 1Password CLI (`op`) | For saving sensitive credentials immediately after apply |
| Oracle Database 26ai (or 19c with DBRU Jul-2025) | Docker container `labdb` with PDB `LABPDB1` for the demo environment |
<!-- markdownlint-enable MD013 MD060 -->

---

## Step 1 - Clone and Navigate

Clone the `oci-labs` repository (if not already present) and navigate to the
stack directory.

```bash
git clone https://github.com/oehrlis/oci-labs.git
cd oci-labs/terraform/envs/mfa_oma_setup
```

If you already have the repository, navigate directly:

```bash
cd /path/to/oci-labs/terraform/envs/mfa_oma_setup
```

---

## Step 2 - Configure

### 2.1 Copy example files

```bash
cp .env.example .env
cp terraform.tfvars.example terraform.tfvars
```

### 2.2 Fill .env with sensitive OCIDs

Edit `.env` and populate the three required `TF_VAR_*` variables.
Use `op read` to retrieve OCIDs from 1Password without exposing them in shell history.

```bash
# Example: retrieve OCIDs from 1Password and export them
export TF_VAR_tenancy_ocid=$(op read "op://OCI-Labs/oci-tenancy/tenancy_ocid")
export TF_VAR_compartment_ocid=$(op read "op://OCI-Labs/oci-tenancy/compartment_ocid")
export TF_VAR_identity_domain_ocid=$(op read "op://OCI-Labs/oci-tenancy/identity_domain_ocid")
```

Or store these lines in `.env` and source it before every Terraform command:

```bash
source .env
```

> Note: `.env` is git-ignored. Never commit it. Sensitive OCIDs belong in `.env`,
> not in `terraform.tfvars`.

### 2.3 Fill terraform.tfvars

Edit `terraform.tfvars` with non-sensitive configuration. The defaults match the
lab naming convention (`region_key=zrh`, `env=lab`, `stack=mfaoma`):

```hcl
# OCI provider
oci_profile = "DEFAULT"
region      = "eu-zurich-1"

# Naming convention
region_key   = "zrh"
env          = "lab"
stack        = "mfaoma"
lab_instance = 1
project_tag  = "oradba-labs"

# Email Delivery
smtp_sender_email = "labdb@yourdomain.com"
smtp_sender_name  = "Oracle DB MFA Demo"

# OAuth Application (leave empty to auto-derive from naming convention)
app_name = ""

# DKIM (optional - requires verified email domain)
create_dkim = false
```

The naming convention produces resource names like:
`app-zrh-lab-mfaoma-oauth-01`, `usr-zrh-lab-mfaoma-smtp-01`, `pol-zrh-lab-mfaoma-smtp-01`.

---

## Step 3 - Terraform Init, Plan, Apply

```bash
# Load sensitive OCIDs
source .env

# Initialise providers and backend
terraform init

# Preview what will be created (no changes applied)
terraform plan

# Apply - review the plan summary and confirm with 'yes'
terraform apply
```

Expected resources after apply:

- `oci_identity_domains_application.oauth_app` - OAuth Confidential App
- `oci_identity_user.smtp_user` - SMTP IAM user (tenancy root)
- `oci_identity_smtp_credential.smtp_cred` - SMTP credential
- `oci_email_sender.approved_sender` - Approved Sender
- `oci_identity_policy.smtp_policy` - IAM policy

---

## Step 4 - Save Credentials Immediately

> Warning: The SMTP credential password and OAuth client secret are shown only
> once after apply. If lost, you must destroy and recreate the SMTP credential
> or the OAuth app. Save them to 1Password before doing anything else.

### 4.1 Retrieve all sensitive outputs

```bash
terraform output -json
```

For specific values:

```bash
terraform output -json | jq -r '.oauth_client_id.value'
terraform output -json | jq -r '.oauth_client_secret.value'
terraform output -json | jq -r '.smtp_username.value'
terraform output -json | jq -r '.smtp_password.value'
terraform output -json | jq -r '.iam_domain_url.value'
```

### 4.2 Save to 1Password

```bash
# Save SMTP password
SMTP_PASSWORD=$(terraform output -json | jq -r '.smtp_password.value')
op item edit "OCI-Labs-MFA-OMA" --vault "OCI-Labs" "smtp_password=$SMTP_PASSWORD"

# Save OAuth client secret
OAUTH_SECRET=$(terraform output -json | jq -r '.oauth_client_secret.value')
op item edit "OCI-Labs-MFA-OMA" --vault "OCI-Labs" "oauth_client_secret=$OAUTH_SECRET"
```

Adapt the vault and item name to your 1Password structure.

### 4.3 Retrieve the DB config commands

```bash
terraform output db_mfa_config_commands
```

This prints the complete `ALTER SYSTEM` block needed in Step 6.

---

## Step 5 - Grant OAuth App Roles (manual)

> Important: Terraform creates the OAuth Confidential Application but cannot
> grant built-in admin roles. This step is always manual.

The following roles must be granted to the OAuth App:

- `MFA Client`
- `User Administrator`
- `Identity Domain Administration`

### 5.1 Via OCI Console

1. Open OCI Console and navigate to:
   **Identity & Security -> Domains -> \<your domain> -> Oracle Cloud Services**
2. Find the application (e.g. `app-zrh-lab-mfaoma-oauth-01`) and open it.
3. Click **Application Roles** in the left navigation.
4. For each role (`MFA Client`, `User Administrator`, `Identity Domain Administration`):
   - Click the role, then click **Assign App**.
   - Select your OAuth application and confirm.

### 5.2 Via OCI CLI

Retrieve the Identity Domain URL from Terraform output first:

```bash
IDCS_URL=$(terraform output -json | jq -r '.iam_domain_url.value')
```

List available app roles to find the correct role OCIDs:

```bash
oci identity-domains app-role list \
  --idcs-endpoint "$IDCS_URL" \
  --filter "displayName sw \"MFA\"" \
  --query 'data.resources[*].{name:displayName, id:id}' \
  --output table
```

Grant a role by assigning the app as a grantee (replace `<APP_OCID>` and `<ROLE_ID>`):

```bash
oci identity-domains grant create \
  --idcs-endpoint "$IDCS_URL" \
  --grant-mechanism "ADMINISTRATOR_TO_APP" \
  --grantee '{"type": "App", "value": "<APP_OCID>"}' \
  --app-entitlement-collection \
    '{"entitlements": [{"name": "appRoles", "attributeString": "<ROLE_ID>"}]}'
```

Repeat for each of the three required roles.

---

## Step 6 - Configure Oracle Database

All DB-side steps run inside the Docker container `labdb` with PDB `LABPDB1`.

### 6.1 Set MFA System Parameters

Run the ALTER SYSTEM commands from Terraform output as SYSDBA:

```bash
terraform output db_mfa_config_commands
```

Connect to the database and execute the output:

<!-- markdownlint-disable MD013 -->
```sql
CONN sys/Oracle123@localhost:1521/LABPDB1 AS SYSDBA

-- Paste the terraform output db_mfa_config_commands here, e.g.:
ALTER SYSTEM SET MFA_OMA_IAM_DOMAIN_URL = 'https://idcs-xxx.identity.oraclecloud.com' SCOPE=BOTH;
ALTER SYSTEM SET MFA_SMTP_HOST          = 'smtp.email.eu-zurich-1.oci.oraclecloud.com' SCOPE=BOTH;
ALTER SYSTEM SET MFA_SMTP_PORT          = 587 SCOPE=BOTH;
ALTER SYSTEM SET MFA_SENDER_EMAIL_ID    = 'labdb@yourdomain.com' SCOPE=BOTH;
```
<!-- markdownlint-enable MD013 -->

Also set the display name (not included in Terraform output):

```sql
ALTER SYSTEM SET MFA_SENDER_EMAIL_DISPLAYNAME = 'Oracle DB MFA Demo' SCOPE=BOTH;
```

Adjust the SQLNET timeout so that push approval time does not cause a connect timeout:

```bash
docker exec -it labdb bash -c \
  "echo 'SQLNET.INBOUND_CONNECT_TIMEOUT=120' >> \$TNS_ADMIN/sqlnet.ora"
```

### 6.2 Determine PDB GUID for Wallet Path

<!-- markdownlint-disable MD013 -->
```bash
docker exec -it labdb sqlplus -s sys/Oracle123@localhost:1521/LABPDB1 as sysdba <<'EOF'
SELECT guid FROM v$pdbs WHERE name = 'LABPDB1';
EOF
```
<!-- markdownlint-enable MD013 -->

Set the shell variable for use in subsequent commands:

```bash
PDB_GUID="<GUID from above query>"
WALLET_ROOT="/opt/oracle/dcs/commonstore/wallets"
```

### 6.3 Create MFA Wallet

```bash
docker exec -it labdb bash -c "
  mkdir -p ${WALLET_ROOT}/${PDB_GUID}/mfa &&
  orapki wallet create -wallet ${WALLET_ROOT}/${PDB_GUID}/mfa -auto_login
"
```

### 6.4 Store OAuth Credentials in Wallet

Retrieve the values from 1Password or from `terraform output -json`:

```bash
CLIENT_ID=$(terraform output -json | jq -r '.oauth_client_id.value')
CLIENT_SECRET=$(op read "op://OCI-Labs/OCI-Labs-MFA-OMA/oauth_client_secret")
```

Store them in the wallet:

```bash
docker exec -it labdb bash -c "
  orapki secretstore create_credential \
    -wallet ${WALLET_ROOT}/${PDB_GUID}/mfa \
    -connect_string oracle.security.mfa.oma.clientid \
    -username ignored \
    -password '${CLIENT_ID}'
"
```

```bash
docker exec -it labdb bash -c "
  orapki secretstore create_credential \
    -wallet ${WALLET_ROOT}/${PDB_GUID}/mfa \
    -connect_string oracle.security.mfa.oma.clientsecret \
    -username ignored \
    -password '${CLIENT_SECRET}'
"
```

### 6.5 Store SMTP Credentials in Wallet

```bash
SMTP_USER=$(terraform output -json | jq -r '.smtp_username.value')
SMTP_PASS=$(op read "op://OCI-Labs/OCI-Labs-MFA-OMA/smtp_password")
```

```bash
docker exec -it labdb bash -c "
  orapki secretstore create_credential \
    -wallet ${WALLET_ROOT}/${PDB_GUID}/mfa \
    -connect_string oracle.security.mfa.smtp.user \
    -username ignored \
    -password '${SMTP_USER}'
"
```

```bash
docker exec -it labdb bash -c "
  orapki secretstore create_credential \
    -wallet ${WALLET_ROOT}/${PDB_GUID}/mfa \
    -connect_string oracle.security.mfa.smtp.password \
    -username ignored \
    -password '${SMTP_PASS}'
"
```

---

## Step 7 - Validate

### 7.1 Check MFA Parameters in Database

```sql
CONN sys/Oracle123@localhost:1521/LABPDB1 AS SYSDBA

SELECT name, value
FROM   v$parameter
WHERE  name LIKE 'mfa%'
ORDER BY name;
```

Expected parameters with non-null values:

- `mfa_oma_iam_domain_url`
- `mfa_smtp_host`
- `mfa_smtp_port`
- `mfa_sender_email_id`
- `mfa_sender_email_displayname`

### 7.2 Verify Wallet Contents

```bash
docker exec -it labdb bash -c "
  orapki wallet display -wallet ${WALLET_ROOT}/${PDB_GUID}/mfa
"
```

Confirm that the four `oracle.security.mfa.*` credential entries appear.

### 7.3 Create Test User and Trigger OMA Registration Email

```sql
CONN sys/Oracle123@localhost:1521/LABPDB1 AS SYSDBA

-- Create a user with OMA Push as second factor.
-- AND FACTOR triggers the OMA registration email immediately.
CREATE USER mfademo
    IDENTIFIED BY "Oracle123!"
    AND FACTOR 'OMA_PUSH' AS 'your.email@example.com';

GRANT CREATE SESSION TO mfademo;
```

Check that the registration email is delivered to `your.email@example.com`.
The email contains a QR code to register with the Oracle Mobile Authenticator app.

### 7.4 Verify MFA Status in DBA_USERS

```sql
SELECT username, mfa, external_name
FROM   dba_users
WHERE  username = 'MFADEMO';
```

### 7.5 Test MFA Login

After registering in the OMA app, test the login:

```bash
sqlplus mfademo/"Oracle123!"@localhost:1521/LABPDB1
```

Expected output:

```text
Confirm login in authenticator app
```

Approve the push notification in the OMA app. The SQL*Plus session opens after approval.

Verify MFA context inside the session:

```sql
SELECT SYS_CONTEXT('USERENV', 'MULTIFACTOR_AUTHENTICATION_METHODS') AS mfa_method
FROM   dual;
```

Expected value: `OMA_PUSH`.

---

## Teardown

### Remove Terraform Resources

```bash
source .env
terraform destroy
```

Confirm with `yes` when prompted. This removes:

- OAuth Confidential Application
- SMTP IAM User and SMTP Credential
- Approved Sender
- IAM Policy

> Note: Destroy does not revoke OMA registrations on user accounts.
> Clean up test users in the database before running destroy.

### Clean Up Database Users

```sql
CONN sys/Oracle123@localhost:1521/LABPDB1 AS SYSDBA

DROP USER mfademo CASCADE;
```

### Remove DB MFA Wallet

```bash
docker exec -it labdb bash -c "
  rm -rf ${WALLET_ROOT}/${PDB_GUID}/mfa
"
```

### Reset MFA System Parameters

```sql
CONN sys/Oracle123@localhost:1521/LABPDB1 AS SYSDBA

ALTER SYSTEM RESET MFA_OMA_IAM_DOMAIN_URL SCOPE=BOTH;
ALTER SYSTEM RESET MFA_SMTP_HOST          SCOPE=BOTH;
ALTER SYSTEM RESET MFA_SMTP_PORT          SCOPE=BOTH;
ALTER SYSTEM RESET MFA_SENDER_EMAIL_ID    SCOPE=BOTH;
ALTER SYSTEM RESET MFA_SENDER_EMAIL_DISPLAYNAME SCOPE=BOTH;
```

---

## Troubleshooting

<!-- markdownlint-disable MD013 MD060 -->
| Symptom | Likely Cause | Fix |
| --- | --- | --- |
| `Error: 404 Not Found` on `oci_identity_domains_application` | `identity_domain_ocid` is wrong or domain is in a different region | Verify the OCID in OCI Console under Identity & Security -> Domains |
| `Error: Conflict` on `oci_email_sender` | Approved Sender already exists in the compartment | Remove the existing sender manually in OCI Console or import it: `terraform import oci_email_sender.approved_sender <ocid>` |
| `Error: 409` on `oci_identity_user` | SMTP user name already exists in the tenancy | Change `stack` or `lab_instance` in `terraform.tfvars` to generate a different name |
| `terraform output db_mfa_config_commands` shows blank or error | Outputs are sensitive; plain `terraform output` hides them | Use `terraform output -json` or `terraform output db_mfa_config_commands` |
| SMTP credential password not visible after apply | Password output is sensitive and truncated in CLI | Use `terraform output -json \| jq -r '.smtp_password.value'` immediately after apply |
| OMA registration email not received | Sender domain not verified, SMTP credential wrong, or IAM policy missing | Check Approved Sender status in OCI Console; verify wallet entries with `orapki wallet display` |
| `ORA-12170: TNS:Connect timeout occurred` during MFA login | `SQLNET.INBOUND_CONNECT_TIMEOUT` too short for push approval | Set `SQLNET.INBOUND_CONNECT_TIMEOUT=120` in `$TNS_ADMIN/sqlnet.ora` and restart listener |
| `ORA-03113: end-of-file on communication channel` during MFA login | Push notification rejected or timed out | User must approve push in OMA app within the timeout window |
| `ORA-28000` or login fails after CREATE USER AND FACTOR | OMA roles not granted on OAuth App | Repeat Step 5 - grant MFA Client, User Administrator, Identity Domain Administration |
| `orapki secretstore create_credential` fails | Wallet does not exist or path is wrong | Verify `$WALLET_ROOT/$PDB_GUID/mfa` exists; re-run `orapki wallet create` |
<!-- markdownlint-enable MD013 MD060 -->

---

## References

- Oracle MFA Tutorial: <https://docs.oracle.com/en/learn/mfa-db23ai-oma/>
- Spec: `docs/spec-iam-mfa-oma.md`
- Module README: `terraform/modules/iam_mfa_oma/README.md`
- Talk Demo Guide: `[talk demo guide](../../../../talks/oracle-db-mfa/demos.md)`
