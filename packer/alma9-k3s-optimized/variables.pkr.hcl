variable "alma_version" {
  type        = string
  description = "AlmaLinux version (e.g., 9.6)"
  default     = "9.6"
}

variable "alma_iso_storage" {
  type        = string
  description = "Proxmox storage location for AlmaLinux ISO (format: storage:iso/filename.iso)"
  default     = "local-120:iso/AlmaLinux-9.6-x86_64-minimal.iso"
}

variable "vm_storage_pool" {
  type        = string
  description = "Proxmox storage pool for VM disks"
  default     = "local-lvm"
}

variable "proxmox_token" {
  type        = string
  description = "Proxmox API token (set via PKR_VAR_proxmox_token)"
  sensitive   = true
  default     = ""
}
