---
icon: material/tunnel
---

# cloudflared LXC Deployment

This guide covers deploying a cloudflared LXC container on Proxmox using Terraform, with Cloudflare tunnel and DNS configuration.

## Overview

The `terraform/envs/cloudflared_lxc/` environment creates:

| Component | Description |
|-----------|-------------|
| Proxmox LXC | Lightweight container running cloudflared |
| Cloudflare Tunnel | Named tunnel for secure connectivity |
| DNS Records | CNAME records pointing to the tunnel |
| Configuration Files | Generated config.yaml and credentials.json |

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
terraform/envs/cloudflared_lxc/
├── main.tf                  # Main configuration
├── providers.tf             # Provider configurations
├── variables.tf             # Input variables
├── outputs.tf               # Output values
├── lxc.tf                   # Proxmox LXC resource
├── cloudflare.tf            # Cloudflare resources
├── locals.tf                # Computed values
├── config.yaml              # cloudflared config template
└── terraform.tfvars.example # Example variable values
```

## Configuration

### Step 1: Create Variables File

```bash
cd terraform/envs/cloudflared_lxc
cp terraform.tfvars.example terraform.tfvars
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

# LXC Configuration
lxc_hostname  = "cloudflared"
lxc_cores     = 1
lxc_memory    = 512
lxc_disk_size = "4G"
lxc_ip        = "10.0.10.10/24"
lxc_gateway   = "10.0.10.1"

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
cd terraform/envs/cloudflared_lxc
tofu init
```

### Plan Changes

```bash
tofu plan
```

Review the planned changes:

- 1 LXC container
- 1 Cloudflare tunnel
- 1 Cloudflare tunnel configuration
- N DNS records (one per ingress rule)
- 2 local files (config.yaml, credentials.json)

### Apply Changes

```bash
tofu apply
```

Type `yes` to confirm.

## Post-Deployment Setup

After Terraform creates the resources, you need to install and configure cloudflared in the LXC container.

### Step 1: Install cloudflared

SSH into your Proxmox host and run:

```bash
# Get the LXC VM ID from Terraform output
LXC_ID=$(cd terraform/envs/cloudflared_lxc && tofu output -raw lxc_vmid)

# Install dependencies
pct exec $LXC_ID -- apt-get update
pct exec $LXC_ID -- apt-get install -y curl gnupg2

# Add Cloudflare repository
pct exec $LXC_ID -- bash -c 'mkdir -p /usr/share/keyrings'
pct exec $LXC_ID -- bash -c 'curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null'
pct exec $LXC_ID -- bash -c 'echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared bookworm main" | tee /etc/apt/sources.list.d/cloudflared.list'

# Install cloudflared
pct exec $LXC_ID -- apt-get update
pct exec $LXC_ID -- apt-get install -y cloudflared
```

### Step 2: Copy Configuration Files

The Terraform configuration generates files in `terraform/envs/cloudflared_lxc/generated/`:

```bash
# Create config directory in LXC
pct exec $LXC_ID -- mkdir -p /etc/cloudflared

# Copy config files (from your workstation to Proxmox, then to LXC)
# Option 1: SCP to Proxmox, then pct push
scp terraform/envs/cloudflared_lxc/generated/config.yaml proxmox:/tmp/
scp terraform/envs/cloudflared_lxc/generated/credentials.json proxmox:/tmp/
ssh proxmox "pct push $LXC_ID /tmp/config.yaml /etc/cloudflared/config.yaml"
ssh proxmox "pct push $LXC_ID /tmp/credentials.json /etc/cloudflared/credentials.json"

# Set permissions
pct exec $LXC_ID -- chmod 600 /etc/cloudflared/credentials.json
pct exec $LXC_ID -- chmod 644 /etc/cloudflared/config.yaml
```

### Step 3: Start cloudflared Service

```bash
# Enable and start the service
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
tofu output lxc_vmid
tofu output tunnel_id
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
