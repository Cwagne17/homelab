# =============================================================================
# k3s-single Environment - Variables
#
# Variables for deploying a single-node k3s cluster.
#
# Most infrastructure values are hardcoded as they don't change.
# Only environment-specific values are exposed as variables.
#
# Refs: Req 3.1, 3.4, 3.5, 7.2, 7.3
# =============================================================================

# -----------------------------------------------------------------------------
# Proxmox Provider Configuration
# -----------------------------------------------------------------------------

variable "pm_api_token_secret" {
  type        = string
  description = "Proxmox API token secret for opentofu@pve user"
  sensitive   = true
  # Set via environment variable: export TF_VAR_pm_api_token_secret="your-token"
}

# -----------------------------------------------------------------------------
# Infrastructure Configuration
# -----------------------------------------------------------------------------

variable "template_name" {
  type        = number
  description = "Golden image template VM ID (from Packer build)"
  # Use the VM ID number of the template
  # Example: 100 for alma9.6-k3s-stable-202512061712
  default     = 100
}

variable "storage_pool" {
  type        = string
  description = "Proxmox storage pool for VM disks (template is on local-lvm, VM disk will be on this storage)"
  default     = "vmdata"
}

# -----------------------------------------------------------------------------
# VM Configuration (Req 3.4)
# -----------------------------------------------------------------------------

variable "vm_cores" {
  type        = number
  description = "CPU cores for the k3s node"
  default     = 4
}

variable "vm_memory" {
  type        = number
  description = "RAM in MB (24GB = 24576)"
  default     = 24576
}

variable "vm_disk_size" {
  type        = string
  description = "Disk size for the k3s node"
  default     = "32G"
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "vm_ip" {
  type        = string
  description = "Static IP address with CIDR notation (e.g., 10.23.45.31/24)"
  default     = "10.23.45.31/24"
  # Note: Proxmox will error if this IP is already in use by another VM
}
