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
          origin_request = {
            no_tls_verify = true // Skip TLS verification for internal services because unless mTLS is setup
          }
        },
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

# -----------------------------------------------------------------------------
# Cloudflare Access Applications
# -----------------------------------------------------------------------------

resource "cloudflare_zero_trust_access_application" "app" {
  for_each = var.access_applications

  account_id                = var.account_id
  name                      = "${each.key}.${var.zone_name}"
  domain                    = "${each.key}.${var.zone_name}"
  type                      = "self_hosted"
  session_duration          = each.value.session_duration
  
  # Link policies to this application
  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.allow[each.key].id
      precedence = 1
    },
    {
      id         = cloudflare_zero_trust_access_policy.default_deny[0].id
      precedence = 100
    }
  ]
  
  depends_on = [
    cloudflare_zero_trust_access_policy.allow,
    cloudflare_zero_trust_access_policy.default_deny
  ]
}

# -----------------------------------------------------------------------------
# Cloudflare Access Policies
# -----------------------------------------------------------------------------

# One allow policy per application
resource "cloudflare_zero_trust_access_policy" "allow" {
  for_each = var.access_applications

  account_id = var.account_id
  name       = "${each.key}.${var.zone_name} - ${each.value.policy_name}"
  decision   = "allow"

  # Include rules - at least one must match
  include = length(each.value.include.emails) > 0 ? [
    for email in each.value.include.emails : {
      email = {
        email = email
      }
    }
  ] : []

  # Require rules - all must match
  require = concat(
    # Login methods (e.g., GitHub)
    length(each.value.require.login_methods) > 0 ? [
      for method in each.value.require.login_methods : {
        login_method = {
          id = method
        }
      }
    ] : [],
    
    # Country requirement
    length(each.value.require.countries) > 0 ? [
      for country in each.value.require.countries : {
        geo = {
          country_code = country
        }
      }
    ] : [],
    
    # IP range requirement
    length(each.value.require.ip_ranges) > 0 ? [
      for ip_range in each.value.require.ip_ranges : {
        ip = {
          ip = ip_range
        }
      }
    ] : []
  )

  # Exclude rules - none can match
  exclude = concat(
    # Email-based exclude
    length(each.value.exclude.emails) > 0 ? [
      for email in each.value.exclude.emails : {
        email = {
          email = email
        }
      }
    ] : [],
    
    # Country exclude
    length(each.value.exclude.countries) > 0 ? [
      for country in each.value.exclude.countries : {
        geo = {
          country_code = country
        }
      }
    ] : [],
    
    # IP range exclude
    length(each.value.exclude.ip_ranges) > 0 ? [
      for ip_range in each.value.exclude.ip_ranges : {
        ip = {
          ip = ip_range
        }
      }
    ] : []
  )
}

# One default deny policy for the entire account
resource "cloudflare_zero_trust_access_policy" "default_deny" {
  count = length(var.access_applications) > 0 ? 1 : 0

  account_id = var.account_id
  name       = "Default Deny All"
  decision   = "deny"

  include = [{
    everyone = {}
  }]

  # Make sure allow policies are created first
  depends_on = [cloudflare_zero_trust_access_policy.allow]
}
