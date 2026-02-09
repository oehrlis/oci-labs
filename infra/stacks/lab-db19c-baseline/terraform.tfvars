# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: terraform.tfvars
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2025.11.26
# Version....: v0.1.0
# Purpose....: Default variables for the lab-db19c-baseline Terraform stack.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
# Modified...:
# 2025.11.26 oehrli - initial version
# ------------------------------------------------------------------------------

tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaac3gjl7xgpxu3mmqh2hahws2loithifufgimnjkmmac2r33dr6tfq"
user_ocid        = "ocid1.user.oc1..aaaaaaaa5m4nujb23zpw2srpohtexulfizkznk4lpvcfkvx6hnx66vnw52pa"
fingerprint      = "d4:d7:af:8b:c1:f9:c9:b7:3e:c9:1f:2a:c7:3b:54:00"
private_key_path = "/Users/stefan.oehrli/.oci/oci_api_key.pem"

region           = "eu-zurich-1"
compartment_ocid = "ocid1.compartment.oc1..aaaaaaaahmgdcd6ejo2acolul3dppkh7pdurceq2tn3b5ghrghmpsahglsqa"

ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAttY4vfXbzVErjElIbbTre0zFOBe2gW/3BvE1MN0lC44fNCl4texidPykZFxz436WgWZETzqBKlQw0YFalMw/Z5hzfnje6BZWEdridBjf9T+WKW8s+ReosXqVKjyoj4bGmei/VhHs0/h2xcI6XUYL47AFseySHeexY9N9FF/tLbAr+4jMq+/jGruB4aTTpNRWnvLUjbk7+D+d3hk8Q/fZs68qzBx8pnuVsrQ+bvivAWUMlZ/IbrgMdmkKxIzpEPiL845wzGxZ7lxA4pMNrpv1MXWK/weHvpHLRpssKArLegoCl4suefpKpoGGSMxAdAbsX9++ScKtWQJtD3COt80eGQ== Stefan Oehrli 2048"
bootstrap_url  = "https://objectstorage.eu-zurich-1.oraclecloud.com/p/fOAtM88UxxzWdgrN8i4W4RnPOWyK6fdk3cJh7TU3MPZiLws5-ucPW0fJlNBNiYVo/n/trivadisbdsxsp/b/tvd-cpureport/o/bootstrap_linux.tar.gz"
# --- EOF ----------------------------------------------------------------------
