terraform {
  required_version = ">= 1.7.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.70.0"
    }
  }
}

provider "proxmox" {
  # Configuration read from environment variables:
  # PROXMOX_VE_ENDPOINT, PROXMOX_VE_USERNAME, PROXMOX_VE_TOKEN, PROXMOX_VE_INSECURE
}

resource "proxmox_virtual_environment_vm" "truenas" {
  name        = var.vm_name
  vm_id       = var.vmid
  node_name   = var.node
  pool_id     = var.pool
  tags        = var.tags
  description = "TrueNAS SCALE storage server"

  bios          = "ovmf"
  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"

  cpu {
    cores   = var.cores
    sockets = var.sockets
    type    = var.cpu_type
  }

  memory {
    dedicated = var.memory_mb
  }

  # Boot order: CD-ROM first for installation, then OS disk, then network
  boot_order = ["ide2", "scsi0", "net0"]

  # EFI disk for UEFI boot with Secure Boot support
  efi_disk {
    datastore_id      = var.system_storage
    file_format       = "raw"
    type              = "4m"
    pre_enrolled_keys = true
  }

  # OS disk - 32GB on vmdata with iothread
  disk {
    datastore_id = var.system_storage
    interface    = "scsi0"
    size         = var.os_disk_gb
    file_format  = "raw"
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  # CD-ROM with TrueNAS SCALE ISO
  cdrom {
    enabled   = true
    file_id   = "${var.iso_storage}:iso/${var.truenas_iso}"
    interface = "ide2"
  }

  # Passthrough disk 1 - WD 6TB drive
  disk {
    interface = "scsi1"
    file_id   = var.passthrough_disk1_by_id
    iothread  = true
    discard   = "on"
    ssd       = false
    cache     = "none"
    aio       = "native"
  }

  # Passthrough disk 2 - WD 6TB drive
  disk {
    interface = "scsi2"
    file_id   = var.passthrough_disk2_by_id
    iothread  = true
    discard   = "on"
    ssd       = false
    cache     = "none"
    aio       = "native"
  }

  # Network interface
  network_device {
    bridge      = var.bridge
    mac_address = var.macaddr
    firewall    = var.firewall
    model       = "virtio"
  }

  lifecycle {
    create_before_destroy = true
    # Ignore changes to cdrom to allow removal/changes after installation
    ignore_changes = [cdrom]
  }
}
