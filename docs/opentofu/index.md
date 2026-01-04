---
icon: material/terraform
---

# OpenTofu Infrastructure

OpenTofu is an open-source infrastructure-as-code tool for provisioning and managing cloud infrastructure.

## Overview

OpenTofu manages all infrastructure in the homelab:

- **Declarative Configuration**: Infrastructure defined as code
- **Proxmox Provider**: Automated VM provisioning
- **State Management**: Track infrastructure changes in S3
- **Modular Design**: Reusable components

## Infrastructure Components

- **Talos Cluster**: Multi-node Kubernetes cluster on Talos Linux
- **VM Configuration**: CPU, memory, disk, networking
- **Machine Config**: Automated Talos configuration via templates
- **Networking**: Hybrid DHCP + static IP addressing
- **Remote State**: S3 backend with DynamoDB locking

## Next Steps

- [Infrastructure](infrastructure.md) - Deploy infrastructure
- [Modules](modules.md) - Reusable OpenTofu modules
