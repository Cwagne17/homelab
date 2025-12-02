# =============================================================================
# Cloudflare Zero Trust Environment - Main
#
# This environment configures Cloudflare Tunnel and Zero Trust Access with
# tiered security policies.
#
# Security Tiers:
#   - Tier 1: Admin services requiring WARP (Proxmox, ArgoCD, K8s)
#   - Tier 2: Services accessible from mobile (Grafana, docs)
#   - Tier 3: No Access protection (Jellyfin, for TVs) - not in access_applications
#
# See: docs/cloudflare/access-policies.md for detailed policy guide
# =============================================================================

module "cloudflare_ztna" {
  source = "../../modules/cloudflare_ztna"

  account_id  = "ecd2157f6d71b0fe0dc6f58ba4bd5872"
  zone_name   = "chriswagner.dev"
  tunnel_name = "prod-homelab-tunnel-001"

  # Tunnel origins - services to expose
  origins = {
    proxmox = "https://10.23.45.10:8006"
  }

  # Tier 1: Admin-only with GitHub login required (strict)
  access_applications = {
    proxmox = {
      session_duration = "24h"
      policy_name      = "Allow Chris via GitHub"
      include = {
        emails = ["christopherwagner0700@gmail.com"]
      }
      require = {
        login_methods = ["GitHub"]
        countries     = ["US"]
      }
    }
  }
}
