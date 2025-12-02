# =============================================================================
# Packer Variables for AlmaLinux 9 + k3s Optimized Image
#
# This file provides environment-specific configuration for building the
# k3s-optimized AlmaLinux 9 golden image.
#
# Sensitive values (proxmox_token, ssh_password) should be set via:
#   - Environment variables: PKR_VAR_proxmox_token
#   - Command line: -var "proxmox_token=..."
#
# =============================================================================

# -----------------------------------------------------------------------------
# Proxmox Connection
# -----------------------------------------------------------------------------

# IMPORTANT: Packer builds must use the internal Proxmox IP address.
# The public proxmox.chriswagner.dev endpoint is protected by Cloudflare Access
# with strict security policies that will block API token authentication.
# Packer builds must originate from inside the network.
proxmox_url      = "https://10.23.45.10:8006/api2/json"
proxmox_username = "packer@pve!packer"
proxmox_node     = "pve"

# Skip TLS verification if using self-signed certificate
proxmox_skip_tls_verify = true

# -----------------------------------------------------------------------------
# AlmaLinux ISO Configuration
# -----------------------------------------------------------------------------

# Using AlmaLinux 9.6 minimal from local Proxmox storage
# Format for local ISO: storage:content-type/filename.iso
alma_iso_url      = "local-120:iso/AlmaLinux-9.6-x86_64-minimal.iso"
alma_iso_checksum = "none"

# -----------------------------------------------------------------------------
# k3s Version
# -----------------------------------------------------------------------------

# k3s version to install
# See: https://github.com/k3s-io/k3s/releases
k3s_version = "v1.31.3+k3s1"

# -----------------------------------------------------------------------------
# Image Naming
# -----------------------------------------------------------------------------

# Semantic version for the image
# Format: alma{version}-k3-node-{arch}-v{k3s-version}-v{distribution-release}
image_version = "alma9-k3-node-amd64-v1.31.3-v1"

# -----------------------------------------------------------------------------
# VM Hardware Configuration
# -----------------------------------------------------------------------------

# VM ID for the builder VM (must be unique)
vm_id = 9000

# CPU cores for build process
vm_cores = 2

# Memory in MB
vm_memory = 4096

# Disk size
vm_disk_size = "32G"

# Storage pool for VM disks and EFI
vm_storage_pool = "local-lvm"

# Network bridge
vm_bridge = "vmbr0"

# -----------------------------------------------------------------------------
# Build Configuration
# -----------------------------------------------------------------------------

# SSH configuration for provisioning
ssh_username = "root"
# ssh_password is set in kickstart (default: "packer")
# Override via: export PKR_VAR_ssh_password="your-password"

# SSH timeout for slow networks
ssh_timeout = "30m"