# =============================================================================
# Homelab Infrastructure Makefile
#
# This Makefile provides targets for:
#   - Building Packer images
#   - Managing OpenTofu/Terraform infrastructure
#   - Bootstrapping Kubernetes with Argo CD
#   - Documentation generation
#   - Validation and linting (preflight)
#
# Refs: Req 6.1, 6.2, 6.3, 6.4, 6.5
# =============================================================================

.PHONY: help packer tf-init tf-plan tf-apply tf-destroy \
        k8s-bootstrap argo k8s-diff \
        preflight clean \
        docs docs-build docs-clean

# -----------------------------------------------------------------------------
# Configuration Variables
# -----------------------------------------------------------------------------

# AlmaLinux version
ALMA_VERSION ?= 9.6

# k3s version to install
K3S_VERSION ?= v1.31.3+k3s1

# Environment for Terraform operations (k3s-single, etc.)
ENV ?= k3s-single

# Packer directory
PACKER_DIR := packer/alma9-k3s-optimized

# Terraform directory
TF_DIR := terraform/envs/$(ENV)

# Kubernetes cluster directory
K8S_DIR := k8s/clusters/home

# -----------------------------------------------------------------------------
# Default Target
# -----------------------------------------------------------------------------

help:
	@echo "Homelab Infrastructure Makefile"
	@echo ""
	@echo "Configuration:"
	@echo "  ALMA_VERSION  = $(ALMA_VERSION)"
	@echo "  K3S_VERSION   = $(K3S_VERSION)"
	@echo "  ENV           = $(ENV)"
	@echo ""
	@echo "Packer Targets:"
	@echo "  packer          - Initialize and build Packer image"
	@echo ""
	@echo "Terraform Targets:"
	@echo "  tf-init         - Initialize Terraform for ENV"
	@echo "  tf-plan         - Plan Terraform changes for ENV"
	@echo "  tf-apply        - Apply Terraform changes for ENV"
	@echo "  tf-destroy      - Destroy Terraform resources for ENV"
	@echo ""
	@echo "Kubernetes Targets:"
	@echo "  k8s-bootstrap   - Apply bootstrap manifests (Argo CD)"
	@echo "  argo            - Apply app-of-apps root application"
	@echo "  k8s-diff        - Show diff of Kubernetes manifests"
	@echo ""
	@echo "Utility Targets:"
	@echo "  preflight       - Run all format, validate, and lint checks"
	@echo "  clean           - Clean build artifacts"
	@echo ""
	@echo "Documentation Targets:"
	@echo "  docs            - Serve documentation with live reload"
	@echo "  docs-build      - Build documentation site"
	@echo "  docs-clean      - Clean documentation artifacts"
	@echo ""
	@echo "Examples:"
	@echo "  make packer ALMA_VERSION=9.6 K3S_VERSION=v1.31.3+k3s1"
	@echo "  make tf-apply ENV=k3s-single"
	@echo "  make k8s-bootstrap"

# -----------------------------------------------------------------------------
# Packer Targets (Req 6.1)
# -----------------------------------------------------------------------------

packer:
	@echo "==> Building Packer image: AlmaLinux $(ALMA_VERSION) + k3s $(K3S_VERSION)"
	@if [ -z "$$PKR_VAR_proxmox_token" ]; then \
		echo "ERROR: PKR_VAR_proxmox_token environment variable is not set"; \
		echo "Set it with: export PKR_VAR_proxmox_token='your-token'"; \
		exit 1; \
	fi
	cd $(PACKER_DIR) && \
		packer init . && \
		packer build \
			-var "alma_version=$(ALMA_VERSION)" \
			-var "k3s_version=$(K3S_VERSION)" \
			.

packer-validate:
	@echo "==> Validating Packer configuration..."
	cd $(PACKER_DIR) && packer init . && packer validate -syntax-only .

packer-fmt:
	@echo "==> Formatting Packer files..."
	packer fmt -recursive packer/

# -----------------------------------------------------------------------------
# Terraform/OpenTofu Targets (Req 6.2, 6.3)
# -----------------------------------------------------------------------------

tf-init:
	@echo "==> Initializing Terraform for $(ENV)..."
	cd $(TF_DIR) && tofu init || terraform init

tf-plan:
	@echo "==> Planning Terraform changes for $(ENV)..."
	cd $(TF_DIR) && \
		(tofu plan -var-file=../../globals.tfvars || \
		 terraform plan -var-file=../../globals.tfvars)

tf-apply:
	@echo "==> Applying Terraform changes for $(ENV)..."
	cd $(TF_DIR) && \
		(tofu apply -var-file=../../globals.tfvars || \
		 terraform apply -var-file=../../globals.tfvars)

tf-destroy:
	@echo "==> Destroying Terraform resources for $(ENV)..."
	cd $(TF_DIR) && \
		(tofu destroy -var-file=../../globals.tfvars || \
		 terraform destroy -var-file=../../globals.tfvars)

tf-fmt:
	@echo "==> Formatting Terraform files..."
	(tofu fmt -recursive terraform/ || terraform fmt -recursive terraform/)

tf-validate:
	@echo "==> Validating Terraform configuration..."
	cd $(TF_DIR) && (tofu validate || terraform validate)

# -----------------------------------------------------------------------------
# Kubernetes Targets (Req 6.4, 6.5)
# -----------------------------------------------------------------------------

k8s-bootstrap:
	@echo "==> Applying bootstrap manifests (Argo CD)..."
	kubectl apply -k $(K8S_DIR)/bootstrap

argo:
	@echo "==> Applying app-of-apps root application..."
	kubectl apply -f k8s/argo/app-of-apps.yaml

k8s-diff:
	@echo "==> Showing Kubernetes manifest diff..."
	kubectl diff -k $(K8S_DIR) || true

# -----------------------------------------------------------------------------
# Utility Targets (Req 8.3)
# -----------------------------------------------------------------------------

preflight:
	@echo "==> Running preflight checks..."
	./scripts/preflight.sh

clean:
	@echo "==> Cleaning build artifacts..."
	rm -rf packer/**/output/
	rm -f packer/**/manifest.json
	find terraform -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	find terraform -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	rm -rf site/
	@echo "==> Clean complete."

# -----------------------------------------------------------------------------
# Documentation Targets
# -----------------------------------------------------------------------------

docs:
	@echo "Starting documentation server..."
	@echo "Documentation will be available at http://127.0.0.1:8000"
	zensical serve

docs-build:
	@echo "Building documentation..."
	zensical build

docs-clean:
	@echo "Cleaning documentation build artifacts..."
	rm -rf site/
