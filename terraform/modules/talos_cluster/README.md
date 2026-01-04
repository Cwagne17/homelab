# Talos Cluster Module

A clean, minimal Terraform/OpenTofu module for deploying Talos Linux Kubernetes clusters on Proxmox VE.

## Features

- ✅ Talos best practices for Proxmox (q35, UEFI, VirtIO SCSI)
- ✅ Static IP configuration via Talos machine config (no cloud-init)
- ✅ QEMU guest agent support
- ✅ Scalable design (1+ control planes, 0+ workers)
- ✅ Uses only Proxmox and Talos providers (no Kubernetes provider dependency)
- ✅ Outputs kubeconfig and talosconfig for cluster management

## Requirements

- Proxmox VE 8.0+ or 9.0+
- Terraform/OpenTofu 1.7+
- Network access to Proxmox API

## Usage

```hcl
module "talos_cluster" {
  source = "../../modules/talos_cluster"

  cluster = {
    name          = "my-cluster"
    endpoint      = "k8s.example.com:6443"  # DNS name or IP
    talos_version = "v1.11.5"

    network = {
      gateway = "192.168.1.1"
      dns     = ["1.1.1.1", "8.8.8.8"]
      domain  = "local"
    }
  }

  nodes = {
    "ctrl-00" = {
      host_node    = "pve"
      machine_type = "controlplane"
      vm_id        = 800
      cpu          = 4
      ram_mb       = 4096
      disk_gb      = 20
      ip_cidr      = "192.168.1.100/24"
      mac_address  = "BC:24:11:2E:C8:00"
    }

    "work-00" = {
      host_node    = "pve"
      machine_type = "worker"
      vm_id        = 810
      cpu          = 4
      ram_mb       = 8192
      disk_gb      = 50
      ip_cidr      = "192.168.1.110/24"
      mac_address  = "BC:24:11:2E:A8:00"
    }
  }
}
```

## Inputs

| Name                    | Description                                                                   | Type          | Required              |
| ----------------------- | ----------------------------------------------------------------------------- | ------------- | --------------------- |
| `cluster`               | Cluster configuration including name, endpoint, version, and network settings | `object`      | yes                   |
| `nodes`                 | Map of node configurations keyed by hostname                                  | `map(object)` | yes                   |
| `talos_schematic`       | Talos Image Factory schematic YAML (defaults to qemu-guest-agent only)        | `string`      | no                    |
| `proxmox_iso_datastore` | Proxmox datastore for ISO images                                              | `string`      | no (default: "local") |

### Cluster Object

- `name`: Cluster name
- `endpoint`: Kubernetes API endpoint (DNS name or IP with port)
- `talos_version`: Talos version (e.g., "v1.11.5")
- `proxmox_cluster`: Optional Proxmox cluster name for node labels
- `network.gateway`: Network gateway IP
- `network.dns`: List of DNS server IPs
- `network.domain`: Optional DNS domain

### Node Object

- `host_node`: Proxmox node name where VM runs
- `machine_type`: "controlplane" or "worker"
- `vm_id`: Proxmox VM ID
- `cpu`: Number of CPU cores
- `ram_mb`: RAM in MB
- `disk_gb`: Disk size in GB
- `datastore_id`: Proxmox datastore (default: "local-zfs")
- `ip_cidr`: IP with CIDR notation (e.g., "192.168.1.100/24")
- `mac_address`: MAC address

## Outputs

| Name                  | Description                                  |
| --------------------- | -------------------------------------------- |
| `talosconfig`         | Talos client configuration (sensitive)       |
| `kubeconfig`          | Kubernetes cluster configuration (sensitive) |
| `cluster_name`        | Cluster name                                 |
| `cluster_endpoint`    | Kubernetes API endpoint                      |
| `control_plane_nodes` | Map of control plane IPs                     |
| `worker_nodes`        | Map of worker IPs                            |

## VM Configuration

VMs are created with Talos-optimized settings:

- **Machine Type**: q35 (modern PCIe)
- **BIOS**: OVMF (UEFI)
- **SCSI Controller**: virtio-scsi-pci (NOT virtio-scsi-single)
- **Network**: VirtIO for best performance
- **EFI Disk**: 4MB for UEFI firmware
- **Guest Agent**: Enabled (via qemu-guest-agent extension)
- **Serial Console**: Enabled for troubleshooting

## Upgrades

Cluster upgrades are performed using `talosctl upgrade`, not by recreating VMs:

```bash
# Upgrade Talos
talosctl upgrade --nodes <node-ip> \
  --image factory.talos.dev/installer/<schematic-id>:v1.12.0

# Upgrade Kubernetes
talosctl upgrade-k8s --nodes <node-ip> --to 1.32.0
```

## Notes

- Static IPs are configured via Talos machine config, not Proxmox cloud-init
- Service networking (CNI, ingress, LoadBalancer) should be managed via ArgoCD or Helm
- Storage/CSI should be managed separately (not included in this module)
- Memory ballooning is disabled (Talos doesn't support memory hotplug)

## License

MIT
