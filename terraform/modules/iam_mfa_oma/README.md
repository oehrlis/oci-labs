# Module: iam_mfa_oma

Terraform module for the OCI-side prerequisites of Oracle Database Native MFA
with OMA Push (Oracle Mobile Authenticator).

## What this module creates

| Resource | Description |
|---|---|
| `oci_identity_domains_app` | OAuth 2.0 Confidential Application in Identity Domain |
| `oci_identity_user` | Dedicated SMTP IAM user (tenancy root) |
| `oci_identity_group` | IAM group for the SMTP user (required for group-based policy) |
| `oci_identity_user_group_membership` | Binds SMTP user to the SMTP group |
| `oci_identity_smtp_credential` | SMTP credential bound to the SMTP user |
| `oci_email_sender` | Approved Sender in OCI Email Delivery |
| `oci_email_dkim` | DKIM record (optional, `create_dkim = true`) |
| `oci_identity_policy` | Policy allowing SMTP group to use email-family |

## What this module does NOT create

- Oracle Database resources (Compute, VCN, DB itself)
- Email domain verification - must be done manually before `create_dkim = true`
- DB-side configuration (`ALTER SYSTEM`, wallet, user grants)

## Usage

```hcl
module "iam_mfa_oma" {
  source = "../../modules/iam_mfa_oma"

  tenancy_ocid         = var.tenancy_ocid
  compartment_ocid     = var.compartment_ocid
  identity_domain_ocid = var.identity_domain_ocid
  region               = "eu-zurich-1"
  smtp_sender_email    = "mfa.notification@oradba.ch"
}
```

## Post-apply: grant OAuth App roles

After `terraform apply`, grant the following roles to the OAuth application.

> Note: Custom apps appear under **Integrated Applications**, not Oracle Cloud Services.

OCI Console: **Identity & Security -> Domains -> \<Domain> -> Integrated Applications ->
\<app-name> -> Application Roles**

Required roles:

- MFA Client
- User Administrator
- Identity Domain Administrator

**OCI CLI equivalent (uses `raw-request` - `oci identity-domains` has no grant subcommand):**

```bash
IDCS=$(terraform output -raw iam_domain_url | sed 's/:443//')
OCI_PROFILE="DEFAULT"

# Look up app ID
APP_ID=$(oci raw-request --profile "$OCI_PROFILE" --http-method GET \
  --target-uri "${IDCS}/admin/v1/Apps?filter=displayName+eq+%22$(terraform output -raw oauth_client_id)%22" \
  2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['Resources'][0]['id'])")

# Look up role IDs
for ROLE in "MFA+Client" "User+Administrator" "Identity+Domain+Administrator"; do
  ROLE_ID=$(oci raw-request --profile "$OCI_PROFILE" --http-method GET \
    --target-uri "${IDCS}/admin/v1/AppRoles?filter=displayName+eq+%22${ROLE}%22" \
    2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['Resources'][0]['id'])")
  oci raw-request --profile "$OCI_PROFILE" --http-method POST \
    --target-uri "${IDCS}/admin/v1/Grants" \
    --request-body "{
      \"schemas\": [\"urn:ietf:params:scim:schemas:oracle:idcs:Grant\"],
      \"grantMechanism\": \"ADMINISTRATOR_TO_APP\",
      \"app\": {\"value\": \"IDCSAppId\"},
      \"entitlement\": {\"attributeName\": \"appRoles\", \"attributeValue\": \"${ROLE_ID}\"},
      \"grantee\": {\"type\": \"App\", \"value\": \"${APP_ID}\"}
    }" 2>/dev/null | python3 -c "
import sys,json; d=json.load(sys.stdin)
print('OK:', d['data'].get('id','?')) if d['data'].get('id') else print('ERROR:', d['data'].get('detail','?'))
"
done
```

## Resources

### OAuth Confidential Application

**Terraform:** `oci_identity_domains_app.oauth_app`

```bash
IDCS=$(terraform output -raw iam_domain_url | sed 's/:443//')
oci raw-request --http-method POST \
  --target-uri "${IDCS}/admin/v1/Apps" \
  --request-body '{
    "schemas": ["urn:ietf:params:scim:schemas:oracle:idcs:App"],
    "displayName": "oracle-db-mfa",
    "basedOnTemplate": {"value": "CustomWebAppTemplateId"},
    "isOAuthClient": true,
    "allowedGrants": ["client_credentials"],
    "clientType": "confidential",
    "active": true
  }'
```

### SMTP User

**Terraform:** `oci_identity_user.smtp_user`

```bash
oci iam user create \
  --name "usr-zrh-lab-mfaoma-smtp-01" \
  --description "SMTP user for Oracle DB MFA email delivery" \
  --email "mfa.notification@oradba.ch" \
  --compartment-id "$TENANCY_OCID"
```

### SMTP Credential

**Terraform:** `oci_identity_smtp_credential.smtp_cred`

```bash
USER_OCID=$(terraform output -raw smtp_user_ocid)
oci iam smtp-credential create \
  --description "SMTP credential for usr-zrh-lab-mfaoma-smtp-01" \
  --user-id "$USER_OCID"
```

