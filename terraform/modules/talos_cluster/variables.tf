variable "cluster" {
  description = "Cluster configuration"
  type = object({
    name            = string               # Cluster name
    endpoint        = string               # Kubernetes API endpoint (DNS name or IP with port, e.g., "k8s.example.com:6443" or "192.168.1.100:6443")
    talos_version   = string               # Talos version (e.g., "v1.11.5")
    proxmox_cluster = optional(string, "") # Optional Proxmox cluster name for node labels
  })

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.cluster.talos_version))
    error_message = "talos_version must be in the format vX.Y.Z (e.g., v1.11.5)"
  }
}

variable "nodes" {
  description = "Configuration for cluster nodes keyed by hostname"
  type = map(object({
    machine_type = string # "controlplane" or "worker"
    vm_id        = number # Proxmox VM ID
    cpu          = number # Number of CPU cores
    memory       = number # RAM in MB
    disk_size    = number # Disk size in GB
    private_ip   = string # IP address with CIDR (e.g., "192.168.1.100/24")
  }))

  validation {
    condition = alltrue([
      for k, v in var.nodes : contains(["controlplane", "worker"], v.machine_type)
    ])
    error_message = "machine_type must be either 'controlplane' or 'worker'"
  }

  validation {
    condition = alltrue([
      for k, v in var.nodes : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", v.private_ip))
    ])
    error_message = "private_ip must be in CIDR format (e.g., 192.168.1.100/24)"
  }
}

variable "proxmox_host_node" {
  description = "Proxmox node name where VMs will run"
  type        = string
}

variable "proxmox_datastore" {
  description = "Proxmox datastore for VM disks (EFI and main disk)"
  type        = string
  default     = "vmdata"
}

variable "proxmox_iso_datastore" {
  description = "Proxmox datastore for ISO images"
  type        = string
  default     = "local-120"
}

variable "network_gateway" {
  description = "Network gateway for all nodes"
  type        = string
}
