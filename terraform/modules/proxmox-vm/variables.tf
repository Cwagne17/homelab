# =============================================================================
# Proxmox VM Module - Variables
#
# This module provides a reusable configuration for creating Proxmox VMs
# from golden image templates. It handles:
#   - VM cloning from templates
#   - Cloud-init configuration (user, SSH keys, network)
#   - Disk and network configuration
#   - Lifecycle management
#
# Refs: Req 3.2, 3.3, 4.1, 4.2, 4.3, 4.4, 4.5
# =============================================================================

# -----------------------------------------------------------------------------
# VM Identity
# -----------------------------------------------------------------------------

variable "name" {
  type        = string
  description = "VM hostname and Proxmox VM name"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,62}$", var.name))
    error_message = "VM name must be lowercase alphanumeric with hyphens, starting with a letter."
  }
}

variable "vmid" {
  type        = number
  description = "Proxmox VM ID (optional, auto-assigned if 0)"
  default     = 0
}

# -----------------------------------------------------------------------------
# Proxmox Infrastructure
# -----------------------------------------------------------------------------

variable "template" {
  type        = number
  description = "Proxmox template VM ID to clone from (e.g., 100)"
}

variable "node" {
  type        = string
  description = "Proxmox node name where VM will be created"
}

variable "storage" {
  type        = string
  description = "Storage pool for VM disks (e.g., local-lvm, vmdata)"
}

variable "bridge" {
  type        = string
  description = "Network bridge for VM (e.g., vmbr0)"
  default     = "vmbr0"
}

# -----------------------------------------------------------------------------
# VM Resources
# -----------------------------------------------------------------------------

variable "cores" {
  type        = number
  description = "Number of CPU cores"
  default     = 2

  validation {
    condition     = var.cores >= 1 && var.cores <= 128
    error_message = "CPU cores must be between 1 and 128."
  }
}

variable "memory" {
  type        = number
  description = "RAM in MB (e.g., 4096 for 4GB)"
  default     = 4096

  validation {
    condition     = var.memory >= 512 && var.memory <= 1048576
    error_message = "Memory must be between 512 MB and 1 TB."
  }
}

variable "disk_size" {
  type        = string
  description = "Disk size (e.g., 32G, 100G)"
  default     = "32G"

  validation {
    condition     = can(regex("^[0-9]+[GMK]$", var.disk_size))
    error_message = "Disk size must be in format like 32G, 100G, or 500M."
  }
}

# -----------------------------------------------------------------------------
# Cloud-init Configuration
# -----------------------------------------------------------------------------

variable "ci_user" {
  type        = string
  description = "Cloud-init default username"
  default     = "admin"
}

variable "ssh_pubkey" {
  type        = string
  description = "SSH public key for cloud-init user"
  # TODO: Replace with your SSH public key
  default     = ""
}

variable "ip" {
  type        = string
  description = "Static IP address with CIDR notation (e.g., 10.23.45.31/24)"

  validation {
    condition     = can(cidrhost(var.ip, 0))
    error_message = "IP must be in CIDR notation (e.g., 10.23.45.31/24)."
  }
}

variable "gateway" {
  type        = string
  description = "Network gateway IP address"

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.gateway))
    error_message = "Gateway must be a valid IPv4 address."
  }
}

variable "nameserver" {
  type        = string
  description = "DNS nameserver IP address"

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.nameserver))
    error_message = "Nameserver must be a valid IPv4 address."
  }
}

variable "user_data" {
  type        = string
  description = "Optional cloud-init user-data snippet name (stored in Proxmox snippets)"
  default     = ""
}

# -----------------------------------------------------------------------------
# VM Options
# -----------------------------------------------------------------------------

variable "onboot" {
  type        = bool
  description = "Start VM automatically on Proxmox host boot"
  default     = true
}

variable "agent" {
  type        = number
  description = "Enable QEMU guest agent (1 = enabled, 0 = disabled)"
  default     = 1
}

variable "tags" {
  type        = list(string)
  description = "Tags to apply to the VM"
  default     = ["k3s", "homelab"]
}
