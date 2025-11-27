# =============================================================================
# k3s-single Environment - Variables
#
# Variables for deploying a single-node k3s cluster.
#
# Refs: Req 3.1, 3.4, 3.5, 7.2, 7.3
# =============================================================================

# -----------------------------------------------------------------------------
# Proxmox Provider Configuration
# -----------------------------------------------------------------------------

variable "pm_api_url" {
  type        = string
  description = "Proxmox API URL (e.g., https://10.23.45.10:8006/api2/json)"
  # TODO: Set via environment variable PM_API_URL
}

variable "pm_api_token_id" {
  type        = string
  description = "Proxmox API token ID (e.g., root@pam!terraform)"
  # TODO: Set via environment variable PM_API_TOKEN_ID
}

variable "pm_api_token_secret" {
  type        = string
  description = "Proxmox API token secret"
  sensitive   = true
  # TODO: Set via environment variable PM_API_TOKEN_SECRET
}

variable "pm_tls_insecure" {
  type        = bool
  description = "Skip TLS certificate verification"
  default     = true
}

# -----------------------------------------------------------------------------
# Infrastructure Configuration
# -----------------------------------------------------------------------------

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name"
  default     = "pve"
}

variable "template_name" {
  type        = string
  description = "Golden image template name (from Packer build)"
  default     = "alma9-k3-node-amd64-v1.28.5-v1"
}

variable "storage_pool" {
  type        = string
  description = "Proxmox storage pool for VM disks"
  default     = "local-lvm"
}

variable "network_bridge" {
  type        = string
  description = "Proxmox network bridge"
  default     = "vmbr0"
}

# -----------------------------------------------------------------------------
# VM Configuration (Req 3.4)
# -----------------------------------------------------------------------------

variable "vm_name" {
  type        = string
  description = "VM hostname"
  default     = "k3s-s1"
}

variable "vm_cores" {
  type        = number
  description = "CPU cores"
  default     = 4
}

variable "vm_memory" {
  type        = number
  description = "RAM in MB (24GB = 24576)"
  default     = 24576
}

variable "vm_disk_size" {
  type        = string
  description = "Disk size"
  default     = "32G"
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "vm_ip" {
  type        = string
  description = "Static IP with CIDR"
  default     = "10.23.45.31/24"
}

variable "vm_gateway" {
  type        = string
  description = "Network gateway"
  default     = "10.23.45.1"
}

variable "vm_nameserver" {
  type        = string
  description = "DNS nameserver"
  default     = "10.23.45.1"
}

# -----------------------------------------------------------------------------
# Cloud-init Configuration
# -----------------------------------------------------------------------------

variable "ci_user" {
  type        = string
  description = "Cloud-init default user"
  default     = "admin"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for cloud-init user"
  # TODO: Replace with your SSH public key
  default     = ""
}
