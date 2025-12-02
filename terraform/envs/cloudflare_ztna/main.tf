# =============================================================================
# Cloudflare Zero Trust Environment - Main
# =============================================================================

module "cloudflare_ztna" {
  source = "../../modules/cloudflare_ztna"

  account_id = "ecd2157f6d71b0fe0dc6f58ba4bd5872"
  zone_name  = "chriswagner.dev"

  tunnel_name = "prod-homelab-tunnel-001"

  origins = {
    proxmox = "https://10.23.45.10:8006"
  }

  access_apps   = ["proxmox"]
  access_emails = ["christopherwagner0700@gmail.com"]
}