### Approved Sender

**Terraform:** `oci_email_sender.approved_sender`

```bash
oci email sender create \
  --compartment-id "$COMPARTMENT_OCID" \
  --email-address "mfa.notification@oradba.ch"
```

### IAM Group + Membership

**Terraform:** `oci_identity_group.smtp_group`, `oci_identity_user_group_membership.smtp_membership`

```bash
# Identity Domain tenancies reject "Allow user" policies - group required
oci iam group create \
  --compartment-id "$TENANCY_OCID" \
  --name "grp-zrh-lab-mfaoma-smtp-01" \
  --description "Group for SMTP user - Oracle DB MFA email delivery"

oci iam group add-user \
  --group-id "$GROUP_OCID" \
  --user-id "$(terraform output -raw smtp_user_ocid)"
```

### IAM Policy

**Terraform:** `oci_identity_policy.smtp_policy`

```bash
oci iam policy create \
  --compartment-id "$TENANCY_OCID" \
  --name "pol-zrh-lab-mfaoma-smtp-01" \
  --description "Allow SMTP group to use email-family" \
  --statements '["Allow group grp-zrh-lab-mfaoma-smtp-01 to use email-family in compartment id COMPARTMENT_OCID"]'
```

### DB MFA Wallet (post-apply, manual)

Oracle DB MFA requires a wallet per PDB. Use the **service URL as connect string**
with the actual credentials as username/password — NOT separate entries per field.

```bash
WALLET_ROOT="<value of wallet_root DB parameter>"
PDB_GUID="<SELECT guid FROM v\$pdbs WHERE name = 'YOUR_PDB'>"
WALLET="${WALLET_ROOT}/${PDB_GUID}/mfa"
IDCS=$(terraform output -raw iam_domain_url)
SMTP_HOST=$(terraform output -raw smtp_host)
CLIENT_ID=$(terraform output -raw oauth_client_id)
CLIENT_SECRET="<from 1Password>"
SMTP_USER=$(terraform output -raw smtp_username)
SMTP_PASS="<from 1Password>"

mkdir -p "$WALLET"
orapki wallet create -wallet "$WALLET" -auto_login

# OAuth: IDCS URL as connect string
orapki secretstore create_credential -wallet "$WALLET" \
  -connect_string "$IDCS" -username "$CLIENT_ID" -password "$CLIENT_SECRET"

# SMTP: host as connect string
orapki secretstore create_credential -wallet "$WALLET" \
  -connect_string "$SMTP_HOST" -username "$SMTP_USER" -password "$SMTP_PASS"

# Verify: must show exactly 2 entries
mkstore -wrl "$WALLET" -listCredential
```

## Inputs

<!-- markdownlint-disable MD013 MD060 -->
| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `tenancy_ocid` | Tenancy OCID | `string` | - | yes |
| `compartment_ocid` | Compartment OCID for Email Delivery resources | `string` | - | yes |
| `identity_domain_ocid` | OCID of the OCI Identity Domain | `string` | - | yes |
| `smtp_sender_email` | Approved Sender email address | `string` | - | yes |
| `region` | OCI region identifier | `string` | `eu-zurich-1` | no |
| `region_key` | Short region key for resource names | `string` | `zrh` | no |
| `env` | Environment code | `string` | `lab` | no |
| `stack` | Stack code | `string` | `mfaoma` | no |
| `lab_instance` | Instance index (1 -> 01) | `number` | `1` | no |
| `project_tag` | Value for project freeform tag | `string` | `oradba-labs` | no |
| `freeform_tags` | Additional freeform tags | `map(string)` | `{}` | no |
| `app_name` | Override for OAuth App display name | `string` | `""` | no |
| `smtp_sender_name` | Display name in From header | `string` | `Oracle DB MFA` | no |
| `create_dkim` | Create DKIM record | `bool` | `false` | no |
| `email_domain_ocid` | OCID of Email Delivery domain (required when `create_dkim = true`) | `string` | `null` | no |
<!-- markdownlint-enable -->

## Outputs

<!-- markdownlint-disable MD013 MD060 -->
| Name | Description | Sensitive |
|---|---|---|
| `iam_domain_url` | Identity Domain URL | no |
| `oauth_client_id` | OAuth App client ID | no |
| `oauth_client_secret` | OAuth App client secret | yes |
| `smtp_host` | OCI Email Delivery SMTP host | no |
| `smtp_port` | SMTP port (587) | no |
| `smtp_sender_email` | Approved Sender email | no |
| `smtp_username` | SMTP credential username | no |
| `smtp_password` | SMTP credential password | yes |
| `smtp_user_ocid` | OCID of SMTP IAM user | no |
| `smtp_group_ocid` | OCID of IAM group for SMTP user | no |
| `approved_sender_ocid` | OCID of Approved Sender | no |
| `db_mfa_config_commands` | ALTER SYSTEM commands for DB-side setup | yes |
<!-- markdownlint-enable -->

## References

- [Oracle MFA Tutorial](https://docs.oracle.com/en/learn/mfa-db23ai-oma/)
- [Talk Demo Guide](../../../../talks/oracle-db-mfa/demos.md)
