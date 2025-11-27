# Packer Templates

This page documents the Packer template structure and configuration variables for building k3s-optimized AlmaLinux 9 images.

## Why This Approach?

We use Packer to create **golden images** with k3s pre-installed because:

- **Fast Boot Times**: VMs come up with Kubernetes already running
- **Consistency**: Every deployment uses the exact same base image
- **Version Pinning**: Specific k3s versions are baked into the image
- **Reduced Provisioning**: No need to install k3s at VM creation time

## Template Structure

```
packer/alma9-k3s-optimized/
├── packer.pkr.hcl           # Main builder configuration
├── variables.pkr.hcl        # Variable definitions
├── http/
│   └── ks.cfg               # Kickstart for automated install
└── scripts/
    ├── os-update.sh         # System updates and base config
    ├── guest-agent.sh       # QEMU guest agent installation
    ├── k3s-install.sh       # k3s server installation
    └── hardening-oscap.sh   # Security hardening (stub)
```

## Configuration Variables

### Setting Variables

Variables can be passed to Packer in multiple ways:

```bash
# Command line
packer build -var "proxmox_url=https://10.23.45.10:8006/api2/json" .

# Variable file
packer build -var-file="variables.auto.pkrvars.hcl" .

# Environment variables
export PKR_VAR_proxmox_token="your-api-token"
packer build .
```

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `proxmox_url` | Proxmox API endpoint | `https://10.23.45.10:8006/api2/json` |
| `proxmox_username` | API username | `root@pam` or `packer@pve!token` |
| `proxmox_token` | API token (sensitive) | Set via `PKR_VAR_proxmox_token` |
| `proxmox_node` | Target Proxmox node | `pve` |
| `alma_iso_url` | AlmaLinux ISO path | `local:iso/AlmaLinux-9.3-x86_64-minimal.iso` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `image_version` | Template name | `alma9-k3-node-amd64-v1.28.5-v1` |
| `k3s_version` | k3s version to install | `v1.28.5+k3s1` |
| `vm_cores` | CPU cores for build VM | `2` |
| `vm_memory` | RAM in MB | `4096` |
| `vm_disk_size` | Disk size | `32G` |

### Image Naming Convention

The `image_version` follows a structured format:

```
alma{version}-k3-node-{arch}-{k3s-version}-v{distribution-release}
```

Example: `alma9-k3-node-amd64-v1.28.5-v1`

Components:
- **alma9**: AlmaLinux major version
- **k3-node**: Indicates k3s pre-installed
- **amd64**: CPU architecture
- **v1.28.5**: k3s version (without +k3s suffix)
- **v1**: Image iteration/release

## Example Variable File

Create a file `variables.auto.pkrvars.hcl`:

```hcl
# Proxmox connection
proxmox_url      = "https://10.23.45.10:8006/api2/json"
proxmox_username = "packer@pve!packer-token"
proxmox_node     = "pve"

# ISO configuration
alma_iso_url     = "local:iso/AlmaLinux-9.3-x86_64-minimal.iso"
alma_iso_checksum = "sha256:abc123..."

# k3s version
k3s_version      = "v1.29.0+k3s1"
image_version    = "alma9-k3-node-amd64-v1.29.0-v1"

# Build configuration
vm_id           = 9000
vm_storage_pool = "local-lvm"
```

!!! warning "Secrets Management"
    Never commit sensitive values like `proxmox_token` or `ssh_password` to Git.
    Use environment variables or a secrets manager.

## Next Steps

- [Image Building](building.md) - Run your first build
- [Overview](index.md) - Return to Packer overview
