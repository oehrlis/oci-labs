# Stack: mfa_oma_setup

Deployable Terraform stack for Oracle Database Native MFA with OMA Push.
Calls the `iam_mfa_oma` module to provision all OCI-side prerequisites.

## Prerequisites

- OCI Tenancy with Identity Domain (not classic IAM)
- OCI Email Delivery available in the target region
- Email domain already verified in OCI Email Delivery
- Terraform >= 1.3, OCI Provider >= 5.0
- OCI CLI configured (`~/.oci/config`, profile DEFAULT or named)

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

See the [Runbook Step 5](../../../../docs/runbook-mfa-oma.md#step-5---grant-oauth-app-roles-manual)
for CLI commands using `oci raw-request`.

### 3. Configure Oracle Database

```bash
# Get copy-paste ready ALTER SYSTEM commands
terraform output db_mfa_config_commands
```

Run the output SQL as SYSDBA, then store OAuth and SMTP credentials in the MFA
wallet using `orapki secretstore create_credential`. See the
[Runbook Steps 6-7](../../../../docs/runbook-mfa-oma.md#step-6---configure-oracle-database)
for the full wallet configuration procedure.

## Teardown

```bash
source .env
terraform destroy
```

## References

- [Oracle MFA Tutorial](https://docs.oracle.com/en/learn/mfa-db23ai-oma/)
- [Module README](../../modules/iam_mfa_oma/README.md)
- [Talk Demo Guide](../../../../talks/oracle-db-mfa/demos.md)
