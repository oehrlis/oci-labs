# Naming module

Consistent naming and tagging helpers for OraDBA lab stacks. The module builds a core name segment and a base freeform tag map so resources share predictable identifiers.

## Inputs

- `region_key` (string): OCI region key, e.g. `chzh`, `eu-frn`, `uk-lon`.
- `environment_code` (string): Environment code, e.g. `l` (lab), `ws` (workshop), `d`, `t`, `p`. Default: `l`.
- `stack_code` (string): Stack / lab type, e.g. `odb19eng`, `odb21eng`, `odb26ai`, `odbaud`.
- `lab_instance` (number): Lab instance index, rendered as two digits (1 -> `01`). Default: `1`.
- `common_freeform_tags` (map(string)): Base freeform tags (default includes `project` and `owner`). Merged with stack-specific tags inside the module.

## Outputs

- `lab_name_core` (string): `{region}-{env}-{stack}-{instance}`, e.g. `chzh-l-odb19eng-01`.
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
