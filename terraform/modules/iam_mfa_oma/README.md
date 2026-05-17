# Module: iam_mfa_oma

Terraform module for the OCI-side prerequisites of Oracle Database Native MFA
with OMA Push (Oracle Mobile Authenticator).

## What this module creates

| Resource | Description |
|---|---|
| `oci_identity_domains_application` | OAuth 2.0 Confidential Application in Identity Domain |
| `oci_identity_user` | Dedicated SMTP IAM user (tenancy root) |
| `oci_identity_smtp_credential` | SMTP credential bound to the SMTP user |
| `oci_email_sender` | Approved Sender in OCI Email Delivery |
| `oci_email_dkim` | DKIM record (optional, `create_dkim = true`) |
| `oci_identity_policy` | Policy allowing SMTP user to use email-family |

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
  smtp_sender_email    = "labdb@oradba.ch"
}
```

## Post-apply: grant OAuth App roles

After `terraform apply`, grant the following roles to the OAuth application in the
OCI Console: **Identity & Security -> Domains -> \<Domain> -> Oracle Cloud Services ->
\<app-name> -> Application Roles**

Required roles:

- MFA Client
- User Administrator
- Identity Domain Administration

**OCI CLI equivalent:**

```bash
IDCS_URL=$(terraform output -raw iam_domain_url)
APP_ID=$(oci identity-domains app list \
  --idcs-endpoint "$IDCS_URL" \
  --display-name "$(terraform output -raw oauth_client_id)" \
  --query 'data.resources[0].id' --raw-output)

# Look up role OCIDs and grant - repeat for each role
for ROLE_NAME in "MFA Client" "User Administrator" "Identity Domain Administration"; do
  ROLE_ID=$(oci identity-domains app-role list \
    --idcs-endpoint "$IDCS_URL" \
    --filter "displayName eq \"$ROLE_NAME\"" \
    --query 'data.resources[0].id' --raw-output)
  oci identity-domains grant create \
    --idcs-endpoint "$IDCS_URL" \
    --schemas '["urn:ietf:params:scim:schemas:oracle:idcs:Grant"]' \
    --grant-mechanism "ADMINISTRATOR_TO_APP" \
    --grantee "{\"type\":\"App\",\"value\":\"$APP_ID\"}" \
    --entitlement "{\"attributeName\":\"appRoles\",\"attributeValue\":\"$ROLE_ID\"}"
done
```

## Resources

### OAuth Confidential Application

**Terraform:** `oci_identity_domains_application.oauth_app`

```bash
IDCS_URL=$(terraform output -raw iam_domain_url)
oci identity-domains app create \
  --idcs-endpoint "$IDCS_URL" \
  --schemas '["urn:ietf:params:scim:schemas:oracle:idcs:App"]' \
  --display-name "oracle-db-mfa" \
  --is-oauth-client true \
  --allowed-grants '["client_credentials"]' \
  --client-type "confidential"
```

### SMTP User

**Terraform:** `oci_identity_user.smtp_user`

```bash
oci iam user create \
  --name "usr-zrh-lab-mfaoma-smtp-01" \
  --description "SMTP user for Oracle DB MFA email delivery" \
  --email "labdb@oradba.ch" \
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
  --email-address "labdb@oradba.ch"
```

### IAM Policy

**Terraform:** `oci_identity_policy.smtp_policy`

```bash
oci iam policy create \
  --compartment-id "$TENANCY_OCID" \
  --name "pol-zrh-lab-mfaoma-smtp-01" \
  --description "Allow SMTP user to use email-family" \
  --statements '["Allow user usr-zrh-lab-mfaoma-smtp-01 to use email-family in compartment id COMPARTMENT_OCID"]'
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
| `approved_sender_ocid` | OCID of Approved Sender | no |
| `db_mfa_config_commands` | ALTER SYSTEM commands for DB-side setup | yes |
<!-- markdownlint-enable -->

## References

- [Oracle MFA Tutorial](https://docs.oracle.com/en/learn/mfa-db23ai-oma/)
- [Talk Demo Guide](../../../../talks/oracle-db-mfa/demos.md)
