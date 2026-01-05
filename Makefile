# Homelab Infrastructure Makefile
.PHONY: help tf-init tf-plan tf-apply kubeconfig talos-upgrade argocd docs clean

ENV ?= talos_cluster
TF_DIR := terraform/envs/$(ENV)

help:
	@echo "Homelab Makefile"
	@echo ""
	@echo "Terraform:"
	@echo "  tf-init         Initialize Terraform"
	@echo "  tf-plan         Plan infrastructure changes"
	@echo "  tf-apply        Apply infrastructure changes"
	@echo ""
	@echo "Kubernetes:"
	@echo "  kubeconfig      Export cluster kubeconfig to ~/.kube/config"
	@echo "  argocd          Access ArgoCD UI (port-forward)"
	@echo ""
	@echo "Talos:"
	@echo "  talos-upgrade   Upgrade all Talos nodes to latest version"
	@echo ""
	@echo "Docs:"
	@echo "  docs            Serve documentation"
	@echo ""
	@echo "Utility:"
	@echo "  clean           Clean build artifacts"

# Terraform
tf-init:
	@cd $(TF_DIR) && terraform init

tf-plan:
	@cd $(TF_DIR) && terraform plan

tf-apply:
	@cd $(TF_DIR) && terraform apply

# Kubernetes
kubeconfig:
	@KUBECONFIG_SRC=$(TF_DIR)/output/kubeconfig; \
	KUBECONFIG_DST=$$HOME/.kube/config; \
	if [ ! -f "$$KUBECONFIG_SRC" ]; then \
		echo "❌ Kubeconfig not found at $$KUBECONFIG_SRC"; \
		echo "Run 'make tf-apply' first"; \
		exit 1; \
	fi; \
	mkdir -p $$HOME/.kube; \
	if [ -f "$$KUBECONFIG_DST" ]; then \
		cp "$$KUBECONFIG_DST" "$$KUBECONFIG_DST.backup"; \
		KUBECONFIG="$$KUBECONFIG_DST:$$KUBECONFIG_SRC" kubectl config view --flatten > "$$KUBECONFIG_DST.tmp"; \
		mv "$$KUBECONFIG_DST.tmp" "$$KUBECONFIG_DST"; \
		chmod 600 "$$KUBECONFIG_DST"; \
		echo "✅ Kubeconfig merged"; \
	else \
		cp "$$KUBECONFIG_SRC" "$$KUBECONFIG_DST"; \
		chmod 600 "$$KUBECONFIG_DST"; \
		echo "✅ Kubeconfig exported"; \
	fi; \
	echo "Current context: $$(kubectl config current-context)"

argocd:
	@echo "ArgoCD admin password:"
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d && echo
	@echo ""
	@echo "Access UI at: https://localhost:8080"
	@echo "Username: admin"
	@kubectl port-forward svc/argocd-server -n argocd 8080:443

# Talos
talos-upgrade:
	@if ! command -v talosctl &> /dev/null; then \
		echo "❌ talosctl not found. Install with:"; \
		echo "   brew install siderolabs/tap/talosctl"; \
		exit 1; \
	fi
	@./scripts/talos-upgrade.sh

# Docs
docs:
	@zensical serve

# Utility
clean:
	@find terraform -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@find terraform -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@rm -rf site/
	@echo "✅ Clean complete"

