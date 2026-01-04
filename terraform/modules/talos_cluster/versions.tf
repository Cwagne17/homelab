terraform {
  required_version = ">= 1.7.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.70.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.7.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.0.0"
    }
  }
}
