# =============================================================================
# cloudflared-lxc Environment - Local Values
#
# Computed values and locals for the cloudflared LXC deployment.
#
# =============================================================================

locals {
  # Extract IP address without CIDR notation for use in commands
  lxc_ip_address = var.lxc_ip == "dhcp" ? "dhcp" : split("/", var.lxc_ip)[0]

  # Network configuration string for LXC
  lxc_network_config = var.lxc_ip == "dhcp" ? "ip=dhcp" : "ip=${var.lxc_ip},gw=${var.lxc_gateway}"

  # Cloudflared config file content
  cloudflared_config = templatefile("${path.module}/config.yaml", {
    tunnel_id         = cloudflare_zero_trust_tunnel_cloudflared.cloudflared.id
    tunnel_name       = var.tunnel_name
    ingress_rules     = var.ingress_rules
  })

  # Cloudflared credentials JSON content
  cloudflared_credentials = jsonencode({
    AccountTag   = var.cloudflare_account_id
    TunnelSecret = var.tunnel_secret
    TunnelID     = cloudflare_zero_trust_tunnel_cloudflared.cloudflared.id
  })

  # Installation script for cloudflared
  # Note: This script is for documentation purposes. The actual provisioning
  # is done through pct exec commands or SSH after LXC creation.
  cloudflared_install_script = <<-EOT
    #!/bin/bash
    set -e

    # Update package lists
    apt-get update

    # Install required packages (including lsb-release for OS detection)
    apt-get install -y curl gnupg2 apt-transport-https lsb-release

    # Add Cloudflare GPG key and repository
    # Using 'bookworm' as the default for Debian 12, or detect dynamically
    mkdir -p /usr/share/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
    CODENAME=$(lsb_release -cs 2>/dev/null || echo "bookworm")
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $CODENAME main" | tee /etc/apt/sources.list.d/cloudflared.list

    # Install cloudflared
    apt-get update
    apt-get install -y cloudflared

    # Create cloudflared config directory
    mkdir -p /etc/cloudflared

    # Enable and start cloudflared service
    systemctl enable cloudflared
    systemctl start cloudflared
  EOT

  # Tags for the LXC container
  lxc_tags = ["cloudflared", "tunnel", "homelab"]
}
