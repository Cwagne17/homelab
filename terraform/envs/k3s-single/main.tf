# =============================================================================
# k3s-single Environment - Main Configuration
#
# Deploys a single-node k3s cluster on Proxmox using the proxmox-vm module.
# Uses the alma9-k3s-stable golden image which includes:
#   - k3s (stable channel) with secrets encryption
#   - ArgoCD (auto-deployed via k3s HelmChart)
#   - QEMU Guest Agent
#
# Specs:
#   - 4 CPU cores
#   - 24GB RAM
#   - 32GB disk
#   - Static IP: 10.23.45.31/24
#
# Refs: Req 3.1, 3.4, 3.5
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc06"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # TODO: Configure remote backend for state management
  # backend "s3" {
  #   bucket         = "homelab-terraform-state"
  #   key            = "k3s-single/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-lock"
  # }
}

# -----------------------------------------------------------------------------
# Local Values (Hardcoded Infrastructure)
# -----------------------------------------------------------------------------

locals {
  # Infrastructure constants (don't change)
  proxmox_api_url    = "https://10.23.45.10:8006/api2/json"
  proxmox_token_id   = "terraform@pve!terraform"
  proxmox_node       = "pve"
  network_bridge     = "vmbr0"
  
  # Network constants
  gateway            = "10.23.45.1"
  nameserver         = "10.23.45.1"  # Pi-hole DNS server
  
  # Cloud-init user
  ci_user            = "admin"
  
  # Generate unique VM name with random suffix
  vm_name            = "prod-alma9-k3s-${random_id.vm_suffix.hex}"
}

# Generate random hex suffix for VM name
resource "random_id" "vm_suffix" {
  byte_length = 4
}

# -----------------------------------------------------------------------------
# SSH Key Generation
# -----------------------------------------------------------------------------

# Generate SSH key pair for the VM
resource "tls_private_key" "vm_ssh" {
  algorithm = "ED25519"
}

# Save private key to ~/.ssh/
resource "local_file" "private_key" {
  content         = tls_private_key.vm_ssh.private_key_openssh
  filename        = pathexpand("~/.ssh/${local.vm_name}")
  file_permission = "0600"
}

# Save public key to ~/.ssh/
resource "local_file" "public_key" {
  content         = tls_private_key.vm_ssh.public_key_openssh
  filename        = pathexpand("~/.ssh/${local.vm_name}.pub")
  file_permission = "0644"
}

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------

provider "proxmox" {
  pm_api_url          = local.proxmox_api_url
  pm_api_token_id     = local.proxmox_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
  
  # Debug logging
  pm_log_enable = true
  pm_log_file   = "terraform-plugin-proxmox.log"
  pm_log_levels = {
    _default    = "debug"
    _capturelog = ""
  }
}

# -----------------------------------------------------------------------------
# k3s Single Node
# -----------------------------------------------------------------------------

module "k3s_node" {
  source = "../../modules/proxmox-vm"

  # VM Identity
  name     = local.vm_name
  template = var.template_name
  node     = local.proxmox_node

  # Resources (Req 3.4: 4 cores, 24GB RAM)
  cores     = var.vm_cores
  memory    = var.vm_memory
  disk_size = var.vm_disk_size
  storage   = var.storage_pool

  # Network
  bridge     = local.network_bridge
  ip         = var.vm_ip
  gateway    = local.gateway
  nameserver = local.nameserver

  # Cloud-init
  ci_user    = local.ci_user
  ssh_pubkey = tls_private_key.vm_ssh.public_key_openssh

  # VM Options
  onboot = true
  agent  = 1
  tags   = ["k3s", "single-node", "prod", "alma9"]
}
