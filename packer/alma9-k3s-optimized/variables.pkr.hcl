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

variable "k3s_version" {
  type        = string
  description = "k3s version to install (e.g., v1.31.3+k3s1)"
  default     = "v1.31.3+k3s1"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+\\+k3s[0-9]+$", var.k3s_version))
    error_message = "K3s version must match format: v{major}.{minor}.{patch}+k3s{release}."
  }
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
