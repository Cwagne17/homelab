# =============================================================================
# Proxmox VM Module - Main Configuration
#
# Creates a Proxmox VM by cloning a template and applying cloud-init
# configuration for network, user, and SSH key setup.
#
# Features:
#   - SCSI disk with SSD emulation and discard enabled
#   - virtio network interface
#   - Cloud-init for automated first-boot configuration
#   - create_before_destroy lifecycle for zero-downtime updates
#
# Refs: Req 3.2, 3.3, 4.1, 4.2, 4.3, 4.4, 4.5
# =============================================================================

terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = ">= 3.0.2-rc06"
    }
  }
}

# -----------------------------------------------------------------------------
# Proxmox VM Resource
# -----------------------------------------------------------------------------

resource "proxmox_vm_qemu" "vm" {
  # VM Identity
  name        = var.name
  target_node = var.node
  vmid        = var.vmid > 0 ? var.vmid : null

  # Clone from template
  clone_id   = var.template
  full_clone = true

  # VM Options
  onboot = var.onboot
  agent  = var.agent
  tags   = join(",", var.tags)

  # CPU Configuration
  cpu {
    cores   = var.cores
    sockets = 1
    type    = "host"
  }

  # Memory Configuration
  memory = var.memory

  # Boot Configuration
  boot = "order=scsi0"

  # Storage Configuration (Req 4.2)
  # SCSI disk with SSD emulation and discard enabled
  scsihw = "virtio-scsi-single"

  disk {
    slot     = "scsi0"
    type     = "disk"
    storage  = var.storage
    size     = var.disk_size
    discard  = true
    iothread = true
  }

  # Network Configuration (Req 4.3)
  # virtio network interface on specified bridge
  network {
    id     = 0
    model  = "virtio"
    bridge = var.bridge
  }

  # Cloud-init Configuration (Req 3.2, 4.4)
  os_type   = "cloud-init"
  ciuser    = var.ci_user
  sshkeys   = var.ssh_pubkey
  ipconfig0 = "ip=${var.ip},gw=${var.gateway}"
  nameserver = var.nameserver

  # Optional custom user-data snippet
  cicustom = var.user_data != "" ? "user=local:snippets/${var.user_data}" : null

  # Lifecycle Configuration (Req 3.3)
  # create_before_destroy minimizes downtime during updates
  lifecycle {
    create_before_destroy = true

    # Ignore changes to clone source (template may be updated independently)
    ignore_changes = [
      clone,
    ]
  }

  # Wait for cloud-init to complete
  # This helps ensure the VM is fully initialized before Terraform considers it ready
  timeouts {
    create = "10m"
    update = "10m"
    delete = "5m"
  }
}
