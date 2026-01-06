terraform {
  required_version = ">= 1.7.0"

  backend "s3" {
    bucket         = "homelab-terraform-state-678730054304"
    key            = "talos-cluster/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "homelab-terraform-locks"
    encrypt        = true
    profile        = "chris-personal-mgmt"
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.70.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.9.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
  }
}

provider "proxmox" {
  // Must be within the same network as the Proxmox server
  endpoint = "https://10.23.45.10:8006"
  insecure = true

  api_token = var.proxmox_api_token
}
