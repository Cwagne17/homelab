---
icon: material/terraform
---

# OpenTofu Infrastructure

OpenTofu is an open-source infrastructure-as-code tool for provisioning and managing cloud infrastructure.

## Overview

OpenTofu manages all infrastructure in the homelab:

- **Declarative Configuration**: Infrastructure defined as code
- **Proxmox Provider**: Automated VM provisioning
- **State Management**: Track infrastructure changes
- **Modular Design**: Reusable components

## Infrastructure Components

- **k3s Cluster**: Single-node Kubernetes cluster
- **VM Configuration**: CPU, memory, disk, networking
- **Cloud-init**: Automated VM initialization
- **Networking**: Static IP configuration

## Next Steps

- [Infrastructure](infrastructure.md) - Deploy infrastructure
- [Modules](modules.md) - Reusable OpenTofu modules
