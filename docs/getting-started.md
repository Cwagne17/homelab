---
icon: material/rocket-launch
---

# Getting Started

Welcome! This guide will help you deploy the homelab infrastructure from scratch.

## What You'll Learn

- Prerequisites and required tools
- Installation steps
- Configuration basics
- Your first deployment

## Prerequisites

Before you begin, ensure you have:

### Hardware Requirements

- **Proxmox VE Server**: Physical server or nested virtualization
  - Minimum: 8GB RAM, 4 CPU cores, 100GB storage
  - Recommended: 32GB+ RAM, 8+ CPU cores, 500GB+ storage
- **Development Machine**: Linux, macOS, or Windows with WSL2
- **Network**: Connectivity between your machine and Proxmox

### Software Requirements

- Basic knowledge of Linux, VMs, and Kubernetes
- Git for version control
- SSH access to Proxmox host

## Installation

Install the required tools on your development machine:

### 1. Install Atmos

**macOS (Homebrew)**

```bash
brew install atmos
```

**Linux**

```bash
curl -fsSL https://atmos.tools/install.sh | bash
```

**Verify**

```bash
atmos version
```

### 2. Install Packer

**macOS (Homebrew)**

```bash
brew install packer
```

**Linux**

```bash
# Download from https://www.packer.io/downloads
```

**Verify**

```bash
packer version
```

### 3. Install OpenTofu

**macOS (Homebrew)**

```bash
brew install opentofu
```

**Linux**

```bash
# Download from https://opentofu.org/docs/intro/install/
```

**Verify**

```bash
tofu version
```

### 4. Install kubectl

**macOS (Homebrew)**

```bash
brew install kubectl
```

**Linux**

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

**Verify**

```bash
kubectl version --client
```

## Configuration

### 1. Clone the Repository

```bash
git clone https://github.com/cwagne17/homelab.git
cd homelab
```

### 2. Configure Proxmox Access

Set up API credentials:

```bash
export PROXMOX_TOKEN="your-api-token"
export PM_API_TOKEN_SECRET="your-api-token"
```

### 3. Validate Configuration

```bash
atmos validate stacks
```

## Quick Deploy

Deploy the entire stack:

```bash
atmos workflow deploy-homelab -f stacks/workflows/deploy.yaml
```

This will:

1. Build a k3s-optimized AlmaLinux 9 image
2. Provision a VM on Proxmox
3. Bootstrap Kubernetes with Argo CD
4. Deploy applications via GitOps

## Next Steps

- [Configure Proxmox](proxmox/setup.md) in detail
- [Build custom images](packer/building.md) with Packer
- [Deploy infrastructure](opentofu/infrastructure.md) with OpenTofu
- [Manage Kubernetes](k3s/cluster.md) clusters

## Troubleshooting

### Common Issues

**Packer build fails**

- Check Proxmox API credentials
- Verify network connectivity
- Ensure sufficient storage space

**OpenTofu apply fails**

- Verify template exists in Proxmox
- Check VM resource availability
- Review OpenTofu state

**Kubernetes bootstrap fails**

- Verify VM is running
- Check k3s service status
- Review kubectl connectivity

## Getting Help

- **GitHub Issues**: Report bugs or request features
- **Documentation**: Browse the other sections
- **Community**: Connect on [LinkedIn](https://www.linkedin.com/in/cwagnerdevops)
