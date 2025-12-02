# =============================================================================
# Packer Builder Configuration for AlmaLinux 9 + k3s Optimized Image
#
# This configuration uses the Proxmox ISO builder to create a k3s-optimized
# AlmaLinux 9 golden image directly on Proxmox VE.
#
# Build Process:
#   1. Connect to Proxmox API
#   2. Create temporary VM with AlmaLinux 9 ISO
#   3. Boot with UEFI firmware and serve kickstart via HTTP
#   4. Run automated installation
#   5. Execute provisioning scripts (OS updates, guest agent, k3s)
#   6. Convert VM to template
#
# Refs: Req 1.1, 1.2, 1.4, 1.5, 9.1, 9.2, 9.3, 9.4, 9.5
# =============================================================================

packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# -----------------------------------------------------------------------------
# Proxmox ISO Builder
# -----------------------------------------------------------------------------

source "proxmox-iso" "alma9-k3s" {
  # Proxmox connection
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  node                     = var.proxmox_node
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  # VM Configuration
  vm_id   = var.vm_id
  vm_name = var.image_version

  # ISO Configuration using boot_iso block (new syntax)
  boot_iso {
    type         = "scsi"
    iso_file     = var.alma_iso_url
    unmount      = true
    iso_checksum = var.alma_iso_checksum
  }

  # UEFI and Machine Type (Req 1.1, 9.2)
  bios    = "ovmf"
  machine = "q35"

  # EFI disk configuration for UEFI boot
  efi_config {
    efi_storage_pool  = var.vm_storage_pool
    efi_type          = "4m"
    pre_enrolled_keys = false
  }

  # QEMU Guest Agent (Req 9.2)
  qemu_agent = true

  # CPU and Memory
  cores    = var.vm_cores
  sockets  = 1
  memory   = var.vm_memory
  cpu_type = "host"

  # Storage Configuration
  scsi_controller = "virtio-scsi-single"

  disks {
    type         = "scsi"
    disk_size    = var.vm_disk_size
    storage_pool = var.vm_storage_pool
    format       = "raw"
    io_thread    = true
    ssd          = true
    discard      = true
  }

  # Network Configuration
  network_adapters {
    model    = "virtio"
    bridge   = var.vm_bridge
    firewall = false
  }

  # Cloud-init drive for future VM initialization
  cloud_init              = true
  cloud_init_storage_pool = var.vm_storage_pool

  # Boot configuration for kickstart (Req 9.5)
  boot      = "order=scsi0;ide2"
  boot_wait = "5s"

  boot_command = [
    "<up><wait>",
    "e<wait>",
    "<down><down><end><wait>",
    "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
    "inst.text inst.stage2=cdrom inst.ks=https://raw.githubusercontent.com/Cwagne17/homelab/refs/heads/main/packer/alma9-k3s-optimized/http/ks.cfg<wait>",
    "<leftCtrlOn>x<leftCtrlOff>"
  ]

  # HTTP server disabled - using GitHub raw URL instead
  # http_directory    = "${path.root}/http"
  # http_bind_address = var.http_bind_address
  # http_port_min     = var.http_port_min
  # http_port_max     = var.http_port_max

  # SSH connection for provisioning
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = var.ssh_timeout

  # Template conversion (Req 9.3)
  template_name        = var.image_version
  template_description = "AlmaLinux 9 with k3s ${var.k3s_version} pre-installed. Built by Packer on ${timestamp()}"
}

# -----------------------------------------------------------------------------
# Build Definition
# -----------------------------------------------------------------------------

build {
  name    = "alma9-k3s-optimized"
  sources = ["source.proxmox-iso.alma9-k3s"]

  # Provisioning scripts disabled for initial testing
  # Will add back one by one once basic build works

  # # 1. System updates and base configuration
  # provisioner "shell" {
  #   script          = "${path.root}/scripts/os-update.sh"
  #   execute_command = "chmod +x {{ .Path }}; sudo {{ .Path }}"
  # }

  # # 2. QEMU guest agent installation
  # provisioner "shell" {
  #   script          = "${path.root}/scripts/guest-agent.sh"
  #   execute_command = "chmod +x {{ .Path }}; sudo {{ .Path }}"
  # }

  # # 3. k3s server installation
  # provisioner "shell" {
  #   script = "${path.root}/scripts/k3s-install.sh"
  #   environment_vars = [
  #     "K3S_VERSION=${var.k3s_version}"
  #   ]
  #   execute_command = "chmod +x {{ .Path }}; sudo {{ .Path }}"
  # }

  # # 4. Security hardening (stub)
  # provisioner "shell" {
  #   script          = "${path.root}/scripts/hardening-oscap.sh"
  #   execute_command = "chmod +x {{ .Path }}; sudo {{ .Path }}"
  # }

  # # 5. Cleanup for template
  # provisioner "shell" {
  #   inline = [
  #     "# Clean up temporary files",
  #     "rm -rf /tmp/*",
  #     "rm -rf /var/tmp/*",
  #     "rm -f /etc/machine-id",
  #     "truncate -s 0 /etc/machine-id",
  #     "rm -f /var/log/*.log",
  #     "rm -f /var/log/**/*.log",
  #     "# Cloud-init cleanup for cloning",
  #     "cloud-init clean --logs",
  #     "# Zero out free space for compression",
  #     "sync",
  #     "# Ensure cloud-init runs on next boot",
  #     "rm -rf /var/lib/cloud/instances/*"
  #   ]
  #   execute_command = "chmod +x {{ .Path }}; sudo {{ .Path }}"
  # }

  # Output template name for reference (Req 9.4)
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
    custom_data = {
      template_name = var.image_version
      k3s_version   = var.k3s_version
      build_time    = timestamp()
    }
  }
}
