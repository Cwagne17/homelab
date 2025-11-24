---
icon: material/home-automation
---

# Welcome to Homelab

A production-grade infrastructure automation project demonstrating modern DevOps practices and cloud-native technologies.

## What is This?

This homelab showcases end-to-end infrastructure automation—from building VM images to deploying Kubernetes applications—all orchestrated through code.

```mermaid
graph LR
    Packer[Packer] -->|Golden Images| Proxmox[Proxmox VE]
    Proxmox -->|VMs| K3s[K3s Cluster]
    K3s -->|GitOps| Apps[Applications]

    style Packer fill:#E9A819,stroke:#6E5B28,stroke-width:2px,color:#071324
    style Proxmox fill:#021C3C,stroke:#E9A819,stroke-width:2px,color:#E9A819
    style K3s fill:#E9A819,stroke:#6E5B28,stroke-width:2px,color:#071324
    style Apps fill:#021C3C,stroke:#E9A819,stroke-width:2px,color:#E9A819
```

## The Stack

!!! tip "Infrastructure as Code"
**Proxmox VE** hosts everything. **Packer** builds golden images. **OpenTofu** provisions VMs. **K3s** runs containers. **Argo CD** deploys apps.

## Quick Start

Deploy the entire stack with a single command:

```bash
atmos workflow deploy-homelab -f stacks/workflows/deploy.yaml
```

## Explore the Stack

### :material-server: [Proxmox](proxmox/index.md)

Open-source virtualization platform hosting all infrastructure

### :material-package-variant: [Packer](packer/index.md)

Automated image building with k3s pre-installed

### :material-terraform: [OpenTofu](opentofu/index.md)

Infrastructure-as-code for declarative VM provisioning

### :material-kubernetes: [K3s](k3s/index.md)

Lightweight Kubernetes with GitOps workflows

---

**Built with** ❤️ **and a lot of YAML**
