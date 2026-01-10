# =============================================================================
# TrueNAS SCALE VM Variables
# =============================================================================

# VM Identity
variable "vm_name" {
  description = "Name of the TrueNAS VM"
  type        = string
  default     = "truenas.home.arpa"
}

variable "vmid" {
  description = "Proxmox VM ID"
  type        = number
  default     = 900
}

variable "node" {
  description = "Proxmox node name where the VM will be created"
  type        = string
}

variable "pool" {
  description = "Proxmox resource pool (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to the VM"
  type        = list(string)
  default     = ["truenas", "nfs", "storage"]
}

# Compute Resources
variable "memory_mb" {
  description = "Memory allocation in MB"
  type        = number
  default     = 8192
}

variable "sockets" {
  description = "Number of CPU sockets"
  type        = number
  default     = 1
}

variable "cores" {
  description = "Number of CPU cores per socket"
  type        = number
  default     = 2
}

variable "cpu_type" {
  description = "CPU type (host for best performance)"
  type        = string
  default     = "host"
}

# Storage Configuration
variable "system_storage" {
  description = "Proxmox datastore for system disk and EFI"
  type        = string
  default     = "vmdata"
}

variable "iso_storage" {
  description = "Proxmox datastore containing ISO images"
  type        = string
  default     = "local-120"
}

variable "os_disk_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 32
}

variable "passthrough_disk1_by_id" {
  description = "First passthrough disk path using /dev/disk/by-id (WD 6TB)"
  type        = string
}

variable "passthrough_disk2_by_id" {
  description = "Second passthrough disk path using /dev/disk/by-id (WD 6TB)"
  type        = string
}

# Installation Media
variable "truenas_iso" {
  description = "TrueNAS SCALE ISO filename"
  type        = string
  default     = "TrueNAS-SCALE-25.10.1.iso"
}

# Network Configuration
variable "bridge" {
  description = "Network bridge for VM"
  type        = string
  default     = "vmbr0"
}

variable "macaddr" {
  description = "MAC address for the VM network interface"
  type        = string
  default     = "02:23:45:21:9a:7c"
}

variable "firewall" {
  description = "Enable Proxmox firewall for this interface"
  type        = bool
  default     = true
}
