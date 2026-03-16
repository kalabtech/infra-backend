# =============================================================================
# MAKEFILE - single environment (prod)
#
# Usage:
#   make init        -> initialize backend
#   make plan        -> plan changes
#   make apply       -> apply changes
#   make resources   -> list resources in state
# =============================================================================

# --- VARIABLES ---
TF_DIR     = ./infra
DOCS_DIR   = ./docs/obsidian
MOD_DIR    = ./modules
STATE_FILE = prod.tfplan

# --- HELPERS ---
define AWS_IDENTITY
	@echo "-----------------------"
	@echo "Current AWS Identity:"
	@AWS_PAGER="" aws sts get-caller-identity --query "Arn" --output text
	@echo "-----------------------"
endef

define TFPLAN_SUMMARY
	@chmod u+x scripts/tfplan_summary.sh
	@./scripts/tfplan_summary.sh $(TF_DIR)/$(STATE_FILE)
	@chmod u-x scripts/tfplan_summary.sh
endef

.PHONY: all verify-identity init plan apply destroy \
        resources show state output validate check prec prec-all docs help

# Default action
all: check validate plan

# =============================================================================
# AWS
# =============================================================================

verify-identity: ## Show current AWS identity
	$(AWS_IDENTITY)

# =============================================================================
# TERRAFORM COMMANDS
# =============================================================================

init: ## Initialize backend
	$(AWS_IDENTITY)
	@echo "Initializing..."
	@terraform -chdir=$(TF_DIR) init -backend-config=../backends/prod.hcl -reconfigure

plan: ## Generate execution plan
	$(AWS_IDENTITY)
	@echo "Generating plan..."
	@terraform -chdir=$(TF_DIR) plan -var-file=../environments/prod.tfvars -out=$(STATE_FILE)
	$(TFPLAN_SUMMARY)

apply: ## Apply changes
	$(AWS_IDENTITY)
	@echo "Applying changes..."
	@terraform -chdir=$(TF_DIR) apply $(STATE_FILE)

destroy: ## Destroy infrastructure
	$(AWS_IDENTITY)
	@echo "WARNING: Destroying infrastructure."
	@terraform -chdir=$(TF_DIR) destroy -var-file=../environments/prod.tfvars

resources: ## List all tfstate resources
	$(AWS_IDENTITY)
	@terraform -chdir=$(TF_DIR) state list

show: ## Show resource in tfstate - make show RES=aws_iam_policy.x
	$(AWS_IDENTITY)
	@terraform -chdir=$(TF_DIR) state show $(RES)

state: ## Pull tfstate
	$(AWS_IDENTITY)
	@terraform -chdir=$(TF_DIR) state pull

output: ## Show tfstate outputs
	$(AWS_IDENTITY)
	@terraform -chdir=$(TF_DIR) output -json | jq '.'

# =============================================================================
# QUALITY AND SECURITY
# =============================================================================

validate: ## Format and validate Terraform code
	@echo "Formatting code..."
	@terraform fmt -recursive $(TF_DIR)
	@terraform fmt -recursive $(MOD_DIR)
	@echo "Validating code..."
	@cd $(TF_DIR) && terraform validate
	@cd $(MOD_DIR) && terraform validate

check: ## Security scan infra and modules
	@echo "-----------------------"
	@echo "Running TFLint..."
	@tflint --chdir=$(TF_DIR) --config=$(CURDIR)/.tflint.hcl
	@tflint --chdir=$(MOD_DIR) --recursive --config=$(CURDIR)/.tflint.hcl
	@echo "-----------------------"
	@echo "Scanning for vulnerabilities..."
	@trivy config --severity MEDIUM,HIGH,CRITICAL $(TF_DIR)
	@trivy config --severity MEDIUM,HIGH,CRITICAL $(MOD_DIR)

lint-init: ## Install tflint plugins
	tflint --init --chdir=$(TF_DIR)
	tflint --init --chdir=$(MOD_DIR)

# =============================================================================
# PRE-COMMIT
# =============================================================================

prec: ## Run pre-commit on staged files
	@pre-commit run

prec-all: ## Run pre-commit on all files
	@pre-commit run --all-files

# =============================================================================
# DOCUMENTATION
# =============================================================================

docs: ## Generate Markdown docs for Obsidian
	@mkdir -p $(DOCS_DIR)
	@echo "Updating Obsidian documentation..."
	@terraform-docs markdown table $(TF_DIR) > $(DOCS_DIR)/infrastructure-prod.md
	@echo "Documentation updated at $(DOCS_DIR)/infrastructure-prod.md"

# =============================================================================
# UTILITIES
# =============================================================================

help: ## Show this help menu
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'
