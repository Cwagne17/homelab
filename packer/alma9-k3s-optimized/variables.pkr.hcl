# =============================================================================
# Packer Variables for AlmaLinux 9 + k3s Optimized Image
#
# This file defines all configurable parameters for building the k3s-optimized
# AlmaLinux 9 golden image. Variables can be set via:
#   - Command line: -var "variable_name=value"
#   - Variable file: -var-file="variables.pkrvars.hcl"
#   - Environment variables: PKR_VAR_variable_name
#
# Refs: Req 1.5, 7.2, 7.3
# =============================================================================

# -----------------------------------------------------------------------------
# Image Version and Naming
# -----------------------------------------------------------------------------

variable "image_version" {
  type        = string
  description = "Semantic version for the image. Format: alma{version}-k3-node-{arch}-{k3s-version}-v{distribution-release}"
  default     = "alma9-k3-node-amd64-v1.28.5-v1"

  validation {
    condition     = can(regex("^alma[0-9]+-k3-node-(amd64|arm64)-v[0-9]+\\.[0-9]+\\.[0-9]+-v[0-9]+$", var.image_version))
    error_message = "Image version must match format: alma{version}-k3-node-{arch}-{k3s-version}-v{distribution-release}"
  }
}

# -----------------------------------------------------------------------------
# Proxmox Connection Configuration
# -----------------------------------------------------------------------------

variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL (e.g., https://10.23.45.10:8006/api2/json)"
  # TODO: Set this to your Proxmox API URL
  default = "https://proxmox.example.com:8006/api2/json"
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox API username (e.g., root@pam or packer@pve!packer-token)"
  # TODO: Set this to your Proxmox username
  default = "root@pam"
}

variable "proxmox_token" {
  type        = string
  description = "Proxmox API token for authentication"
  sensitive   = true
  # TODO: Set via environment variable PKR_VAR_proxmox_token or command line
  default = ""
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name where the image will be built"
  # TODO: Set this to your Proxmox node name
  default = "pve"
}

variable "proxmox_skip_tls_verify" {
  type        = bool
  description = "Skip TLS certificate verification for Proxmox API"
  default     = true
}

# -----------------------------------------------------------------------------
# AlmaLinux ISO Configuration
# -----------------------------------------------------------------------------

variable "alma_iso_url" {
  type        = string
  description = "URL or local path to AlmaLinux 9 Minimal ISO"
  # TODO: Update with the correct ISO URL for your environment
  # Options:
  #   - Local: /var/lib/vz/template/iso/AlmaLinux-9.3-x86_64-minimal.iso
  #   - Remote: https://mirror.example.com/almalinux/9/isos/x86_64/AlmaLinux-9.3-x86_64-minimal.iso
  default = "https://repo.almalinux.org/almalinux/9/isos/x86_64/AlmaLinux-9.3-x86_64-minimal.iso"
}

variable "alma_iso_checksum" {
  type        = string
  description = "SHA256 checksum for AlmaLinux ISO verification"
  # TODO: Update checksum when changing ISO version
  default = "sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
}

variable "alma_iso_storage_pool" {
  type        = string
  description = "Proxmox storage pool for ISO files"
  default     = "local"
}

# -----------------------------------------------------------------------------
# k3s Configuration
# -----------------------------------------------------------------------------

variable "k3s_version" {
  type        = string
  description = "k3s version to install (e.g., v1.28.5+k3s1)"
  default     = "v1.28.5+k3s1"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+\\+k3s[0-9]+$", var.k3s_version))
    error_message = "k3s version must match format: v{major}.{minor}.{patch}+k3s{release}"
  }
}

# -----------------------------------------------------------------------------
# VM Hardware Configuration
# -----------------------------------------------------------------------------

variable "vm_id" {
  type        = number
  description = "Proxmox VM ID for the builder VM"
  default     = 9000
}

variable "vm_cores" {
  type        = number
  description = "Number of CPU cores for builder VM"
  default     = 2
}

variable "vm_memory" {
  type        = number
  description = "Memory in MB for builder VM"
  default     = 4096
}

variable "vm_disk_size" {
  type        = string
  description = "Disk size for builder VM"
  default     = "32G"
}

variable "vm_storage_pool" {
  type        = string
  description = "Proxmox storage pool for VM disks"
  default     = "local-lvm"
}

variable "vm_bridge" {
  type        = string
  description = "Network bridge for VM"
  default     = "vmbr0"
}

# -----------------------------------------------------------------------------
# Build Configuration
# -----------------------------------------------------------------------------

variable "ssh_username" {
  type        = string
  description = "SSH username for provisioning"
  default     = "root"
}

variable "ssh_password" {
  type        = string
  description = "SSH password for provisioning (set in kickstart)"
  sensitive   = true
  # TODO: Set via environment variable or use a more secure method
  default = "packer"
}

variable "ssh_timeout" {
  type        = string
  description = "Timeout for SSH connection"
  default     = "30m"
}

variable "http_bind_address" {
  type        = string
  description = "IP address to bind HTTP server for kickstart delivery"
  default     = "0.0.0.0"
}

variable "http_port_min" {
  type        = number
  description = "Minimum port for HTTP server"
  default     = 8100
}

variable "http_port_max" {
  type        = number
  description = "Maximum port for HTTP server"
  default     = 8200
}
