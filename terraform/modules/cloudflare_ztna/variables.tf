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

variable "access_enabled" {
  type        = bool
  default     = true
  description = "Whether to configure Cloudflare Access for selected origins"
}

variable "access_apps" {
  type        = list(string)
  default     = []
  description = "List of subdomains from 'origins' that should be protected by Access"
}

variable "access_emails" {
  type        = list(string)
  default     = []
  description = "Emails allowed to log in to Access-protected apps"
}

variable "session_duration" {
  type        = string
  default     = "24h"
  description = "Access session duration"
}
