---
icon: material/package-variant
---

# Packer Image Building

HashiCorp Packer automates the creation of machine images for multiple platforms from a single source configuration.

## Overview

Packer builds golden images for the homelab:

- **AlmaLinux 9 Base**: RHEL-compatible Linux distribution
- **k3s Pre-installed**: Kubernetes ready on first boot
- **Automated Builds**: Reproducible image creation
- **Version Control**: Semantic versioning for images

## Why Packer?

Building images with Packer provides:

- **Reproducibility**: Same configuration = same image every time
- **Version Control**: Image definitions stored in Git
- **Automation**: No manual VM installation steps
- **Multi-Platform**: Same process works across hypervisors

## Image Pipeline

```mermaid
graph LR
    Config[Packer Config] --> Build[Build Process]
    Build --> Provision[Provision Scripts]
    Provision --> Upload[Upload to Proxmox]
    Upload --> Template[VM Template]

    style Build fill:#02A8EF,stroke:#01579b,stroke-width:2px
```

## Built Images

- **alma9-k3s-node-amd64**: AlmaLinux 9 with k3s server
- UEFI boot support
- QEMU guest agent pre-installed
- Cloud-init enabled

## Kickstart Automation

The image uses a **kickstart file** (`ks.cfg`) for unattended installation:

| Configuration | Setting |
|--------------|---------|
| Partitioning | GPT/LVM with XFS |
| Boot Mode | UEFI with EFI partition |
| Network | DHCP (static via cloud-init later) |
| SELinux | Enforcing |
| Timezone | UTC |
| Packages | Minimal + cloud-init + essential tools |

### Customizing the Kickstart

Edit `packer/alma9-k3s-optimized/http/ks.cfg` to:

- Change package selection in `%packages` section
- Modify partitioning layout
- Add custom post-install scripts in `%post` section

!!! tip "Root Password"
    The kickstart sets a temporary root password for Packer provisioning.
    This password is only used during build and VMs boot with cloud-init SSH keys.

## Next Steps

- [Image Building](building.md) - Build your first image
- [Templates](templates.md) - Customize Packer templates
