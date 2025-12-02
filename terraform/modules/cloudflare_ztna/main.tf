# =============================================================================
# Cloudflare Zero Trust Network Access Module
# =============================================================================

data "cloudflare_zone" "this" {
  filter = {
    name = var.zone_name
  }
}

# -----------------------------------------------------------------------------
# Cloudflare Tunnel
# -----------------------------------------------------------------------------

resource "cloudflare_zero_trust_tunnel_cloudflared" "ztna" {
  account_id = var.account_id
  name       = var.tunnel_name
  config_src = "cloudflare"
}

# -----------------------------------------------------------------------------
# Tunnel Configuration
# -----------------------------------------------------------------------------

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "ztna" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.ztna.id

  config = {
    ingress = concat(
      [for k, v in var.origins : merge(
        {
          hostname = "${k}.${var.zone_name}"
          service  = v
        },
        startswith(v, "https://") ? {
          origin_request = {
            no_tls_verify = true
          }
        } : {}
      )],
      [{
        service = "http_status:404"
      }]
    )
  }
}

# -----------------------------------------------------------------------------
# DNS Records
# -----------------------------------------------------------------------------

resource "cloudflare_dns_record" "app" {
  for_each = var.origins

  zone_id = data.cloudflare_zone.this.zone_id
  name    = each.key
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.ztna.id}.cfargotunnel.com"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - Cloudflare Tunnel for ${each.key}"
}
