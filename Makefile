# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: Makefile
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Editor.....: Stefan Oehrli
# Date.......: 19.08.2026
# Version....: v0.1.0
# Purpose....: Lifecycle automation for the OCI lab stacks - lint, validate, and
#              the cpu-patch-test lab (build, install, patch, verify, destroy).
# Notes......: Config via terraform/envs/<env>/.env (auto-sourced per target).
#              Secrets come from 1Password at run time - never from this file.
#              Use 'make help' for targets.
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ------------------------------------------------------------------------------

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help
MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

# Ensure Homebrew-installed tools are found regardless of caller's PATH
PATH := /opt/homebrew/bin:/usr/local/bin:$(PATH)
export PATH

# -- Colors --------------------------------------------------------------------
COLOR_RESET  := \033[0m
COLOR_BOLD   := \033[1m
COLOR_GREEN  := \033[32m
COLOR_YELLOW := \033[33m
COLOR_BLUE   := \033[34m
COLOR_RED    := \033[31m

# -- Project -------------------------------------------------------------------
PROJECT_NAME := oci-labs
VERSION      := $(shell cat VERSION 2>/dev/null || echo "0.0.0")

# -- Directories ---------------------------------------------------------------
TF_DIR      := terraform
ANSIBLE_DIR := ansible
DOC_DIR     := docs
TOOLS_DIR   := tools

# -- cpu-patch-test lab --------------------------------------------------------
CPU_ENV_DIR   := $(TF_DIR)/envs/cpu-patch-test
CPU_ENV_FILE  := $(CPU_ENV_DIR)/.env
CPU_PLAN_FILE := tfplan
CPU_INVENTORY := inventories/generated/cpu-patch-test/hosts.yml
CPU_PLAYBOOK  := playbooks/lab-cpu-patch.yml

# 1Password references. Read inside recipe bodies only - never at parse time,
# because a $(shell op read ...) would run before any 'op signin'.
OP_MOS_USER := op://secrets/Oracle-MOS/username
OP_MOS_PASS := op://secrets/Oracle-MOS/password

# -- Tool detection ------------------------------------------------------------
TERRAFORM    := $(shell PATH="$(PATH)" command -v terraform 2>/dev/null)
ANSIBLE      := $(shell PATH="$(PATH)" command -v ansible-playbook 2>/dev/null)
ANSIBLE_EXTRA ?=
ANSIBLE_LINT := $(shell PATH="$(PATH)" command -v ansible-lint 2>/dev/null)
YAMLLINT     := $(shell PATH="$(PATH)" command -v yamllint 2>/dev/null)
MARKDOWNLINT := $(shell PATH="$(PATH)" command -v markdownlint 2>/dev/null || \
                        PATH="$(PATH)" command -v markdownlint-cli 2>/dev/null)
SHELLCHECK   := $(shell PATH="$(PATH)" command -v shellcheck 2>/dev/null)
OP           := $(shell PATH="$(PATH)" command -v op 2>/dev/null)
OCI          := $(shell PATH="$(PATH)" command -v oci 2>/dev/null)
GIT          := $(shell PATH="$(PATH)" command -v git 2>/dev/null)

# -- Verbosity -----------------------------------------------------------------
V ?=
Q := $(if $(V),,@)

# ==============================================================================
# Help
# ==============================================================================

.PHONY: help
help: ## Show this help message
	@echo -e "$(COLOR_BOLD)$(PROJECT_NAME) Makefile$(COLOR_RESET)"
	@echo "Version: $(VERSION)"
	@echo ""
	@echo "CPU patch lab - quarterly cycle:"
	@echo "  make cpu-lab-plan                    # dry-run, no changes"
	@echo "  make cpu-lab-apply                   # build the infrastructure"
	@echo "  make cpu-lab-install                 # OS + Oracle 19c at the base RU"
	@echo "  make cpu-lab-patch                   # AutoUpgrade to the target RU"
	@echo "  make cpu-lab-verify                  # confirm the patch level"
	@echo "  make cpu-lab-destroy                 # tear everything down"
	@echo ""
	@echo "Release workflow:"
	@echo "  Patch : make release                 # bump patch -> commit -> tag"
	@echo "  Minor : make version-bump-minor && make tag"
	@echo "  Major : make version-bump-major && make tag"
	@echo "  After : git push origin main && git push origin v$(VERSION)"
	@echo ""
	@echo -e "$(COLOR_BOLD)Lint and Format:$(COLOR_RESET)"
	@grep -E '^(lint|fmt)[a-zA-Z_-]*:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(COLOR_GREEN)%-24s$(COLOR_RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo -e "$(COLOR_BOLD)CPU Patch Lab:$(COLOR_RESET)"
	@grep -E '^cpu-lab-[a-zA-Z_-]*:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(COLOR_GREEN)%-24s$(COLOR_RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo -e "$(COLOR_BOLD)Cleanup:$(COLOR_RESET)"
	@grep -E '^clean[a-zA-Z_-]*:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(COLOR_GREEN)%-24s$(COLOR_RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo -e "$(COLOR_BOLD)Version Management:$(COLOR_RESET)"
	@grep -E '^(version|check-version)[a-zA-Z_-]*:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(COLOR_GREEN)%-24s$(COLOR_RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo -e "$(COLOR_BOLD)Release Management:$(COLOR_RESET)"
	@grep -E '^(tag|release):.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(COLOR_GREEN)%-24s$(COLOR_RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo -e "$(COLOR_BOLD)Info:$(COLOR_RESET)"
	@grep -E '^status:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(COLOR_GREEN)%-24s$(COLOR_RESET) %s\n", $$1, $$2}'

# ==============================================================================
# Guards
# ==============================================================================

.PHONY: guard-terraform guard-ansible guard-op guard-oci guard-cpu-env

guard-terraform:
	@[[ -n "$(TERRAFORM)" ]] || \
	  { echo "❌ terraform not found. Install: brew install terraform"; exit 1; }

guard-ansible:
	@[[ -n "$(ANSIBLE)" ]] || \
	  { echo "❌ ansible-playbook not found. Install: brew install ansible"; exit 1; }

guard-op:
	@[[ -n "$(OP)" ]] || \
	  { echo "❌ 1Password CLI not found. Install: brew install 1password-cli"; exit 1; }

guard-oci:
	@[[ -n "$(OCI)" ]] || \
	  { echo "❌ OCI CLI not found. Install: brew install oci-cli"; exit 1; }

guard-cpu-env:
	@[[ -f "$(CPU_INVENTORY_ABS)" ]] || \
	  { echo "❌ Inventory $(CPU_INVENTORY_ABS) missing - run 'make cpu-lab-apply' first"; exit 1; }

CPU_INVENTORY_ABS := $(ANSIBLE_DIR)/$(CPU_INVENTORY)

# ==============================================================================
# Lint and Format
# ==============================================================================

.PHONY: lint
lint: lint-terraform lint-ansible lint-yaml lint-markdown lint-shell check-version ## Run all lint checks

.PHONY: fmt-terraform
fmt-terraform: guard-terraform ## Format Terraform files in-place
	$(Q)"$(TERRAFORM)" fmt -recursive "$(TF_DIR)"
	@echo "✅ Terraform files formatted"

.PHONY: lint-terraform
lint-terraform: guard-terraform ## Check Terraform formatting and validate every env
	@echo -e "$(COLOR_BOLD)terraform fmt -check$(COLOR_RESET)"
	$(Q)"$(TERRAFORM)" fmt -check -recursive "$(TF_DIR)"
	@echo -e "$(COLOR_BOLD)terraform validate per env$(COLOR_RESET)"
	@for env in $(TF_DIR)/envs/*/; do \
	  [[ -f "$$env/provider.tf" ]] || continue; \
	  echo "--- $$env"; \
	  ( cd "$$env" && "$(TERRAFORM)" init -backend=false -input=false >/dev/null && "$(TERRAFORM)" validate ); \
	done
	@echo "✅ Terraform lint complete"

.PHONY: lint-ansible
lint-ansible: ## Lint Ansible roles and playbooks with ansible-lint
	@[[ -n "$(ANSIBLE_LINT)" ]] || \
	  { echo "❌ ansible-lint not found. Install: brew install ansible-lint"; exit 1; }
	$(Q)cd "$(ANSIBLE_DIR)" && "$(ANSIBLE_LINT)" roles/ playbooks/

.PHONY: lint-ansible-syntax
lint-ansible-syntax: guard-ansible guard-cpu-env ## Syntax-check the cpu-patch playbook
	$(Q)cd "$(ANSIBLE_DIR)" && "$(ANSIBLE)" -i "$(CPU_INVENTORY)" "$(CPU_PLAYBOOK)" --syntax-check

.PHONY: lint-yaml
lint-yaml: ## Lint YAML files with yamllint
	@[[ -n "$(YAMLLINT)" ]] || \
	  { echo "❌ yamllint not found. Install: brew install yamllint"; exit 1; }
	$(Q)"$(YAMLLINT)" "$(ANSIBLE_DIR)"

.PHONY: lint-markdown
lint-markdown: ## Lint markdown files with markdownlint
	@[[ -n "$(MARKDOWNLINT)" ]] || \
	  { echo "❌ markdownlint not found. Install: npm install -g markdownlint-cli"; exit 1; }
	$(Q)find . -type f -name "*.md" \
		-not -path "./.git/*" \
		-not -path "./node_modules/*" -print0 | \
		xargs -0 "$(MARKDOWNLINT)"

.PHONY: lint-shell
lint-shell: ## Lint shell scripts with shellcheck
	@[[ -n "$(SHELLCHECK)" ]] || \
	  { echo "❌ shellcheck not found. Install: brew install shellcheck"; exit 1; }
	$(Q)find "$(TOOLS_DIR)" bootstrap -type f -name "*.sh" -print0 2>/dev/null | \
		xargs -0 -r "$(SHELLCHECK)" -x -S warning

.PHONY: check-version
check-version: ## Validate semantic version format in VERSION file
	@grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$' VERSION \
		&& echo "Version is valid: $(VERSION)" \
		|| (echo "Invalid version format in VERSION"; exit 1)

# ==============================================================================
# CPU Patch Lab
# ==============================================================================
# Every target sources $(CPU_ENV_FILE) when present, so TF_VAR_* overrides are
# picked up without the caller having to remember 'source .env'.

.PHONY: cpu-lab-init
cpu-lab-init: guard-terraform ## Init Terraform for the cpu-patch-test env
	$(Q)cd "$(CPU_ENV_DIR)" && "$(TERRAFORM)" init -input=false
	@echo "✅ cpu-patch-test initialised"

.PHONY: cpu-lab-plan
cpu-lab-plan: guard-terraform ## Plan cpu-patch-test (dry-run, writes tfplan)
	$(Q)cd "$(CPU_ENV_DIR)" && \
	  set -a; [[ -f .env ]] && . ./.env; set +a; \
	  "$(TERRAFORM)" plan -input=false -out="$(CPU_PLAN_FILE)"

.PHONY: cpu-lab-apply
cpu-lab-apply: guard-terraform ## Build the lab infra - applies a saved tfplan, or plans fresh (REPLAN=1 forces fresh)
	$(Q)cd "$(CPU_ENV_DIR)" && \
	  set -a; [[ -f .env ]] && . ./.env; set +a; \
	  if [[ "$(REPLAN)" == "1" ]] && [[ -f "$(CPU_PLAN_FILE)" ]]; then \
	    echo "REPLAN=1 - discarding the saved plan"; \
	    rm -f "$(CPU_PLAN_FILE)"; \
	  fi; \
	  if [[ -f "$(CPU_PLAN_FILE)" ]]; then \
	    age=$$(( ( $$(date +%s) - $$(stat -f %m "$(CPU_PLAN_FILE)") ) / 60 )); \
	    echo -e "$(COLOR_YELLOW)Applying the saved plan $(CPU_PLAN_FILE) (created $$age min ago).$(COLOR_RESET)"; \
	    echo "A saved plan applies WITHOUT a confirmation prompt."; \
	    echo "Review it first with : make cpu-lab-show"; \
	    echo "Plan again instead   : make cpu-lab-apply REPLAN=1"; \
	    "$(TERRAFORM)" apply -input=false "$(CPU_PLAN_FILE)"; \
	    rm -f "$(CPU_PLAN_FILE)"; \
	  else \
	    echo "No saved plan - Terraform will plan now and ask for confirmation."; \
	    "$(TERRAFORM)" apply -input=false; \
	  fi
	@echo "✅ Infrastructure ready - inventory: $(CPU_INVENTORY_ABS)"

.PHONY: cpu-lab-show
cpu-lab-show: guard-terraform ## Show the saved tfplan in human-readable form
	@[[ -f "$(CPU_ENV_DIR)/$(CPU_PLAN_FILE)" ]] || \
	  { echo "❌ No saved plan at $(CPU_ENV_DIR)/$(CPU_PLAN_FILE) - run 'make cpu-lab-plan'"; exit 1; }
	$(Q)cd "$(CPU_ENV_DIR)" && "$(TERRAFORM)" show "$(CPU_PLAN_FILE)"

# ------------------------------------------------------------------------------
# Ansible secrets
# ------------------------------------------------------------------------------
# Secrets go to Ansible in a 0600 JSON file, never on the command line. An argv
# is world-readable through ps, so "-e mos_password=..." exposed the MOS account
# and the database SYS password to every local user for the whole run - and an
# AutoUpgrade run lasts an hour.
#
# The values reach python3 through the environment rather than argv for the same
# reason; /proc/<pid>/environ and "ps -E" are owner-restricted, argv is not.
# The trap removes the file on success, error and Ctrl-C alike.
define cpu_lab_ansible_secrets
umask 077; \
mos_user="$$("$(OP)" read '$(OP_MOS_USER)')" || { echo "❌ op read failed - run: eval \$$(op signin)"; exit 1; }; \
mos_pass="$$("$(OP)" read '$(OP_MOS_PASS)')" || { echo "❌ op read failed - run: eval \$$(op signin)"; exit 1; }; \
sys_pass="$$(cd "$(CPU_ENV_DIR)" && "$(TERRAFORM)" output -raw db_sys_password 2>/dev/null || echo '')"; \
ks_pass="$$(cd "$(CPU_ENV_DIR)" && "$(TERRAFORM)" output -raw autoupgrade_keystore_password 2>/dev/null || echo '')"; \
vars_file="$$(mktemp "$${TMPDIR:-/tmp}/cpu-lab-vars.XXXXXX")"; \
trap 'rm -f "$$vars_file"' EXIT INT TERM; \
MOS_USER="$$mos_user" MOS_PASS="$$mos_pass" SYS_PASS="$$sys_pass" KS_PASS="$$ks_pass" \
  python3 -c 'import json, os, sys; json.dump({"mos_username": os.environ["MOS_USER"], "mos_password": os.environ["MOS_PASS"], "db19_sys_password": os.environ["SYS_PASS"], "db19_autoupgrade_keystore_password": os.environ["KS_PASS"]}, open(sys.argv[1], "w"))' "$$vars_file"
endef

.PHONY: cpu-lab-install
cpu-lab-install: guard-ansible guard-op guard-cpu-env ## Install OS prereqs + Oracle 19c at the base RU
	$(Q)$(cpu_lab_ansible_secrets); \
	  cd "$(ANSIBLE_DIR)" && "$(ANSIBLE)" -i "$(CPU_INVENTORY)" "$(CPU_PLAYBOOK)" \
	    --tags install -e @"$$vars_file" $(ANSIBLE_EXTRA)

.PHONY: cpu-lab-patch
cpu-lab-patch: guard-ansible guard-op guard-cpu-env ## Run the AutoUpgrade out-of-place patch to the target RU
	$(Q)$(cpu_lab_ansible_secrets); \
	  cd "$(ANSIBLE_DIR)" && "$(ANSIBLE)" -i "$(CPU_INVENTORY)" "$(CPU_PLAYBOOK)" \
	    --tags patch -e @"$$vars_file" $(ANSIBLE_EXTRA)

.PHONY: cpu-lab-verify
cpu-lab-verify: guard-ansible guard-cpu-env ## Verify the post-patch state (read-only)
	$(Q)cd "$(ANSIBLE_DIR)" && "$(ANSIBLE)" -i "$(CPU_INVENTORY)" "$(CPU_PLAYBOOK)" --tags verify $(ANSIBLE_EXTRA)

.PHONY: cpu-lab-step
cpu-lab-step: guard-ansible guard-op guard-cpu-env ## Run a single tag: make cpu-lab-step TAG=create_home
	@[[ -n "$(TAG)" ]] || { echo "❌ TAG is required, e.g. make cpu-lab-step TAG=prereq"; exit 1; }
	$(Q)$(cpu_lab_ansible_secrets); \
	  cd "$(ANSIBLE_DIR)" && "$(ANSIBLE)" -i "$(CPU_INVENTORY)" "$(CPU_PLAYBOOK)" \
	    --tags "$(TAG)" -e @"$$vars_file" $(ANSIBLE_EXTRA)

.PHONY: cpu-lab-output
cpu-lab-output: guard-terraform ## Show Terraform outputs for the lab
	$(Q)cd "$(CPU_ENV_DIR)" && "$(TERRAFORM)" output

.PHONY: cpu-lab-ssh
cpu-lab-ssh: guard-terraform ## Print the SSH command(s) for the lab host(s)
	$(Q)cd "$(CPU_ENV_DIR)" && "$(TERRAFORM)" output -json ssh_commands | \
	  python3 -c 'import json,sys; [print(f"{k}: {v}") for k,v in json.load(sys.stdin).items()]'

.PHONY: cpu-lab-destroy
cpu-lab-destroy: guard-terraform ## Tear down the lab (asks for confirmation, YES=1 to skip)
	@if [[ "$(YES)" != "1" ]]; then \
	  echo -e "$(COLOR_YELLOW)This destroys the whole cpu-patch-test stack.$(COLOR_RESET)"; \
	  read -r -p "Type 'destroy' to confirm: " answer; \
	  [[ "$$answer" == "destroy" ]] || { echo "Aborted."; exit 1; }; \
	fi
	$(Q)cd "$(CPU_ENV_DIR)" && \
	  set -a; [[ -f .env ]] && . ./.env; set +a; \
	  "$(TERRAFORM)" destroy -input=false -auto-approve
	@echo "✅ cpu-patch-test destroyed"

.PHONY: cpu-lab-cycle
cpu-lab-cycle: ## Full cycle: apply -> install -> patch -> verify (leaves the lab running)
	@echo "🚀 Starting the full CPU patch cycle..."
	@$(MAKE) --no-print-directory cpu-lab-apply
	@$(MAKE) --no-print-directory cpu-lab-install
	@$(MAKE) --no-print-directory cpu-lab-patch
	@$(MAKE) --no-print-directory cpu-lab-verify
	@echo "🎉 Cycle complete. Tear down with: make cpu-lab-destroy"

# ==============================================================================
# Base image pre-authenticated request
# ==============================================================================
# AutoUpgrade cannot download the Oracle 19c base image, so it is staged from OCI
# Object Storage. These targets mint, list, and revoke the pre-authenticated
# request that serves it.
#
# A PAR URL is a bearer credential - anyone holding it can read the object. The
# default lifetime is deliberately short so it stays inside Accenture monitoring
# thresholds; override with PAR_DAYS=<n>.

define drop_base_image_url
grep -v '^export TF_VAR_db_base_image_url=' "$(CPU_ENV_FILE)" > "$(CPU_ENV_FILE).new" 2>/dev/null || true; \
mv -f "$(CPU_ENV_FILE).new" "$(CPU_ENV_FILE)"
endef

PAR_BUCKET := orarepo
PAR_OBJECT := LINUX.X64_193000_db_home.zip
PAR_NAME   := cpu-lab-base-image-19c
PAR_DAYS   ?= 7

.PHONY: cpu-lab-par
cpu-lab-par: guard-oci guard-terraform ## Mint a short-lived PAR for the 19c base image and write it to .env (PAR_DAYS=7)
	$(Q)profile="$$(grep -oE '^export TF_VAR_oci_config_profile="[^"]+"' "$(CPU_ENV_FILE)" 2>/dev/null | cut -d'"' -f2)"; \
	  profile="$${profile:-TRIVADIS}"; \
	  expires="$$(python3 -c 'import datetime,sys; print((datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(days=int(sys.argv[1]))).strftime("%Y-%m-%dT%H:%M:%S.000Z"))' "$(PAR_DAYS)")"; \
	  echo -e "$(COLOR_BOLD)Minting a pre-authenticated request$(COLOR_RESET)"; \
	  echo "  profile : $$profile"; \
	  echo "  bucket  : $(PAR_BUCKET)"; \
	  echo "  object  : $(PAR_OBJECT)"; \
	  echo "  access  : ObjectRead (single object, no bucket listing)"; \
	  echo "  expires : $$expires  ($(PAR_DAYS) days)"; \
	  uri="$$("$(OCI)" --profile "$$profile" os preauth-request create \
	      --bucket-name "$(PAR_BUCKET)" \
	      --name "$(PAR_NAME)" \
	      --object-name "$(PAR_OBJECT)" \
	      --access-type ObjectRead \
	      --time-expires "$$expires" \
	      --query 'data."full-path"' --raw-output)"; \
	  [[ -n "$$uri" ]] || { echo "❌ PAR creation returned no URI"; exit 1; }; \
	  code="$$(curl -sI -o /dev/null -w '%{http_code}' --max-time 30 "$$uri")"; \
	  size="$$(curl -sI --max-time 30 "$$uri" | tr -d '\r' | awk 'tolower($$1)=="content-length:"{print $$2}')"; \
	  if [[ "$$code" != "200" ]]; then echo "❌ PAR does not serve the object (HTTP $$code)"; exit 1; fi; \
	  echo "  verified: HTTP $$code, content-length $$size"; \
	  touch "$(CPU_ENV_FILE)"; \
	  $(drop_base_image_url); \
	  printf 'export TF_VAR_db_base_image_url="%s"\n' "$$uri" >> "$(CPU_ENV_FILE)"; \
	  echo "  written : $(CPU_ENV_FILE) (git-ignored; token not echoed)"; \
	  echo "$$uri" | sed 's#/p/[^/]*/#/p/<token>/#'
	@echo "✅ PAR ready - next: make cpu-lab-step TAG=download"

.PHONY: cpu-lab-par-list
cpu-lab-par-list: guard-oci ## List existing PARs on the base image bucket
	$(Q)profile="$$(grep -oE '^export TF_VAR_oci_config_profile="[^"]+"' "$(CPU_ENV_FILE)" 2>/dev/null | cut -d'"' -f2)"; \
	  profile="$${profile:-TRIVADIS}"; \
	  "$(OCI)" --profile "$$profile" os preauth-request list --bucket-name "$(PAR_BUCKET)" \
	    --query 'data[].{name:name,object:"object-name",access:"access-type",expires:"time-expires"}' \
	    --output table

.PHONY: cpu-lab-par-revoke
cpu-lab-par-revoke: guard-oci ## Revoke the base-image PARs on the bucket and clear the .env entry
	$(Q)profile="$$(grep -oE '^export TF_VAR_oci_config_profile="[^"]+"' "$(CPU_ENV_FILE)" 2>/dev/null | cut -d'"' -f2)"; \
	  profile="$${profile:-TRIVADIS}"; \
	  ids="$$("$(OCI)" --profile "$$profile" os preauth-request list --bucket-name "$(PAR_BUCKET)" \
	      --query 'data[?name==`$(PAR_NAME)`].id' --raw-output | tr -d '[]", ' | grep . || true)"; \
	  if [[ -z "$$ids" ]]; then echo "No PAR named $(PAR_NAME) found."; exit 0; fi; \
	  for id in $$ids; do \
	    echo "Revoking $$id"; \
	    "$(OCI)" --profile "$$profile" os preauth-request delete --bucket-name "$(PAR_BUCKET)" --par-id "$$id" --force; \
	  done; \
	  $(drop_base_image_url)
	@echo "✅ PAR(s) revoked and removed from $(CPU_ENV_FILE)"

# ==============================================================================
# Gold images
# ==============================================================================
# A self-made gold image is the only gold-image route that works for 19c - the
# Oracle Update Advisor answers HTTP 500 for target_version=19 (see the runbook).
# The artifact is built during a create_home run on the lab host and pushed from
# there: it is several GB and the host is in the same region as the bucket.
#
# Naming scheme, decided 2026-08-21:
#   goldimage-db-<version>-<platform>-<edition>-<date>.zip
#   goldimage-db-<version>-<platform>-<edition>-<date>.patchset.json
# Underscores inside the version because AutoUpgrade rejects dots in
# CREATE_GOLD_IMAGE. The manifest carries the resolved patch set and the
# artifact checksum, so the image describes itself a quarter later.

GOLD_PAR_NAME  := cpu-lab-goldimage-write
GOLD_PAR_HOURS ?= 2

.PHONY: cpu-lab-goldimage-push
cpu-lab-goldimage-push: guard-oci guard-ansible guard-cpu-env ## Push the gold image built on the lab host into the orarepo bucket
	$(Q)profile="$$(grep -oE '^export TF_VAR_oci_config_profile="[^"]+"' "$(CPU_ENV_FILE)" 2>/dev/null | cut -d'"' -f2)"; \
	  profile="$${profile:-TRIVADIS}"; \
	  expires="$$(python3 -c 'import datetime; print((datetime.datetime.now(datetime.UTC) + datetime.timedelta(hours=$(GOLD_PAR_HOURS))).strftime("%Y-%m-%dT%H:%M:%S.000Z"))')"; \
	  echo "Minting a write PAR on $(PAR_BUCKET), valid $(GOLD_PAR_HOURS)h (expires $$expires)"; \
	  uri="$$("$(OCI)" --profile "$$profile" os preauth-request create \
	      --bucket-name "$(PAR_BUCKET)" --name "$(GOLD_PAR_NAME)" \
	      --access-type AnyObjectWrite --time-expires "$$expires" \
	      --query 'data."full-path"' --raw-output)"; \
	  [[ -n "$$uri" ]] || { echo "❌ PAR creation returned no URI"; exit 1; }; \
	  echo "  PAR     : $$(echo "$$uri" | sed 's#/p/[^/]*/#/p/<token>/#')"; \
	  rc=0; \
	  cd "$(ANSIBLE_DIR)" && "$(ANSIBLE)" -i "$(CPU_INVENTORY)" "$(CPU_PLAYBOOK)" \
	    --tags goldimage_push -e db19_gold_image_par="$$uri" $(ANSIBLE_EXTRA) || rc=$$?; \
	  cd - >/dev/null; \
	  echo "Revoking the write PAR"; \
	  ids="$$("$(OCI)" --profile "$$profile" os preauth-request list --bucket-name "$(PAR_BUCKET)" \
	      --query 'data[?name==`$(GOLD_PAR_NAME)`].id' --raw-output | tr -d '[]", ' | grep . || true)"; \
	  for id in $$ids; do \
	    "$(OCI)" --profile "$$profile" os preauth-request delete --bucket-name "$(PAR_BUCKET)" --par-id "$$id" --force; \
	  done; \
	  exit $$rc
	@echo "✅ Gold image and manifest pushed - list with: make cpu-lab-goldimage-list"

.PHONY: cpu-lab-goldimage-list
cpu-lab-goldimage-list: guard-oci ## List the gold images in the orarepo bucket
	$(Q)profile="$$(grep -oE '^export TF_VAR_oci_config_profile="[^"]+"' "$(CPU_ENV_FILE)" 2>/dev/null | cut -d'"' -f2)"; \
	  profile="$${profile:-TRIVADIS}"; \
	  "$(OCI)" --profile "$$profile" os object list --bucket-name "$(PAR_BUCKET)" \
	    --prefix goldimage-db- \
	    --query 'data[].{name:name,size:size,modified:"time-modified"}' --output table

.PHONY: cpu-lab-rollback
cpu-lab-rollback: guard-ansible guard-cpu-env ## Roll the database back to the pre-patch restore point and the old home
	@echo "⚠️  Rollback flashes the database back to the Guaranteed Restore Point"
	@echo "    taken before the patch and restarts it from the base home."
	@if [[ "$(YES)" != "1" ]]; then \
	  read -r -p "    Continue? [y/N] " a; [[ "$$a" == "y" ]] || { echo "aborted"; exit 1; }; \
	fi
	$(Q)cd "$(ANSIBLE_DIR)" && "$(ANSIBLE)" -i "$(CPU_INVENTORY)" "$(CPU_PLAYBOOK)" \
	  --tags rollback $(ANSIBLE_EXTRA)
	@echo "✅ Rollback done - the lab runs from the base home again"

# ==============================================================================
# OCI Bastion sessions
# ==============================================================================
# Alternative to cpu-lab-allow-ip. A Bastion port-forwarding session is
# authorised by IAM, not by source IP, so switching from office WiFi to mobile
# stops mattering. Needs enable_bastion = true in the stack.
#
# Ansible then talks to a local forwarded port instead of the public IP:
#   make cpu-lab-bastion-tunnel
#   make cpu-lab-install ANSIBLE_EXTRA="-e ansible_host=127.0.0.1 -e ansible_port=$(BASTION_LOCAL_PORT)"

BASTION_LOCAL_PORT ?= 2222
BASTION_SESSION_TTL ?= 10800

.PHONY: cpu-lab-bastion-session
cpu-lab-bastion-session: guard-oci guard-terraform ## Create a Bastion port-forwarding session and print the tunnel command
	$(Q)cd "$(CPU_ENV_DIR)" && \
	  set -a; [[ -f .env ]] && . ./.env; set +a; \
	  bid="$$("$(TERRAFORM)" output -raw bastion_id 2>/dev/null || true)"; \
	  if [[ -z "$$bid" || "$$bid" == "null" ]]; then \
	    echo "❌ No Bastion in this stack. Enable it first:"; \
	    echo "   echo 'enable_bastion = true' >> terraform.tfvars && make cpu-lab-apply"; \
	    exit 1; \
	  fi; \
	  ip="$$("$(TERRAFORM)" output -json db_private_ips | python3 -c 'import json,sys;print(list(json.load(sys.stdin).values())[0])')"; \
	  key="$$("$(TERRAFORM)" output -raw lab_private_key_path)"; \
	  profile="$${TF_VAR_oci_config_profile:-TRIVADIS}"; \
	  echo "Bastion : $$bid"; \
	  echo "Target  : $$ip:22"; \
	  sid="$$("$(OCI)" --profile "$$profile" bastion session create-port-forwarding \
	      --bastion-id "$$bid" --target-private-ip "$$ip" --target-port 22 \
	      --ssh-public-key-file "$$key.pub" \
	      --session-ttl "$(BASTION_SESSION_TTL)" \
	      --display-name "cpu-lab-$$(date +%H%M%S)" \
	      --wait-for-state SUCCEEDED --query 'data.resources[0].identifier' --raw-output 2>/dev/null)"; \
	  [[ -n "$$sid" ]] || { echo "❌ Session creation failed"; exit 1; }; \
	  cmd="$$("$(OCI)" --profile "$$profile" bastion session get --session-id "$$sid" \
	      --query 'data."ssh-metadata".command' --raw-output)"; \
	  echo "Session : $$sid"; \
	  echo ""; \
	  echo "Tunnel command (localPort is substituted):"; \
	  echo "$$cmd" | sed -e "s#<privateKey>#$$key#g" -e "s#<localPort>#$(BASTION_LOCAL_PORT)#g"; \
	  echo "$$cmd" | sed -e "s#<privateKey>#$$key#g" -e "s#<localPort>#$(BASTION_LOCAL_PORT)#g" > .bastion-tunnel.cmd; \
	  echo ""; \
	  echo "Then: make cpu-lab-bastion-tunnel   (opens it in the background)"

.PHONY: cpu-lab-bastion-tunnel
cpu-lab-bastion-tunnel: ## Open the last created Bastion tunnel in the background
	$(Q)cd "$(CPU_ENV_DIR)" && \
	  [[ -f .bastion-tunnel.cmd ]] || { echo "❌ No session yet - run: make cpu-lab-bastion-session"; exit 1; }; \
	  if nc -z 127.0.0.1 $(BASTION_LOCAL_PORT) 2>/dev/null; then \
	    echo "Tunnel already listening on 127.0.0.1:$(BASTION_LOCAL_PORT)"; \
	  else \
	    nohup bash -c "$$(cat .bastion-tunnel.cmd) -o StrictHostKeyChecking=no" \
	      >.bastion-tunnel.log 2>&1 & \
	    for i in $$(seq 1 20); do nc -z 127.0.0.1 $(BASTION_LOCAL_PORT) 2>/dev/null && break; sleep 1; done; \
	  fi; \
	  nc -z 127.0.0.1 $(BASTION_LOCAL_PORT) 2>/dev/null \
	    && echo "✅ Tunnel up on 127.0.0.1:$(BASTION_LOCAL_PORT)" \
	    || { echo "❌ Tunnel did not come up - see $(CPU_ENV_DIR)/.bastion-tunnel.log"; exit 1; }
	@echo ""
	@echo "Use it with Ansible:"
	@echo "  make cpu-lab-install ANSIBLE_EXTRA=\"-e ansible_host=127.0.0.1 -e ansible_port=$(BASTION_LOCAL_PORT)\""

.PHONY: cpu-lab-bastion-list
cpu-lab-bastion-list: guard-oci guard-terraform ## List active Bastion sessions
	$(Q)cd "$(CPU_ENV_DIR)" && \
	  set -a; [[ -f .env ]] && . ./.env; set +a; \
	  bid="$$("$(TERRAFORM)" output -raw bastion_id 2>/dev/null || true)"; \
	  [[ -n "$$bid" && "$$bid" != "null" ]] || { echo "No Bastion in this stack."; exit 0; }; \
	  "$(OCI)" --profile "$${TF_VAR_oci_config_profile:-TRIVADIS}" bastion session list \
	    --bastion-id "$$bid" --all \
	    --query 'data[?"lifecycle-state"==`ACTIVE`].{name:"display-name",state:"lifecycle-state",ttl:"session-ttl-in-seconds",created:"time-created"}' \
	    --output table

# ==============================================================================
# Progress and monitoring
# ==============================================================================
# create_home, create_db and patch each run for 30-60 minutes. These targets
# read progress straight off the host via tools/cpu-lab-progress.sh.
#
# The script runs with --become on purpose: the Oracle directories are not
# readable by opc, and without privileges du/find silently return nothing, which
# looks exactly like "nothing is happening" even while dbca sits at 36%.

INTERVAL ?= 30
PROGRESS_SCRIPT := $(TOOLS_DIR)/cpu-lab-progress.sh

.PHONY: cpu-lab-allow-ip
cpu-lab-allow-ip: guard-terraform ## Re-point the SSH allow-list at your current egress IP (NSG only)
	$(Q)ip="$$(curl -s -4 --max-time 15 https://ifconfig.me)"; \
	  [[ "$$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$$ ]] || { echo "❌ Could not determine an IPv4 egress address (got '$$ip')"; exit 1; }; \
	  echo "Current egress IPv4: $$ip"; \
	  cd "$(CPU_ENV_DIR)" && \
	  set -a; [[ -f .env ]] && . ./.env; set +a; \
	  current="$$(grep -oE '^allowed_ssh_cidrs = \[[^]]*\]' terraform.tfvars 2>/dev/null || true)"; \
	  if [[ "$$current" == *"$$ip/32"* ]]; then echo "Already allowed - nothing to do."; exit 0; fi; \
	  grep -v '^allowed_ssh_cidrs' terraform.tfvars > terraform.tfvars.new; \
	  printf 'allowed_ssh_cidrs = ["%s/32"]\n' "$$ip" >> terraform.tfvars.new; \
	  mv -f terraform.tfvars.new terraform.tfvars; \
	  echo "terraform.tfvars updated - applying the NSG rules only"; \
	  "$(TERRAFORM)" apply -input=false -auto-approve \
	    -target=module.oracle_db_host.oci_core_network_security_group_security_rule.ingress_ssh \
	    -target=module.network.oci_core_security_list.public 2>&1 | tail -5
	@echo "✅ SSH allow-list updated - the instance was not touched"

.PHONY: cpu-lab-progress
# When the host is reached through a Bastion tunnel instead of its public IP,
# pass the override through, e.g.
#   make cpu-lab-progress ANSIBLE_EXTRA="-e ansible_host=127.0.0.1 -e ansible_port=2222"
cpu-lab-progress: guard-ansible guard-cpu-env ## Snapshot of the running step on the lab host
	$(Q)cd "$(ANSIBLE_DIR)" && ANSIBLE_HOST_KEY_CHECKING=False ansible \
	  -i "$(CPU_INVENTORY)" cpu_patch_hosts \
	  -m script -a "../$(PROGRESS_SCRIPT)" --become $(ANSIBLE_EXTRA) 2>&1 \
	  | python3 -c 'import sys,re,json;t=sys.stdin.read();m=re.search(r"\"stdout_lines\": (\[.*?\n    \])",t,re.S);print("\n".join(json.loads(m.group(1))) if m else t.strip())'

.PHONY: cpu-lab-watch
cpu-lab-watch: ## Poll cpu-lab-progress every INTERVAL seconds (default 30, Ctrl-C to stop)
	@echo "Polling every $(INTERVAL)s - Ctrl-C to stop"
	$(Q)while true; do \
	  $(MAKE) --no-print-directory cpu-lab-progress ANSIBLE_EXTRA="$(ANSIBLE_EXTRA)" || true; \
	  sleep $(INTERVAL); \
	done

.PHONY: cpu-lab-logs
cpu-lab-logs: guard-terraform ## Print the log locations on the lab host
	@echo "AutoUpgrade global_log_dir : /u00/app/oracle/cfgtoollogs/autoupgrade"
	@echo "  Oracle Updater service   : .../cfgtoollogs/patch/auto/aru/ous.log"
	@echo "  generated configs        : /u00/app/oracle/etc/autoupgrade"
	@echo "  MOS keystore             : /u00/app/oracle/etc/autoupgrade/keystore"
	@echo "dbca                       : /u00/app/oracle/cfgtoollogs/dbca/<SID>"
	@echo "staged media               : /opt/stage"
	@$(MAKE) --no-print-directory cpu-lab-ssh

# ==============================================================================
# Cleanup
# ==============================================================================

.PHONY: clean
clean: ## Remove Terraform plan files and local caches (keeps state)
	@find "$(TF_DIR)" -type f -name "tfplan" -delete 2>/dev/null || true
	@find . -type f -name "*.tmp" -not -path "./.git/*" -delete 2>/dev/null || true
	@find . -type d -name "__pycache__" -not -path "./.git/*" -exec rm -rf {} + 2>/dev/null || true
	@echo "✅ Clean complete"

.PHONY: clean-terraform
clean-terraform: ## Remove .terraform dirs and lock files (state untouched)
	@find "$(TF_DIR)" -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find "$(TF_DIR)" -type f -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@echo "✅ Terraform caches removed - re-run 'make cpu-lab-init'"

# ==============================================================================
# Version Management
# ==============================================================================

.PHONY: version
version: ## Show current version from VERSION file
	@echo "$(VERSION)"

.PHONY: version-bump-patch
version-bump-patch: ## Bump patch (0.0.X) -> commit
	@current="$$(cat VERSION)"; \
	major="$${current%%.*}"; rest="$${current#*.}"; \
	minor="$${rest%%.*}"; patch="$${rest#*.}"; \
	new_version="$$major.$$minor.$$((patch + 1))"; \
	echo "$$new_version" > VERSION; \
	$(GIT) add VERSION; \
	$(GIT) commit -m "chore: bump version to v$$new_version"; \
	echo "✅ Bumped and committed: $$current -> v$$new_version"; \
	echo "   Next: make tag"

.PHONY: version-bump-minor
version-bump-minor: ## Bump minor (0.X.0) -> commit
	@current="$$(cat VERSION)"; \
	major="$${current%%.*}"; rest="$${current#*.}"; \
	minor="$${rest%%.*}"; \
	new_version="$$major.$$((minor + 1)).0"; \
	echo "$$new_version" > VERSION; \
	$(GIT) add VERSION; \
	$(GIT) commit -m "chore: bump version to v$$new_version"; \
	echo "✅ Bumped and committed: $$current -> v$$new_version"; \
	echo "   Next: make tag"

.PHONY: version-bump-major
version-bump-major: ## Bump major (X.0.0) -> commit
	@current="$$(cat VERSION)"; \
	major="$${current%%.*}"; \
	new_version="$$((major + 1)).0.0"; \
	echo "$$new_version" > VERSION; \
	$(GIT) add VERSION; \
	$(GIT) commit -m "chore: bump version to v$$new_version"; \
	echo "✅ Bumped and committed: $$current -> v$$new_version"; \
	echo "   Next: make tag"

# ==============================================================================
# Release Management
# ==============================================================================

.PHONY: tag
tag: ## Create git tag from VERSION (guards: clean tree + VERSION committed)
	@if [[ -z "$(GIT)" ]]; then echo "Error: git not found in PATH"; exit 1; fi; \
	version="$$(cat VERSION)"; \
	tag="v$$version"; \
	if ! $(GIT) diff --quiet HEAD 2>/dev/null; then \
		echo "❌ Working tree is dirty - commit all changes before tagging:"; \
		$(GIT) status -sb; \
		exit 1; \
	fi; \
	committed="$$($(GIT) show HEAD:VERSION 2>/dev/null | tr -d '[:space:]')"; \
	if [[ "$$committed" != "$$version" ]]; then \
		echo "❌ VERSION ($$version) not yet committed (HEAD has: $$committed)"; \
		echo "   Run: git add VERSION CHANGELOG.md && git commit -m 'chore: bump version to v$$version'"; \
		exit 1; \
	fi; \
	if $(GIT) rev-parse "$$tag" >/dev/null 2>&1; then \
		echo "❌ Tag $$tag already exists"; \
		exit 1; \
	fi; \
	$(GIT) tag -a "$$tag" -m "Release $$tag"; \
	echo "✅ Created tag $$tag"; \
	echo ""; \
	echo "   Push manually:"; \
	echo "     git push origin main"; \
	echo "     git push origin $$tag"

.PHONY: release
release: ## Full patch release: bump patch -> commit -> tag
	@echo "🚀 Starting patch release..."
	@$(MAKE) --no-print-directory version-bump-patch
	@$(MAKE) --no-print-directory tag
	@version="$$(cat VERSION)"; \
	echo "🎉 Release v$$version complete!"; \
	echo ""; \
	echo "   Push manually:"; \
	echo "     git push origin main"; \
	echo "     git push origin v$$version"

# ==============================================================================
# Info
# ==============================================================================

.PHONY: status
status: ## Show git status, version, and lab state
	@echo -e "$(COLOR_BOLD)Project status$(COLOR_RESET)"
	@echo "Version: $(VERSION)"
	@echo ""
	@echo -e "$(COLOR_BOLD)cpu-patch-test$(COLOR_RESET)"
	@if [[ -f "$(CPU_ENV_DIR)/terraform.tfstate" ]]; then \
	  echo "  state     : present"; \
	else \
	  echo "  state     : not deployed"; \
	fi
	@if [[ -f "$(CPU_INVENTORY_ABS)" ]]; then \
	  echo "  inventory : $(CPU_INVENTORY_ABS)"; \
	else \
	  echo "  inventory : not generated"; \
	fi
	@if [[ -f "$(CPU_ENV_FILE)" ]]; then \
	  echo "  .env      : present"; \
	else \
	  echo "  .env      : missing (copy from .env.example)"; \
	fi
	@if [[ -n "$(GIT)" ]]; then \
	  echo ""; \
	  $(GIT) status -sb; \
	fi

# --- EOF ----------------------------------------------------------------------
