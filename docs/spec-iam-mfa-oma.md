# Spec: Module iam_mfa_oma

## Zweck

Terraform-Modul und deployable Stack für die OCI-seitigen Prerequisites
von Oracle Database Native MFA mit OMA Push (Oracle Mobile Authenticator).

Das Modul provisioniert die IAM- und Email-Delivery-Ressourcen, die ein
DBA benötigt, um Oracle Database MFA zu konfigurieren. Die DB-seitige
Konfiguration (Parameter, Wallet, User-Anlage) liegt bewusst ausserhalb
des Scopes - sie wird manuell oder per Demo-Script durchgeführt.

Verwendung: DOAG DB 2026 Demo, Blog-Post auf oradba.ch, Community-Referenz.

## Dateipfade (Ziel)

```text
oci-labs/
  terraform/
    modules/
      iam_mfa_oma/         <- dieses Modul
        main.tf
        variables.tf
        outputs.tf
        README.md          <- inkl. OCI CLI Äquivalente
    envs/
      mfa_oma_setup/       <- deployable Stack der das Modul aufruft
        main.tf
        variables.tf
        outputs.tf
        provider.tf
        terraform.tfvars.example
        .env.example
        README.md
```

## OCI Ressourcen (was Terraform erstellt)

### OCI IAM

```text
oci_identity_domains_app  (OAuth Confidential App)
  - display_name: var.app_name (Default: "oracle-db-mfa")
  - based_on_template: CustomWebAppTemplateId
  - grant_type: CLIENT_CREDENTIALS
  - app_roles (manuell nach apply):
      - User Administrator
      - Identity Domain Administrator
      - MFA Client
  - Outputs: client_id, client_secret

oci_identity_user  (dedizierter SMTP-User)
  - name: <stack_code>-smtp-user (via naming module)
  - compartment: tenancy root (IAM Users sind tenancy-weit)

oci_identity_group  (IAM-Gruppe für SMTP-User)
  - name: grp-<naming>-smtp-<nn>
  - Identity Domain Tenancies unterstützen kein "Allow user" in Policies

oci_identity_user_group_membership  (User-zu-Gruppe Bindung)

oci_identity_smtp_credential  (an SMTP-User gebunden)
  - Outputs: username, password (sensitive)
```

### OCI Email Delivery

```text
oci_email_sender  (Approved Sender)
  - email_address: var.smtp_sender_email
  - compartment_id: var.compartment_ocid

oci_email_dkim  (optional, nur wenn Domain bereits verifiziert)
  - nur wenn var.create_dkim = true
```

### OCI IAM Policy

```text
oci_identity_policy
  - Name: <stack_code>-smtp-policy
  - Statement: "Allow group <smtp_group_name> to use email-family
                in compartment id <compartment_ocid>"
  - Hinweis: "Allow user" ist in Identity Domain Tenancies nicht gültig
```

## Variables (Modul)

### Pflicht

```hcl
variable "tenancy_ocid" {
  # Für IAM User (tenancy root)
}

variable "compartment_ocid" {
  # Für Email Delivery Ressourcen und Policy
}

variable "identity_domain_ocid" {
  # OCID der Identity Domain für OAuth App
  # Findet man unter: Identity & Security -> Domains -> <Domain> -> OCID
}

variable "smtp_sender_email" {
  # Approved Sender E-Mail, z.B. "labdb@oradba.ch"
}
```

### Naming (konsistent mit anderen oci-labs Modulen)

```hcl
variable "region_key"        { default = "chzh" }
variable "environment_code"  { default = "l" }
variable "stack_code"        { default = "mfaoma" }
variable "lab_instance"      { default = 1 }
variable "common_freeform_tags" { default = {} }
```

### Optional

```hcl
variable "app_name" {
  default = ""  # leer = aus naming module ableiten
}

variable "smtp_sender_name" {
  default = "Oracle DB MFA"
}

variable "create_dkim" {
  default = false
}
```

## Outputs (Modul)

Alle Outputs, die der DBA für die DB-Konfiguration braucht.
Sensitive Werte als `sensitive = true`.

