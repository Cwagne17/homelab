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
        k8s-dev-start k8s-dev-stop k8s-dev-deploy k8s-argocd \
        k8s-bootstrap argo k8s-diff k8s-kubeconfig \
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
K8S_DIR := k8s

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
	@echo "  k8s-dev-start   - Create local kind cluster for development"
	@echo "  k8s-dev-stop    - Delete local kind cluster"
	@echo "  k8s-dev-deploy  - Deploy dev overlay to kind cluster"
	@echo "  k8s-argocd  - Access Argo CD UI on kind cluster"
	@echo "  k8s-kubeconfig  - Export Talos cluster kubeconfig to ~/.kube/config"
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

# Local Development Cluster
k8s-dev-start:
	@echo "==> Starting local development Kubernetes cluster with kind..."
	@if ! command -v kind &> /dev/null; then \
		echo "ERROR: kind is not installed"; \
		echo "Install with: brew install kind"; \
		exit 1; \
	fi
	@if kind get clusters | grep -q homelab-dev; then \
		echo "Cluster 'homelab-dev' already exists"; \
	else \
		kind create cluster --name homelab-dev; \
	fi
	@echo ""
	@echo "Cluster ready! Next steps:"
	@echo "  1. Install ArgoCD:  make k8s-bootstrap"
	@echo "  2. Deploy apps:     make k8s-dev-deploy"
	@echo "  3. Access ArgoCD:   make k8s-dev-argocd"

k8s-dev-stop:
	@echo "==> Stopping local development cluster..."
	kind delete cluster --name homelab-dev

k8s-argocd:
	@echo "==> Accessing ArgoCD UI..."
	@echo "Getting admin password..."
	@kubectl -n argocd get secret argocd-initial-admin-secret \
		-o jsonpath="{.data.password}" 2>/dev/null | base64 -d && echo
	@echo ""
	@echo "Port-forwarding to ArgoCD server..."
	@echo "Access UI at: https://localhost:8080"
	@echo "Username: admin"
	kubectl port-forward svc/argocd-server -n argocd 8080:443

argo:
	@echo "==> Applying app-of-apps root application..."
	kubectl apply -f k8s/argo/app-of-apps.yaml

k8s-diff:
	@echo "==> Showing Kubernetes manifest diff..."
	kubectl diff -k $(K8S_DIR) || true

k8s-kubeconfig:
	@echo "==> Exporting Talos cluster kubeconfig..."
	@KUBECONFIG_SRC=terraform/envs/talos_cluster/output/kubeconfig; \
	KUBECONFIG_DST=$$HOME/.kube/config; \
	if [ ! -f "$$KUBECONFIG_SRC" ]; then \
		echo "ERROR: Kubeconfig not found at $$KUBECONFIG_SRC"; \
		echo "Have you run 'make tf-apply ENV=talos_cluster' yet?"; \
		exit 1; \
	fi; \
	mkdir -p $$HOME/.kube; \
	if [ -f "$$KUBECONFIG_DST" ]; then \
		echo "Backing up existing kubeconfig to $$KUBECONFIG_DST.backup"; \
		cp "$$KUBECONFIG_DST" "$$KUBECONFIG_DST.backup"; \
		echo "Merging Talos kubeconfig with existing config..."; \
		KUBECONFIG="$$KUBECONFIG_DST:$$KUBECONFIG_SRC" kubectl config view --flatten > "$$KUBECONFIG_DST.tmp"; \
		mv "$$KUBECONFIG_DST.tmp" "$$KUBECONFIG_DST"; \
		chmod 600 "$$KUBECONFIG_DST"; \
		echo "Kubeconfig merged successfully!"; \
	else \
		echo "Copying Talos kubeconfig to $$KUBECONFIG_DST"; \
		cp "$$KUBECONFIG_SRC" "$$KUBECONFIG_DST"; \
		chmod 600 "$$KUBECONFIG_DST"; \
		echo "Kubeconfig copied successfully!"; \
	fi; \
	echo ""; \
	echo "Current context: $$(kubectl config current-context)"; \
	echo "Available contexts:"; \
	kubectl config get-contexts

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
