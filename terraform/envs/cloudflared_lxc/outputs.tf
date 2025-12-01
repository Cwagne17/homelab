# =============================================================================
# cloudflared-lxc Environment - Outputs
#
# Provides key information after deployment for accessing the cloudflared LXC
# and verifying the tunnel configuration.
#
# =============================================================================

# -----------------------------------------------------------------------------
# LXC Information
# -----------------------------------------------------------------------------

output "lxc_vmid" {
  value       = proxmox_lxc.cloudflared.vmid
  description = "Proxmox LXC container VM ID"
}

output "lxc_hostname" {
  value       = proxmox_lxc.cloudflared.hostname
  description = "LXC container hostname"
}

output "lxc_ip" {
  value       = var.lxc_ip
  description = "LXC container IP address"
}

output "lxc_node" {
  value       = proxmox_lxc.cloudflared.target_node
  description = "Proxmox node hosting the LXC"
}

# -----------------------------------------------------------------------------
# Cloudflare Tunnel Information
# -----------------------------------------------------------------------------

output "tunnel_id" {
  value       = cloudflare_zero_trust_tunnel_cloudflared.cloudflared.id
  description = "Cloudflare tunnel ID"
}

output "tunnel_name" {
  value       = cloudflare_zero_trust_tunnel_cloudflared.cloudflared.name
  description = "Cloudflare tunnel name"
}

output "tunnel_cname" {
  value       = "${cloudflare_zero_trust_tunnel_cloudflared.cloudflared.id}.cfargotunnel.com"
  description = "Cloudflare tunnel CNAME target"
}

# -----------------------------------------------------------------------------
# DNS Records
# -----------------------------------------------------------------------------

output "dns_records" {
  value = {
    for hostname, record in cloudflare_record.tunnel_dns :
    hostname => {
      name    = record.name
      type    = record.type
      content = record.content
      proxied = record.proxied
    }
  }
  description = "Created DNS records pointing to the tunnel"
}

# -----------------------------------------------------------------------------
# Configuration Files
# -----------------------------------------------------------------------------

output "config_file_path" {
  value       = local_file.cloudflared_config.filename
  description = "Path to the generated cloudflared config.yaml"
}

output "credentials_file_path" {
  value       = local_sensitive_file.cloudflared_credentials.filename
  description = "Path to the generated credentials.json (sensitive)"
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Access Commands
# -----------------------------------------------------------------------------

output "ssh_command" {
  value       = var.lxc_ip != "dhcp" ? "ssh root@${split("/", var.lxc_ip)[0]}" : "ssh root@<lxc-ip> # Get IP from Proxmox UI"
  description = "SSH command to connect to the LXC container"
}

output "pct_exec_command" {
  value       = "pct exec ${proxmox_lxc.cloudflared.vmid} -- bash"
  description = "Command to execute bash in the LXC from Proxmox host"
}

# -----------------------------------------------------------------------------
# Verification Commands
# -----------------------------------------------------------------------------

output "verification_commands" {
  value = {
    check_service = "pct exec ${proxmox_lxc.cloudflared.vmid} -- systemctl status cloudflared"
    check_tunnel  = "pct exec ${proxmox_lxc.cloudflared.vmid} -- cloudflared tunnel info ${cloudflare_zero_trust_tunnel_cloudflared.cloudflared.id}"
    test_dns      = "dig +short ${var.ingress_rules[0].hostname}"
    test_http     = "curl -I https://${var.ingress_rules[0].hostname}"
  }
  description = "Commands to verify the cloudflared deployment"
}

# -----------------------------------------------------------------------------
# Setup Instructions
# -----------------------------------------------------------------------------

output "setup_instructions" {
  value = <<-EOT
    ============================================================
    Cloudflared LXC Deployment Complete!
    ============================================================

    LXC Container:
      - VM ID: ${proxmox_lxc.cloudflared.vmid}
      - Hostname: ${proxmox_lxc.cloudflared.hostname}
      - IP: ${var.lxc_ip}
      - Node: ${proxmox_lxc.cloudflared.target_node}

    Cloudflare Tunnel:
      - ID: ${cloudflare_zero_trust_tunnel_cloudflared.cloudflared.id}
      - Name: ${cloudflare_zero_trust_tunnel_cloudflared.cloudflared.name}

    Next Steps:
    1. SSH into the Proxmox host
    2. Install cloudflared in the LXC:
       pct exec ${proxmox_lxc.cloudflared.vmid} -- apt-get update
       pct exec ${proxmox_lxc.cloudflared.vmid} -- apt-get install -y curl gnupg2
       # Follow the installation steps in the documentation

    3. Copy config files from: ${path.module}/generated/
       - config.yaml -> /etc/cloudflared/config.yaml
       - credentials.json -> /etc/cloudflared/credentials.json

    4. Start the service:
       pct exec ${proxmox_lxc.cloudflared.vmid} -- systemctl enable cloudflared
       pct exec ${proxmox_lxc.cloudflared.vmid} -- systemctl start cloudflared

    5. Verify:
       - Cloudflare Dashboard: Check tunnel is "Healthy"
       - Test URL: https://${var.ingress_rules[0].hostname}

    ============================================================
  EOT
  description = "Post-deployment setup instructions"
}
