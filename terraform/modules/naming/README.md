# Naming module

Consistent naming and tagging helpers for OraDBA lab stacks. The module builds a core name segment
and a base freeform tag map so resources share predictable identifiers.

## Name schemes

| `name_scheme` | `lab_name_core` | Resource names |
| --- | --- | --- |
| `legacy` (default) | `{region}-{env}-{stack}-{instance}`, `chzh-l-odb19eng-01` | `vcn-chzh-l-odb19eng-01-net-01` |
| `oci` | `{region}-{env}-{stack}`, `zrh-lab-cpu` | `vcn-zrh-lab-cpu-net-01`, `ci-zrh-lab-cpu-db-01` |

`oci` follows the OCI naming rule `{resource}-{region}-{env}-{stack}-{component}-{nn}`: region as
three-letter code (`eu-zurich-1` -> `zrh`, `eu-frankfurt-1` -> `fra`, `us-ashburn-1` -> `iad`,
or the code itself), `environment_code` one of `lab`, `dev`, `test`, `prod`, `stack_code`
lowercase alphanumeric without hyphens. The rule has one index slot - the resource's own - so
`lab_instance` must stay `1`; a second lab of the same kind gets its own `stack_code`. Existing
stacks keep `legacy`: switching the scheme renames every resource, and some names (VCN DNS
labels, subnets) cannot change in place. Requires Terraform >= 1.9.

## Inputs

- `name_scheme` (string): `legacy` (default) or `oci`, see above.
- `region_key` (string): legacy: as given, e.g. `chzh`. oci: OCI region name or three-letter code.
- `environment_code` (string): legacy e.g. `l`, `ws`, `d`, `t`, `p` (default `l`); oci `lab`, `dev`, `test`, `prod`.
- `stack_code` (string): Stack / lab type, e.g. `odb19eng`, `odb21eng`, `odb26ai`, `odbaud`.
- `lab_instance` (number): Lab instance index, rendered as two digits (1 -> `01`). Default: `1`.
- `common_freeform_tags` (map(string)): Base freeform tags (default includes `project` and `owner`).
  Merged with stack-specific tags inside the module.

## Outputs

- `lab_name_core` (string): see the name schemes table.
- `base_freeform_tags` (map(string)): Merged freeform tags including stack, env, region, and padded lab index.

## Usage

```hcl
module "naming" {
  source            = "../modules/naming"
  region_key        = "chzh"
  environment_code  = "l"
  stack_code        = "odb19eng"
  lab_instance      = 1
  common_freeform_tags = {
    project = "oradba-labs"
    owner   = "oehrli"
  }
}

resource "oci_core_vcn" "this" {
  display_name  = "vcn-${module.naming.lab_name_core}-net-01"
  freeform_tags = module.naming.base_freeform_tags
}

resource "oci_core_instance" "jumphost" {
  display_name  = "ci-${module.naming.lab_name_core}-gw-01"
  freeform_tags = module.naming.base_freeform_tags
}
```

## Notes

- Aligns with `global/naming.tf` so module outputs match stack-level naming helpers.
- Extend `base_freeform_tags` at the resource level when additional tags are required.
- Insert qualifiers before the instance number if needed (e.g. `ci-${module.naming.lab_name_core}-gw-sec-01`).
