# datasafe-demo

Demo environment for the Oracle AI World 2026 session LRN6087 (Oracle Data Safe): one Oracle Linux 8 x86 host
with Oracle AI Database 26ai Free in Podman and the Data Safe on-premises connector. Own VCN and Bastion via the
`core` module (`core_owner = dsdemo`), no public IP, NSG egress HTTPS only, nightly auto-stop.

- Stack code: `dsdemo` - names read `zrh-lab-dsdemo-01`, host `ci-zrh-lab-dsdemo-01-db-01`
- Existing compartment only (`compartment_ocid` or `compartment_name` + `tenancy_ocid`)
- Optional instance principal (`enable_instance_principal`) for `ds_connector_create.sh` on the host

Runbook (build, verify, stop/start, teardown, open decisions): [docs/datasafe-demo.md](../../../docs/datasafe-demo.md)

```bash
cp .env.example .env
cp terraform.tfvars.example terraform.tfvars
make dsdemo-plan
make dsdemo-apply
```
