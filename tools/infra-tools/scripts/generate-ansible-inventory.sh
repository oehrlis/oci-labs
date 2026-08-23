#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, CH
# ------------------------------------------------------------------------------
# Name.......: generate-ansible-inventory.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 2026.08.23
# Version....: v0.1.0
# Purpose....: Build an Ansible inventory from OCI resources.
# Notes......: Placeholder. Superseded for cpu-patch-test, where Terraform writes the inventory directly into ansible/inventories/generated/.
#              Exits non-zero with a clear message rather than being an empty
#              file that shellcheck cannot even assign a shell to.
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
set -euo pipefail

echo "ERROR: $(basename "${BASH_SOURCE[0]}") is a placeholder and not implemented yet." >&2
echo "       See tasks/roadmap-cpu-lab.md for the milestone that fills it." >&2
exit 1
