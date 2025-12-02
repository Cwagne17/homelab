# =============================================================================
# Cloudflare Zero Trust Network Access Module - Variables
#
# This module manages Cloudflare Zero Trust Tunnels with dynamic ingress
# rules and optional Access protection.
# =============================================================================

variable "account_id" {
  type        = string
  description = "Cloudflare account ID"
}

variable "zone_name" {
  type        = string
  description = "Cloudflare zone name, e.g. chriswagner.dev"
}

variable "tunnel_name" {
  type        = string
  description = "Name for the Cloudflare tunnel"
}

variable "origins" {
  type        = map(string)
  description = "Map of subdomain -> internal origin URL (e.g. { proxmox = \"https://10.23.45.10:8006\" })"
}

variable "access_applications" {
  type = map(object({
    session_duration = optional(string, "24h")
    policy_name      = optional(string, "Allow Access")
    
    # Include conditions (at least one must match)
    include = object({
      emails = optional(list(string), [])
    })

    # Require conditions (all must match)
    require = optional(object({
      login_methods = optional(list(string), [])
      countries     = optional(list(string), [])
      ip_ranges     = optional(list(string), [])
    }), {})

    # Exclude conditions (none can match)
    exclude = optional(object({
      emails    = optional(list(string), [])
      countries = optional(list(string), [])
      ip_ranges = optional(list(string), [])
    }), {})
  }))
  default     = {}
  description = <<-EOT
    Map of subdomain -> Access application configuration. Each app gets one allow policy,
    and all apps share a default deny policy.
    
    Example - Tier 1 (Admin with GitHub):
    {
      proxmox = {
        session_duration = "24h"
        policy_name      = "Allow Chris via GitHub"
        include = {
          emails = ["chris@example.com"]
        }
        require = {
          login_methods = ["github"]
        }
      }
    }
    
    Example - Tier 2 (Flexible, country restricted):
    {
      grafana = {
        session_duration = "24h"
        policy_name      = "Allow Chris Any Device"
        include = {
          emails = ["chris@example.com"]
        }
        require = {
          countries = ["US"]
        }
      }
    }
  EOT
}
