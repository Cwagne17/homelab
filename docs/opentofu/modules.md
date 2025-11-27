# OpenTofu Modules

This page documents the reusable OpenTofu/Terraform modules for provisioning Proxmox VMs.

## Why Modules?

Using modules provides:

- **Reusability**: Same module for different environments
- **Consistency**: All VMs follow the same configuration pattern
- **Maintainability**: Update module once, apply everywhere
- **Testing**: Modules can be validated independently

## proxmox-vm Module

The `proxmox-vm` module creates VMs by cloning golden image templates.

### Location

```
terraform/modules/proxmox-vm/
├── main.tf        # Resource definitions
├── variables.tf   # Input variables
└── outputs.tf     # Output values
```

### Features

| Feature | Description |
|---------|-------------|
| Template Cloning | Creates VMs from Packer-built templates |
| Cloud-init | Configures user, SSH keys, network |
| SCSI Disk | SSD emulation with TRIM support |
| virtio Network | High-performance networking |
| Lifecycle | `create_before_destroy` for updates |

### Usage Example

```hcl
module "k3s_node" {
  source = "../../modules/proxmox-vm"

  # VM Identity
  name     = "k3s-s1"
  template = "alma9-k3-node-amd64-v1.28.5-v1"
  node     = "pve"

  # Resources
  cores     = 4
  memory    = 24576
  disk_size = "32G"
  storage   = "local-lvm"

  # Network
  bridge     = "vmbr0"
  ip         = "10.23.45.31/24"
  gateway    = "10.23.45.1"
  nameserver = "10.23.45.1"

  # Cloud-init
  ci_user    = "admin"
  ssh_pubkey = file("~/.ssh/id_ed25519.pub")
}
```

### Input Variables

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | string | Yes | VM hostname |
| `template` | string | Yes | Template to clone |
| `node` | string | Yes | Proxmox node |
| `storage` | string | Yes | Storage pool |
| `ip` | string | Yes | Static IP with CIDR |
| `gateway` | string | Yes | Network gateway |
| `nameserver` | string | Yes | DNS server |
| `cores` | number | No | CPU cores (default: 2) |
| `memory` | number | No | RAM in MB (default: 4096) |
| `disk_size` | string | No | Disk size (default: 32G) |
| `ci_user` | string | No | Cloud-init user (default: admin) |
| `ssh_pubkey` | string | No | SSH public key |
| `user_data` | string | No | Custom cloud-init snippet |

### Outputs

| Output | Description |
|--------|-------------|
| `vm_id` | Proxmox VM ID |
| `ip_address` | Configured IP address |
| `name` | VM name |
| `ssh_command` | SSH connection command |
| `kubeconfig_command` | Command to fetch kubeconfig |

### Disk Configuration

The module configures SCSI disks with:

- **SSD Emulation**: Enabled for performance
- **Discard/TRIM**: Enabled for storage efficiency
- **IO Thread**: Enabled for parallelism

### Network Configuration

The module creates a virtio network interface:

- High-performance paravirtualized driver
- Attached to specified bridge
- Static IP via cloud-init

### Lifecycle Management

The `create_before_destroy` lifecycle ensures:

1. New VM is created first
2. Old VM is destroyed after new one is ready
3. Minimizes downtime during updates

!!! tip "Template Updates"
    The module ignores changes to the `clone` attribute,
    allowing template updates without forcing VM recreation.

## Next Steps

- [Infrastructure](infrastructure.md) - Deploy VMs
- [Overview](index.md) - Return to OpenTofu overview
