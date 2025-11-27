# Homelab Documentation

Welcome to the Homelab Infrastructure documentation. This site provides comprehensive guides for building and managing a production-grade homelab using modern DevOps practices.

## Why This Project?

This homelab demonstrates **Infrastructure as Code (IaC)** principles applied to a virtualized environment:

- **Reproducibility**: Every component is defined in code
- **Version Control**: All configurations are tracked in Git
- **Automation**: End-to-end workflows with minimal manual steps
- **Best Practices**: Production patterns adapted for homelab scale

## Documentation Sections

| Section | Description |
|---------|-------------|
| [Packer](packer/index.md) | Build k3s-optimized VM images with automated provisioning |
| [OpenTofu](opentofu/index.md) | Provision and manage Proxmox infrastructure declaratively |
| [K3s/Kubernetes](k3s/index.md) | Deploy and manage applications with GitOps |
| [Proxmox](proxmox/index.md) | Configure and operate the virtualization platform |

## Quick Links

- [Getting Started](getting-started.md) - Setup your development environment
- [Makefile Workflows](getting-started.md#quick-deploy) - Common automation targets
- [Contributing](contribute.md) - How to contribute to this project

## Repository Structure

```
homelab/
├── packer/                    # VM image building
│   └── alma9-k3s-optimized/   # AlmaLinux 9 + k3s template
├── terraform/                 # Infrastructure provisioning
│   ├── modules/proxmox-vm/    # Reusable VM module
│   └── envs/k3s-single/       # Single-node k3s environment
├── k8s/                       # Kubernetes manifests
│   ├── argo/                  # Argo CD app-of-apps
│   └── clusters/home/         # Cluster configurations
├── scripts/                   # Helper scripts
├── docs/                      # This documentation site
└── Makefile                   # Workflow automation
```

## Makefile Targets

The Makefile provides convenient targets for common operations:

```bash
# Image building
make packer

# Infrastructure
make tf-init ENV=k3s-single
make tf-plan ENV=k3s-single
make tf-apply ENV=k3s-single

# Kubernetes
make k8s-bootstrap
make argo

# Validation
make preflight

# Documentation
make docs
```

---

For detailed setup instructions, start with the [Getting Started](getting-started.md) guide.
