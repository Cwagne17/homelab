# =============================================================================
# cloudflared-lxc Environment - Provider Configuration
#
# Configures the Proxmox and Cloudflare providers for managing the cloudflared
# LXC container and Cloudflare tunnel resources.
#
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  # TODO: Configure remote backend for state management
  # backend "s3" {
  #   bucket         = "homelab-terraform-state"
  #   key            = "cloudflared-lxc/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-lock"
  # }
}

# -----------------------------------------------------------------------------
# Proxmox Provider
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
# Cloudflare Provider
# -----------------------------------------------------------------------------

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
