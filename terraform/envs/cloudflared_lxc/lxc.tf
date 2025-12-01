# =============================================================================
# cloudflared-lxc Environment - LXC Resource
#
# Creates a Proxmox LXC container running cloudflared as a tunnel service.
#
# =============================================================================

# -----------------------------------------------------------------------------
# Proxmox LXC Container
# -----------------------------------------------------------------------------

resource "proxmox_lxc" "cloudflared" {
  hostname    = var.lxc_hostname
  target_node = var.proxmox_node
  vmid        = var.lxc_vmid > 0 ? var.lxc_vmid : null

  # Template to clone from
  ostemplate = var.lxc_template

  # Resource allocation
  cores  = var.lxc_cores
  memory = var.lxc_memory
  swap   = var.lxc_swap

  # Root filesystem
  rootfs {
    storage = var.storage_pool
    size    = var.lxc_disk_size
  }

  # Network configuration
  network {
    name   = "eth0"
    bridge = var.network_bridge
    ip     = var.lxc_ip == "dhcp" ? "dhcp" : var.lxc_ip
    gw     = var.lxc_ip == "dhcp" ? null : var.lxc_gateway
  }

  # DNS configuration
  nameserver = var.lxc_nameserver

  # Authentication
  # Note: For enhanced security, consider using SSH keys only (set lxc_ssh_public_key)
  # and disabling password authentication after initial setup
  password = var.lxc_password

  # SSH public key (if provided) - recommended for secure access
  ssh_public_keys = var.lxc_ssh_public_key != "" ? var.lxc_ssh_public_key : null

  # Container options
  onboot       = true
  start        = true
  unprivileged = true

  # Features for unprivileged container
  features {
    nesting = true
  }

  # Tags
  tags = join(",", local.lxc_tags)

  # Lifecycle
  lifecycle {
    ignore_changes = [
      # Ignore changes to template after creation
      ostemplate,
    ]
  }
}

# -----------------------------------------------------------------------------
# Provisioner for cloudflared installation and configuration
#
# NOTE: The telmate/proxmox provider does not support remote-exec provisioners
# for LXC containers directly. The recommended approach is to:
#
# 1. Use a pre-built LXC template with cloudflared installed, OR
# 2. Use Proxmox's built-in cloud-init support (limited for LXC), OR
# 3. Run a post-deployment script via SSH or Ansible
#
# The configuration files are created using null_resource with local-exec
# and SSH to push files and run commands.
# -----------------------------------------------------------------------------

resource "null_resource" "cloudflared_setup" {
  depends_on = [proxmox_lxc.cloudflared]

  # Re-run if configuration changes
  triggers = {
    config_hash      = sha256(local.cloudflared_config)
    credentials_hash = sha256(local.cloudflared_credentials)
    lxc_id           = proxmox_lxc.cloudflared.vmid
  }

  # Wait for LXC to be ready
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for LXC container to be ready..."
      sleep 30
    EOT
  }

  # NOTE: This provisioner requires SSH access to the LXC container.
  # The commands below show what needs to be executed. In practice,
  # you may need to adjust the connection method based on your setup.
  #
  # Option 1: Direct SSH to LXC (if network allows)
  # Option 2: SSH to Proxmox host and use pct exec
  # Option 3: Use Ansible for more robust configuration management
  #
  # For demonstration, we output the commands that need to be run:
  provisioner "local-exec" {
    command = <<-EOT
      echo "=============================================="
      echo "Manual steps required to complete cloudflared setup:"
      echo "=============================================="
      echo ""
      echo "1. SSH into the Proxmox host or the LXC container"
      echo ""
      echo "2. Install cloudflared:"
      echo "   pct exec ${proxmox_lxc.cloudflared.vmid} -- bash -c 'apt-get update && apt-get install -y curl gnupg2'"
      echo "   pct exec ${proxmox_lxc.cloudflared.vmid} -- bash -c 'mkdir -p /usr/share/keyrings'"
      echo "   pct exec ${proxmox_lxc.cloudflared.vmid} -- bash -c 'curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null'"
      echo "   pct exec ${proxmox_lxc.cloudflared.vmid} -- bash -c 'echo \"deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared bookworm main\" | tee /etc/apt/sources.list.d/cloudflared.list'"
      echo "   pct exec ${proxmox_lxc.cloudflared.vmid} -- bash -c 'apt-get update && apt-get install -y cloudflared'"
      echo ""
      echo "3. Create config directory:"
      echo "   pct exec ${proxmox_lxc.cloudflared.vmid} -- mkdir -p /etc/cloudflared"
      echo ""
      echo "4. Copy the generated config files from Terraform outputs"
      echo ""
      echo "5. Enable and start the cloudflared service:"
      echo "   pct exec ${proxmox_lxc.cloudflared.vmid} -- systemctl enable cloudflared"
      echo "   pct exec ${proxmox_lxc.cloudflared.vmid} -- systemctl start cloudflared"
      echo ""
      echo "=============================================="
    EOT
  }
}

# -----------------------------------------------------------------------------
# Output the configuration files for manual or automated deployment
# -----------------------------------------------------------------------------

resource "local_file" "cloudflared_config" {
  content  = local.cloudflared_config
  filename = "${path.module}/generated/config.yaml"

  file_permission = "0600"

  depends_on = [cloudflare_zero_trust_tunnel_cloudflared.cloudflared]
}

resource "local_sensitive_file" "cloudflared_credentials" {
  content  = local.cloudflared_credentials
  filename = "${path.module}/generated/credentials.json"

  file_permission = "0600"

  depends_on = [cloudflare_zero_trust_tunnel_cloudflared.cloudflared]
}
