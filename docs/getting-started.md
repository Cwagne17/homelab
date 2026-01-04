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

### 2. Install Talos CLI

**macOS (Homebrew)**

```bash
brew install siderolabs/tap/talosctl
```

**Linux**

```bash
curl -sL https://talos.dev/install | sh
```

**Verify**

```bash
talosctl version
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

Deploy the Talos cluster:

```bash
make tf-apply ENV=talos_cluster
```

This will:

1. Download Talos Linux image to Proxmox
2. Provision VMs with Talos
3. Bootstrap Kubernetes cluster
4. Generate kubeconfig for cluster access

### Export Kubeconfig

```bash
make k8s-kubeconfig
```

## Next Steps

- [Configure Proxmox](proxmox/setup.md) in detail
- [Deploy Talos cluster](talos/index.md) with OpenTofu
- [Manage infrastructure](opentofu/infrastructure.md) with OpenTofu
- [Configure Kubernetes](k3s/cluster.md) clusters

## Troubleshooting

### Common Issues

**OpenTofu apply fails**

- Verify Proxmox API credentials
- Check VM resource availability
- Review OpenTofu state
- Ensure SSH access to Proxmox is configured

**Talos cluster bootstrap fails**

- Verify VMs are running
- Check network connectivity to control plane
- Review talosctl logs
- Verify machine configurations were applied

**Kubeconfig not working**

- Ensure cluster health check passed
- Verify control plane endpoint is reachable
- Run `make k8s-kubeconfig` to export config

## Getting Help

- **GitHub Issues**: Report bugs or request features
- **Documentation**: Browse the other sections
- **Community**: Connect on [LinkedIn](https://www.linkedin.com/in/cwagnerdevops)
