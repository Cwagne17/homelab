locals {
  factory_url = "https://factory.talos.dev"
}

# Get schematic ID from Talos Image Factory
resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = [
          "siderolabs/qemu-guest-agent"
        ]
      }
    }
  })
}

# Download Talos image to Proxmox node (single download since all VMs on same host)
resource "proxmox_virtual_environment_download_file" "this" {
  node_name    = var.proxmox_host_node
  content_type = "iso"
  datastore_id = var.proxmox_iso_datastore

  file_name               = "talos-${talos_image_factory_schematic.this.id}-${var.cluster.talos_version}-nocloud-amd64.iso"
  url                     = "${local.factory_url}/image/${talos_image_factory_schematic.this.id}/${var.cluster.talos_version}/nocloud-amd64.raw.gz"
  decompression_algorithm = "gz"
  overwrite               = false
}
