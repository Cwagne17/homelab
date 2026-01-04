---
icon: material/tunnel
---

# cloudflared LXC Deployment

This guide covers deploying a cloudflared LXC container on Proxmox and configuring the Cloudflare Tunnel and DNS records. In this repository Terraform/OpenTofu manages the Cloudflare resources (tunnel, DNS, and config files). The LXC itself may be created either by Terraform or installed manually — in my setup I use the Proxmox community helper script to create and install the LXC.

## Overview

The `terraform/envs/cloudflare_ztna/` environment configures Cloudflare Zero Trust (ZTNA) resources — Cloudflare Tunnel, DNS records, and Access policies. This environment does not provision the LXC/container running the `cloudflared` connector; that container may be created manually (for example, with the Proxmox community helper script) or with separate provisioning tooling.

| Component         | Description                                                                |
| ----------------- | -------------------------------------------------------------------------- |
| Cloudflare Tunnel | Named tunnel for secure connectivity                                       |
| DNS Records       | CNAME records pointing to the tunnel                                       |
| Configuration     | Cloudflare-managed tunnel configuration and Access application definitions |

## Prerequisites

Before deploying, ensure you have:

### Proxmox Requirements

- Proxmox VE with API access configured
- API token with appropriate permissions
- LXC template available (e.g., Debian 12)
- Network connectivity to Cloudflare

### Cloudflare Requirements

- Cloudflare account with the domain configured
- API token with permissions:
  - `Zone:DNS:Edit`
  - `Account:Cloudflare Tunnel:Edit`
- Account ID and Zone ID from Cloudflare dashboard

### Tools

- OpenTofu or Terraform >= 1.0
- `openssl` for generating tunnel secret

## Directory Structure

```
terraform/envs/cloudflare_ztna/
├── main.tf                  # Main configuration (module invocation)
├── providers.tf             # Provider configurations
```

## Configuration

### Step 1: Create Variables File

```bash
cd terraform/envs/cloudflare_ztna
```

Edit `terraform.tfvars` with your values:

```hcl
# Proxmox Configuration
pm_api_url      = "https://10.0.10.2:8006/api2/json"
pm_api_token_id = "root@pam!terraform"
pm_tls_insecure = true

proxmox_node   = "pve"
storage_pool   = "local-lvm"
network_bridge = "vmbr0"
lxc_template   = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"

# Note: LXC/container networking and host details are not managed by this environment.
# Provision the container separately (e.g., Proxmox script) and ensure it can reach your LAN.

# Cloudflare Configuration
cloudflare_account_id = "your-account-id"
cloudflare_zone_id    = "your-zone-id"
tunnel_name           = "homelab-cloudflared"
domain                = "chriswagner.dev"

# Ingress Rules
ingress_rules = [
  {
    hostname      = "proxmox.chriswagner.dev"
    service       = "https://10.0.10.2:8006"
    no_tls_verify = true
  }
]
```

### Step 2: Set Secrets

Use environment variables for sensitive values:

```bash
# Proxmox API secret
export TF_VAR_pm_api_token_secret="your-proxmox-token-secret"

# Cloudflare API token
export TF_VAR_cloudflare_api_token="your-cloudflare-api-token"

# LXC root password
export TF_VAR_lxc_password="secure-password"

# Tunnel secret (generate with: openssl rand -base64 32)
export TF_VAR_tunnel_secret="$(openssl rand -base64 32)"
```

!!! warning "Security"
Never commit secrets to version control. Use environment variables or a secrets manager.

### Step 3: Finding Cloudflare IDs

**Account ID:**

1. Log into Cloudflare dashboard
2. Click on any domain
3. Scroll down on the right sidebar to "API" section
4. Copy the "Account ID"

**Zone ID:**

1. Log into Cloudflare dashboard
2. Select your domain (chriswagner.dev)
3. Scroll down on the right sidebar to "API" section
4. Copy the "Zone ID"

## Deployment

### Initialize Terraform

```bash
cd terraform/envs/cloudflare_ztna
tofu init
```

### Plan Changes

```bash
tofu plan
```

Review the planned changes:

- Cloudflare tunnel and associated resources
- DNS records for configured hostnames
- Access application and policy resources (if configured)

