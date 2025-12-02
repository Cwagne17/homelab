locals {
  template_name = "alma${var.alma_version}-k3s-${replace(var.k3s_version, "+", "-")}-${formatdate("YYYYMMDDhhmm", timestamp())}"
}

packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "alma9-k3s" {
  # Proxmox connectivity - Must use internal IP (10.23.45.10) instead of
  # proxmox.chriswagner.dev because Cloudflare Access blocks API token auth.
  # insecure_skip_tls_verify=true needed for self-signed certificates.
  proxmox_url              = "https://10.23.45.10:8006/api2/json"
  username                 = "packer@pve!packer"
  token                    = var.proxmox_token
  node                     = "pve"
  insecure_skip_tls_verify = true

  # VM ID is omitted - Proxmox will auto-assign next available ID
  vm_name = local.template_name

  boot_iso {
    type         = "scsi"
    iso_file     = var.alma_iso_storage
    unmount      = true
    iso_checksum = "none"
  }

  bios    = "ovmf"
  machine = "q35"

  efi_config {
    efi_storage_pool  = var.vm_storage_pool
    efi_type          = "4m"
    pre_enrolled_keys = false
  }

  # QEMU guest agent - disabled during build since agent isn't installed yet.
  # Terraform should set agent=1 when cloning this template.
  qemu_agent = false

  cores    = 2
  sockets  = 1
  memory   = 4096
  cpu_type = "host"

  scsi_controller = "virtio-scsi-single"

  disks {
    type         = "scsi"
    disk_size    = "32G"
    storage_pool = var.vm_storage_pool
    format       = "raw"
    io_thread    = true
    ssd          = true
    discard      = true
  }

  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = false
  }

  # Cloud-init drive for VM customization after cloning
  cloud_init              = true
  cloud_init_storage_pool = var.vm_storage_pool

  boot      = "order=scsi0;ide2"
  boot_wait = "5s"

  boot_command = [
    "<up><wait>",
    "e<wait>",
    "<down><down><end><wait>",
    "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
    "inst.text inst.stage2=cdrom inst.ks=https://raw.githubusercontent.com/Cwagne17/homelab/refs/heads/main/packer/alma9-k3s-optimized/http/ks.cfg?t=${timestamp()}<wait>",
    "<leftCtrlOn>x<leftCtrlOff>"
  ]

  ssh_username = "root"
  ssh_password = "packer"
  ssh_timeout  = "30m"
  # Static IP - must match network --ip in ks.cfg
  ssh_host     = "10.23.45.200"

  template_name        = local.template_name
  template_description = "AlmaLinux ${var.alma_version} + k3s ${var.k3s_version}"

  tags = "packer;template;alma${replace(var.alma_version, ".", "_")};k3s_${replace(replace(var.k3s_version, ".", "_"), "+", "_")}"
}

build {
  sources = ["source.proxmox-iso.alma9-k3s"]

  # Install QEMU guest agent for better Proxmox integration
  provisioner "shell" {
    script = "${path.root}/scripts/guest-agent.sh"
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
    custom_data = {
      template_name = local.template_name
      alma_version  = var.alma_version
      k3s_version   = var.k3s_version
      build_time    = timestamp()
    }
  }
}
