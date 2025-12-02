# =============================================================================
# cloudflared-lxc Environment - Variables
#
# Variables for deploying a cloudflared LXC container on Proxmox and
# configuring Cloudflare tunnel resources.
#
# =============================================================================

# -----------------------------------------------------------------------------
# Proxmox Provider Configuration
# -----------------------------------------------------------------------------

variable "pm_api_url" {
  type        = string
  description = "Proxmox API URL (e.g., https://10.0.10.2:8006/api2/json)"
}

variable "pm_api_token_id" {
  type        = string
  description = "Proxmox API token ID (e.g., root@pam!terraform)"
}

variable "pm_api_token_secret" {
  type        = string
  description = "Proxmox API token secret"
  sensitive   = true
}

variable "pm_tls_insecure" {
  type        = bool
  description = "Skip TLS certificate verification for Proxmox API"
  default     = true
}

# -----------------------------------------------------------------------------
# Cloudflare Provider Configuration
# -----------------------------------------------------------------------------

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token with permissions for tunnels and DNS"
  sensitive   = true
}

variable "cloudflare_account_id" {
  type        = string
  description = "Cloudflare account ID"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare zone ID for chriswagner.dev"
}

# -----------------------------------------------------------------------------
# Proxmox Infrastructure Configuration
# -----------------------------------------------------------------------------

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name where LXC will be created"
  default     = "pve"
}

variable "storage_pool" {
  type        = string
  description = "Proxmox storage pool for LXC rootfs"
  default     = "local-lvm"
}

variable "network_bridge" {
  type        = string
  description = "Proxmox network bridge for LXC"
  default     = "vmbr0"
}

variable "lxc_template" {
  type        = string
  description = "LXC template to use (e.g., 'local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst')"
  default     = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"
}

# -----------------------------------------------------------------------------
# LXC Configuration
# -----------------------------------------------------------------------------

variable "lxc_hostname" {
  type        = string
  description = "Hostname for the cloudflared LXC container"
  default     = "cloudflared"
}

variable "lxc_vmid" {
  type        = number
  description = "Proxmox VM ID for the LXC (0 = auto-assign)"
  default     = 0
}

variable "lxc_cores" {
  type        = number
  description = "Number of CPU cores for the LXC"
  default     = 1
}

variable "lxc_memory" {
  type        = number
  description = "Memory in MB for the LXC"
  default     = 512
}

variable "lxc_swap" {
  type        = number
  description = "Swap size in MB for the LXC"
  default     = 256
}

variable "lxc_disk_size" {
  type        = string
  description = "Root disk size for the LXC (e.g., 4G)"
  default     = "4G"
}

variable "lxc_password" {
  type        = string
  description = "Root password for the LXC container"
  sensitive   = true
}

variable "lxc_ssh_public_key" {
  type        = string
  description = "SSH public key for LXC root user"
  default     = ""
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "lxc_ip" {
  type        = string
  description = "Static IP address with CIDR for the LXC (e.g., '10.0.10.10/24') or 'dhcp'"
  default     = "dhcp"

  validation {
    condition     = var.lxc_ip == "dhcp" || can(cidrhost(var.lxc_ip, 0))
    error_message = "lxc_ip must be 'dhcp' or a valid IP address in CIDR notation (e.g., '10.0.10.10/24')."
  }
}

variable "lxc_gateway" {
  type        = string
  description = "Network gateway IP address (required if using static IP)"
  default     = ""
}

variable "lxc_nameserver" {
  type        = string
  description = "DNS nameserver for the LXC"
  default     = "1.1.1.1"
}

# -----------------------------------------------------------------------------
# Cloudflare Tunnel Configuration
# -----------------------------------------------------------------------------

variable "tunnel_name" {
  type        = string
  description = "Name for the Cloudflare tunnel"
  default     = "homelab-cloudflared"
}

variable "tunnel_secret" {
  type        = string
  description = "Base64-encoded secret for the Cloudflare tunnel (32+ random bytes)"
  sensitive   = true
}

# -----------------------------------------------------------------------------
# DNS and Ingress Configuration
# -----------------------------------------------------------------------------

variable "domain" {
  type        = string
  description = "Base domain for DNS records"
  default     = "chriswagner.dev"
}

variable "proxmox_internal_ip" {
  type        = string
  description = "Internal IP address of the Proxmox host for tunnel ingress"
  default     = "10.0.10.2"
}

variable "ingress_rules" {
  type = list(object({
    hostname      = string
    service       = string
    no_tls_verify = optional(bool, false)
  }))
  description = "List of ingress rules for the cloudflared tunnel"
  default = [
    {
      hostname      = "proxmox.chriswagner.dev"
      service       = "https://10.0.10.2:8006"
      no_tls_verify = true
    }
  ]
}
