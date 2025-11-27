# =============================================================================
# k3s-single Environment - Main Configuration
#
# Deploys a single-node k3s cluster on Proxmox using the proxmox-vm module.
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
      version = "~> 2.9"
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
# Provider Configuration
# -----------------------------------------------------------------------------

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = var.pm_tls_insecure

  # Enable debug logging if needed
  # pm_debug = true
  # pm_log_enable = true
  # pm_log_file = "terraform-proxmox.log"
}

# -----------------------------------------------------------------------------
# k3s Single Node
# -----------------------------------------------------------------------------

module "k3s_node" {
  source = "../../modules/proxmox-vm"

  # VM Identity
  name     = var.vm_name
  template = var.template_name
  node     = var.proxmox_node

  # Resources (Req 3.4: 4 cores, 24GB RAM)
  cores     = var.vm_cores
  memory    = var.vm_memory
  disk_size = var.vm_disk_size
  storage   = var.storage_pool

  # Network
  bridge     = var.network_bridge
  ip         = var.vm_ip
  gateway    = var.vm_gateway
  nameserver = var.vm_nameserver

  # Cloud-init
  ci_user    = var.ci_user
  ssh_pubkey = var.ssh_public_key

  # VM Options
  onboot = true
  agent  = 1
  tags   = ["k3s", "single-node", "homelab"]
}