Note: This environment does not create an LXC/container — it only manages Cloudflare-side resources.

### Apply Changes

```bash
tofu apply
```

Type `yes` to confirm.

## Post-Deployment Setup

After Terraform creates the Cloudflare resources, you still need a running `cloudflared` connector inside an LXC or VM. You can create that container manually (for example using the Proxmox community helper script):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/cloudflared.sh)"
```

Script documentation: https://community-scripts.github.io/ProxmoxVE/scripts?id=cloudflared

Note: I modified the community script to configure a static IP and to set my LAN gateway. The `cloudflare_ztna` module does not manage container networking — ensure the connector has the correct static IP/gateway as needed.

### Step 2: Copy Configuration Files

The Terraform environment manages Cloudflare-side resources and does not create container files for you. After `tofu apply` you can obtain necessary tunnel details from Terraform outputs or from the Cloudflare Zero Trust dashboard (Tunnel ID, CNAME, and installation token). Example useful outputs:

```bash
# Show available outputs
tofu output

# Tunnel-specific outputs
tofu output tunnel_id
tofu output tunnel_cname
tofu output setup_instructions
```

Use the Cloudflare dashboard or the `setup_instructions` output to generate or retrieve the connector credentials, then place them into your container's `/etc/cloudflared/` directory as needed.

### Step 3: Start cloudflared Service

```bash
# Enable and start the service inside the connector container
pct exec $LXC_ID -- systemctl enable cloudflared
pct exec $LXC_ID -- systemctl start cloudflared

# Check status
pct exec $LXC_ID -- systemctl status cloudflared
```

## Verification

### Check Tunnel Status

**Cloudflare Dashboard:**

1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Navigate to Access → Tunnels
3. Verify the tunnel shows as "Healthy"

**Command Line:**

```bash
# Check service status
pct exec $LXC_ID -- systemctl status cloudflared

# Check tunnel connectivity
pct exec $LXC_ID -- cloudflared tunnel info
```

### Test DNS Resolution

```bash
# Check DNS record
dig +short proxmox.chriswagner.dev

# Should return Cloudflare IPs (proxied)
```

### Test HTTP Access

```bash
# Test the proxied endpoint
curl -I https://proxmox.chriswagner.dev
```

## Adding More Services

To add additional services to the tunnel, update the `ingress_rules` variable:

```hcl
ingress_rules = [
  {
    hostname      = "proxmox.chriswagner.dev"
    service       = "https://10.0.10.2:8006"
    no_tls_verify = true
  },
  {
    hostname      = "service.chriswagner.dev"
    service       = "http://10.0.10.x:port"
    no_tls_verify = false
  },
]
```

Then apply the changes:

```bash
tofu apply
```

The Cloudflare tunnel configuration and DNS records will be updated automatically.

## Troubleshooting

### Tunnel Not Connecting

```bash
# Check cloudflared logs
pct exec $LXC_ID -- journalctl -u cloudflared -f

# Verify credentials file
pct exec $LXC_ID -- cat /etc/cloudflared/credentials.json

# Verify config file
pct exec $LXC_ID -- cat /etc/cloudflared/config.yaml
```

### DNS Not Resolving

```bash
# Check if record exists
dig proxmox.chriswagner.dev

# Verify in Cloudflare dashboard
# Check DNS → Records for the zone
```

### Service Not Accessible

1. Verify the internal service is running
2. Check the LXC can reach the service: `curl -k https://10.0.10.2:8006`
3. Verify the ingress rule hostname matches the DNS record
4. Check cloudflared logs for routing errors

## Outputs

After deployment, useful outputs are available:

```bash
# Show all outputs
tofu output

# Specific outputs
tofu output tunnel_id
tofu output tunnel_cname
tofu output setup_instructions
```

## Destroying Resources

To remove all resources:

```bash
tofu destroy
```

!!! warning "Data Loss"
This will delete the LXC container, tunnel, and DNS records. The tunnel secret will need to be regenerated for a new deployment.

## Next Steps

- [Overview](index.md) - Return to Cloudflare overview
- [OpenTofu Infrastructure](../opentofu/infrastructure.md) - Learn about other Terraform environments
