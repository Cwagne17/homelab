locals {
  factory_url  = "https://factory.talos.dev"
  schematic_id = jsondecode(data.http.schematic_id.response_body)["id"]
}

# Get schematic ID from Talos Image Factory
data "http" "schematic_id" {
  url          = "${local.factory_url}/schematics"
  method       = "POST"
  request_body = var.talos_schematic
}

# Download Talos image to Proxmox node (single download since all VMs on same host)
resource "proxmox_virtual_environment_download_file" "this" {
  node_name    = var.proxmox_host_node
  content_type = "iso"
  datastore_id = var.proxmox_iso_datastore

  file_name               = "talos-${local.schematic_id}-${var.cluster.talos_version}-nocloud-amd64.iso"
  url                     = "${local.factory_url}/image/${local.schematic_id}/${var.cluster.talos_version}/nocloud-amd64.raw.gz"
  decompression_algorithm = "gz"
  overwrite               = false
}