```hcl
output "iam_domain_url"     { } # z.B. https://idcs-xxx.identity.oraclecloud.com
output "oauth_client_id"    { }
output "oauth_client_secret"{ sensitive = true }
output "smtp_host"          { } # z.B. smtp.email.eu-zurich-1.oci.oraclecloud.com
output "smtp_port"          { value = 587 }
output "smtp_sender_email"  { }
output "smtp_username"      { }
output "smtp_password"      { sensitive = true }

# Copy-paste ready Block für DB-Konfiguration
output "db_mfa_config_commands" {
  description = "ALTER SYSTEM commands for DB-side MFA setup"
  sensitive   = true
  value = <<-EOT
    ALTER SYSTEM SET MFA_OMA_IAM_DOMAIN_URL = '${iam_domain_url}';
    ALTER SYSTEM SET MFA_SMTP_HOST          = '${smtp_host}';
    ALTER SYSTEM SET MFA_SMTP_PORT          = 587;
    ALTER SYSTEM SET MFA_SENDER_EMAIL_ID    = '${smtp_sender_email}';
  EOT
}
```

## Stack: envs/mfa_oma_setup

### Konfiguration via .env + tfvars

`.env.example`:

```bash
export TF_VAR_tenancy_ocid="ocid1.tenancy.oc1..xxx"
export TF_VAR_compartment_ocid="ocid1.compartment.oc1..xxx"
export TF_VAR_identity_domain_ocid="ocid1.domain.oc1..xxx"
```

`terraform.tfvars.example`:

```hcl
region_key         = "chzh"
environment_code   = "l"
stack_code         = "mfaoma"
smtp_sender_email  = "labdb@yourdomain.com"
smtp_sender_name   = "Oracle DB MFA Demo"
```

### Deployment

```bash
cd terraform/envs/mfa_oma_setup
cp terraform.tfvars.example terraform.tfvars
cp .env.example .env
# .env und terraform.tfvars befüllen

source .env
terraform init
terraform plan
terraform apply

# DB-Konfiguration ausgeben
terraform output db_mfa_config_commands
```

## README-Struktur (Modul)

Jeder Terraform-Ressource-Block wird im README mit dem OCI CLI
Äquivalent dokumentiert. Kein Screenshot, nur Commands.

Beispiel-Struktur im README:

```
## Resources

### OAuth Confidential Application

**Terraform:** oci_identity_domains_app ...

**OCI CLI (raw-request - oci identity-domains hat kein app create):**
$ IDCS=$(terraform output -raw iam_domain_url | sed 's/:443//')
$ oci raw-request --http-method POST \
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

### Approved Sender

**Terraform:** oci_email_sender ...

**OCI CLI:**
$ oci email sender create \
    --compartment-id $COMPARTMENT_OCID \
    --email-address "labdb@oradba.ch"

...
```

## Abgrenzung

**In scope:**

- OCI IAM Identity Domain: OAuth Confidential App + App Roles
- OCI IAM: dedizierter SMTP-User + SMTP Credential
- OCI IAM Policy: Email Delivery Berechtigung
- OCI Email Delivery: Approved Sender
- Outputs: alle Werte für DB-Konfiguration

**Out of scope:**

- Domain-Verifizierung (DKIM/DNS) — manuell oder separates Modul
- DB-seitige Konfiguration (Parameter, Wallet, User-Anlage)
- Cisco Duo Integration — separates Modul später
- Certificate-based MFA — separates Modul später
- Oracle Database Ressourcen (Compute, VCN)

## Abhängigkeiten

- OCI Tenancy mit Identity Domain (nicht klassisches IAM)
- OCI Email Delivery Service verfügbar in der Region
- E-Mail-Domain bereits in OCI Email Delivery verifiziert
  (Domain-Verifizierung ist manueller Schritt oder separates Modul)
- Terraform OCI Provider >= 5.x

## Referenz

- Oracle MFA Tutorial: https://docs.oracle.com/en/learn/mfa-db23ai-oma/
- Talk Demo Guide: talks/oracle-db-mfa/demos.md
- Blog Post (geplant): oradba.ch
