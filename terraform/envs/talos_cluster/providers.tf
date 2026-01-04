terraform {
  required_providers {
    # kubernetes = {
    #   source  = "hashicorp/kubernetes"
    #   version = "3.0.1"
    # }
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.90.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.9.0"
    }
  }
}

provider "proxmox" {
  endpoint = "https://10.23.45.10:8006"
  insecure = true

  api_token = var.proxmox_api_token
  ssh {
    agent    = true
    username = "terraform"
  }
}


# provider "kubernetes" {
#   host                   = module.talos.kube_config.kubernetes_client_configuration.host
#   client_certificate     = base64decode(module.talos.kube_config.kubernetes_client_configuration.client_certificate)
#   client_key             = base64decode(module.talos.kube_config.kubernetes_client_configuration.client_key)
#   cluster_ca_certificate = base64decode(module.talos.kube_config.kubernetes_client_configuration.ca_certificate)
# }