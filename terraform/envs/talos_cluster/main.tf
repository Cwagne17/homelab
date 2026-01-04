module "talos_cluster" {
  source = "../../modules/talos_cluster"

  # Datacenter-specific settings
  proxmox_host_node     = "pve"
  proxmox_datastore     = "vmdata"    # For UEFI and VM disks
  proxmox_iso_datastore = "local-120" # For ISO images
  network_gateway       = "10.23.45.1"

  cluster = {
    name            = "homelab-k8s"
    endpoint        = "10.23.45.30:6443" # Control plane IP or DNS name with port
    talos_version   = "v1.11.5"
    proxmox_cluster = "homelab"
  }

  nodes = {
    "k8s-cp00.home.arpa" = {
      machine_type = "controlplane"
      vm_id        = 800
      cpu          = 2
      memory       = 4096
      disk_size    = 20
      private_ip   = "10.23.45.30/24"
    }

    "k8s-wk00.home.arpa" = {
      machine_type = "worker"
      vm_id        = 810
      cpu          = 4
      memory       = 8192
      disk_size    = 50
      private_ip   = "10.23.45.31/24"
    }
  }
}
