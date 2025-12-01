# =============================================================================
# cloudflared-lxc Environment - Cloudflare Resources
#
# Creates Cloudflare tunnel and DNS resources for the cloudflared LXC.
#
# =============================================================================

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "cloudflare_zone" "domain" {
  zone_id = var.cloudflare_zone_id
}

# -----------------------------------------------------------------------------
# Cloudflare Tunnel
#
# Creates a named tunnel that the cloudflared service will connect to.
# The tunnel secret is provided as a variable and should be a base64-encoded
# string of 32+ random bytes.
#
# To generate a tunnel secret:
#   openssl rand -base64 32
# -----------------------------------------------------------------------------

resource "cloudflare_zero_trust_tunnel_cloudflared" "cloudflared" {
  account_id = var.cloudflare_account_id
  name       = var.tunnel_name
  secret     = var.tunnel_secret
}

# -----------------------------------------------------------------------------
# Cloudflare Tunnel Configuration
#
# Configures the tunnel ingress rules through Cloudflare's API.
# This is the "remotely-managed" tunnel configuration approach.
# -----------------------------------------------------------------------------

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "cloudflared" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.cloudflared.id

  config {
    # Dynamic ingress rules from variable
    dynamic "ingress_rule" {
      for_each = var.ingress_rules
      content {
        hostname = ingress_rule.value.hostname
        service  = ingress_rule.value.service

        dynamic "origin_request" {
          for_each = ingress_rule.value.no_tls_verify ? [1] : []
          content {
            no_tls_verify = true
          }
        }
      }
    }

    # Catch-all rule (required)
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# -----------------------------------------------------------------------------
# DNS Records
#
# Creates CNAME records pointing to the tunnel for each ingress hostname.
# These records are proxied through Cloudflare.
# -----------------------------------------------------------------------------

resource "cloudflare_record" "tunnel_dns" {
  for_each = { for rule in var.ingress_rules : rule.hostname => rule }

  zone_id = var.cloudflare_zone_id
  name    = replace(each.value.hostname, ".${var.domain}", "")
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.cloudflared.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1 # Auto TTL when proxied

  comment = "Managed by Terraform - cloudflared tunnel"
}
