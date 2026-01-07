resource "proxmox_virtual_environment_vm" "this" {
  for_each = var.nodes

  node_name = var.proxmox_host_node

  name        = each.key
  description = each.value.machine_type == "controlplane" ? "Talos Control Plane Node" : "Talos Worker Node"
  tags        = concat(["talos", "kubernetes"], each.value.machine_type == "controlplane" ? ["control-plane"] : ["worker"])
  on_boot     = true
  vm_id       = each.value.vm_id

  # Lifecycle safeguards to prevent accidental VM replacement during Talos upgrades
  lifecycle {
    # prevent_destroy = true  # Temporarily disabled to fix worker node

    # Ignore changes to disk image reference - Talos upgrades should happen via talosctl,
    # not by changing the base image in Terraform
    ignore_changes = [
      disk[0].file_id,
    ]
  }

  # Talos best practices for Proxmox
  machine       = "q35"             # Modern PCIe-based machine type
  scsi_hardware = "virtio-scsi-pci" # NOT virtio-scsi-single (causes bootstrap issues)
  bios          = "ovmf"            # UEFI firmware

  # Enable QEMU guest agent (Talos image includes qemu-guest-agent extension)
  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cpu
    type  = "host" # Best performance, enables advanced instruction sets
  }

  memory {
    dedicated = each.value.memory
  }

  network_device {
    bridge      = "vmbr0"
    model       = "virtio"
    mac_address = each.value.mac_address
  }

  # EFI disk (required for UEFI/OVMF)
  efi_disk {
    datastore_id = var.proxmox_datastore
    file_format  = "raw"
    type         = "4m"
  }

  # Main disk
  disk {
    datastore_id = var.proxmox_datastore
    interface    = "scsi0"
    iothread     = true
    cache        = "writethrough" # Safe default for write cache
    discard      = "on"
    ssd          = true
    file_format  = "raw" # Best performance
    size         = each.value.disk_size
    file_id      = proxmox_virtual_environment_download_file.this.id
  }

  boot_order = ["scsi0"]

  operating_system {
    type = "l26" # Linux Kernel 2.6 - 6.X
  }

  # Enable serial console for troubleshooting
  serial_device {}
}
