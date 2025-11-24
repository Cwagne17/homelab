---
icon: material/rocket-launch
---

# Getting Started

Welcome! This guide will help you understand and deploy the homelab infrastructure.

## What You'll Learn

- How the infrastructure components work together
- Prerequisites for running the homelab
- Step-by-step deployment process
- How to customize for your environment

## Architecture Overview

The homelab uses a pipeline approach:

1. **Packer** builds golden VM images with k3s pre-installed
2. **OpenTofu** provisions VMs on Proxmox from those images
3. **K3s** provides the Kubernetes platform
4. **Argo CD** deploys applications via GitOps

## Quick Deploy

For the impatient, here's the one-command deployment:

```bash
atmos workflow deploy-homelab -f stacks/workflows/deploy.yaml
```

!!! warning "Prerequisites Required"
Make sure you've completed the [Setup](../setup/index.md) steps first!

## Next Steps

1. [Check Prerequisites](../setup/prerequisites.md)
2. [Install Required Tools](../setup/installation.md)
3. [Configure Proxmox](../proxmox/setup.md)
4. [Build Your First Image](../packer/building.md)
