# =============================================================================
# MAKEFILE - infra-core (multi-stack with Terragrunt)
#
# Usage:
#   make plan STACK=icl          -> plan a single stack
#   make plan-all                -> plan all stacks
#   make apply STACK=icl         -> apply a single stack
#   make resources STACK=shared  -> list resources in a stack
# =============================================================================

# --- VARIABLES ---
STACKS_DIR  = ./stacks
MOD_DIR     = ./modules
STACK       ?=                          # Set per command: make plan STACK=icl
STACK_PATH  = $(STACKS_DIR)/$(STACK)
PLAN_FILE = terraform.tfplan
ALL_STACKS  = $(wildcard $(STACKS_DIR)/*)

# --- GUARDS ---
# Dependency to require STACK parameter
require-stack:
	@if [ -z "$(STACK)" ]; then \
		echo "Error: STACK is required. Usage: make <target> STACK=<name>"; \
		echo "Available stacks:"; \
		ls -1 $(STACKS_DIR); \
		exit 1; \
	fi
	@if [ ! -d "$(STACK_PATH)" ]; then \
		echo "Error: stack '$(STACK)' not found in $(STACKS_DIR)/"; \
		echo "Available stacks:"; \
		ls -1 $(STACKS_DIR); \
		exit 1; \
	fi

# --- HELPERS ---
define AWS_IDENTITY
	@echo "-----------------------"
	@echo "Current AWS Identity:"
	@AWS_PAGER="" aws sts get-caller-identity --query "Arn" --output text
	@echo "-----------------------"
endef

define TFPLAN_SUMMARY
	@chmod u+x scripts/tf-plan-summary.sh
	@./scripts/tf-plan-summary.sh $(STACK_PATH)/$(PLAN_FILE)
	@chmod u-x scripts/tf-plan-summary.sh
endef

.PHONY: all init plan apply destroy resources show state output \
        init-all plan-all apply-all \
        fmt validate security prec prec-all help

# =============================================================================
# SINGLE STACK COMMANDS - require STACK=<name>
# =============================================================================

init: require-stack ## Initialize a stack - make init STACK=icl
	$(AWS_IDENTITY)
	@echo "Initializing $(STACK)..."
	@cd $(STACK_PATH) && terragrunt init

plan: require-stack ## Plan a stack - make plan STACK=icl
	$(AWS_IDENTITY)
	@echo "Planning $(STACK)..."
	@cd $(STACK_PATH) && terragrunt plan -out=$(PLAN_FILE)
	$(TFPLAN_SUMMARY)

apply: require-stack ## Apply a stack - make apply STACK=icl
	$(AWS_IDENTITY)
	@echo "Applying $(STACK)..."
	@cd $(STACK_PATH) && terragrunt apply $(PLAN_FILE)

destroy: require-stack ## Destroy a stack - make destroy STACK=icl
	$(AWS_IDENTITY)
	@echo "WARNING: Destroying $(STACK)"
	@cd $(STACK_PATH) && terragrunt destroy

resources: require-stack ## List resources - make resources STACK=icl
	$(AWS_IDENTITY)
	@cd $(STACK_PATH) && terragrunt state list

show: require-stack ## Show a resource - make show STACK=icl RES=aws_iam_policy.x
	$(AWS_IDENTITY)
	@cd $(STACK_PATH) && terragrunt state show $(RES)

state: require-stack ## Pull state - make state STACK=icl
	$(AWS_IDENTITY)
	@cd $(STACK_PATH) && terragrunt state pull

output: require-stack ## Show outputs - make output STACK=icl
	$(AWS_IDENTITY)
	@cd $(STACK_PATH) && terragrunt output -json | jq '.'

# =============================================================================
# ALL STACKS COMMANDS - runs against every stack in stacks/
# =============================================================================

init-all: ## Initialize all stacks
	$(AWS_IDENTITY)
	@for stack in $(ALL_STACKS); do \
		echo "=== Init: $$(basename $$stack) ==="; \
		(cd $$stack && terragrunt init) || exit 1; \
	done

plan-all: ## Plan all stacks
	$(AWS_IDENTITY)
	@for stack in $(ALL_STACKS); do \
		echo "=== Plan: $$(basename $$stack) ==="; \
		(cd $$stack && terragrunt plan) || exit 1; \
	done

apply-all: ## Apply all stacks (runs sequentially, stops on error)
	$(AWS_IDENTITY)
	@echo "WARNING: Applying ALL stacks"
	@for stack in $(ALL_STACKS); do \
		echo "=== Apply: $$(basename $$stack) ==="; \
		(cd $$stack && terragrunt apply) || exit 1; \
	done

# =============================================================================
# QUALITY AND SECURITY
# =============================================================================

fmt: ## Format all Terraform code
	@echo "Formatting..."
	@terraform fmt -recursive $(STACKS_DIR)
	@terraform fmt -recursive $(MOD_DIR)

validate: require-stack ## Validate a stack - make validate STACK=icl
	@echo "Validating $(STACK)..."
	@cd $(STACK_PATH) && terragrunt validate

security: ## Security scan all stacks and modules
	@echo "Scanning for vulnerabilities..."
	@tfsec $(STACKS_DIR)
	@tfsec $(MOD_DIR)
	@echo "tfsec done... next checkov"
	@checkov -d $(STACKS_DIR) --quiet
	@checkov -d $(MOD_DIR) --quiet

# =============================================================================
# PRE-COMMIT
# =============================================================================

prec: ## Run pre-commit on staged files
	@pre-commit run

prec-all: ## Run pre-commit on all files
	@pre-commit run --all-files

# =============================================================================
# UTILITIES
# =============================================================================

stacks: ## List available stacks
	@echo "Available stacks:"
	@ls -1 $(STACKS_DIR)

help: ## Show this help menu
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'
