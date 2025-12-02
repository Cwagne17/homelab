# =============================================================================
# Cloudflare Zero Trust Network Access Module - Outputs
# =============================================================================

output "tunnel_id" {
  description = "Cloudflare tunnel ID"
  value       = cloudflare_zero_trust_tunnel_cloudflared.ztna.id
}

output "tunnel_cname" {
  description = "Cloudflare tunnel CNAME"
  value       = "${cloudflare_zero_trust_tunnel_cloudflared.ztna.id}.cfargotunnel.com"
}

output "zone_id" {
  description = "Cloudflare zone ID"
  value       = data.cloudflare_zone.this.zone_id
}

output "hostnames" {
  description = "List of fully-qualified hostnames configured for the tunnel"
  value       = [for k in keys(var.origins) : "${k}.${var.zone_name}"]
}


