---
icon: material/cloud
---

# Cloudflare Integration

Cloudflare provides secure external access to homelab services through Cloudflare Tunnels and Zero Trust Network Access (ZTNA).

## Overview

Cloudflare Tunnels create a secure, outbound-only connection from your infrastructure to Cloudflare's edge network, eliminating the need to:

- Open inbound ports on your firewall
- Expose your home IP address
- Manage SSL certificates manually
- Configure VPN access

![Cloudflare Tunnel Architecture](../assets/cloudflared-tunnel.png)

## Architecture

The homelab uses a modular Terraform/OpenTofu setup for Cloudflare Zero Trust:

```
terraform/
├── modules/
│   └── cloudflare_ztna/       # Reusable ZTNA module
│       ├── main.tf            # Tunnel, DNS, Access resources
│       ├── variables.tf       # Module inputs
│       └── outputs.tf         # Module outputs
└── envs/
    └── cloudflare_ztna/       # Production environment
        ├── main.tf            # Module invocation
        └── providers.tf       # Provider configuration
```

## Components

### Cloudflare ZTNA Module

The `terraform/modules/cloudflare_ztna` module provides a reusable infrastructure-as-code component that manages:

- **Cloudflare Tunnel** - Named tunnel for secure connectivity
- **Tunnel Configuration** - Ingress rules routing traffic to internal services
- **DNS Records** - Automatic CNAME records pointing to the tunnel
- **Access Applications** (optional) - Zero Trust access control
- **Access Policies** (optional) - Identity-based authentication rules

### Production Environment

The `terraform/envs/cloudflare_ztna/` environment deploys:

- Tunnel named `prod-homelab-tunnel-001`
- Proxmox web interface at `proxmox.chriswagner.dev`
- TLS verification bypass for self-signed certificates
- Optional Access protection with email authentication

## Benefits

!!! success "Security" - No exposed ports or public IP address - Built-in DDoS protection from Cloudflare's global network - Zero Trust access control with identity verification - TLS encryption end-to-end

!!! success "Simplicity" - Automatic SSL certificates managed by Cloudflare - Single module for all Cloudflare resources - Infrastructure as Code with OpenTofu/Terraform - Dynamic ingress rules from simple map variable

!!! success "Performance" - Global edge network with 300+ data centers - Automatic routing optimization - Built-in caching and compression - HTTP/2 and HTTP/3 support

## Zero Trust Access Control

The ZTNA module supports optional Cloudflare Access integration for identity-based authentication:

- **Email Authentication** - Allow specific email addresses
- **Session Management** - Configurable session duration
- **Application-Level Policies** - Protect individual services
- **Audit Logging** - Track all access attempts

## Quick Start

### Prerequisites

- Cloudflare account with domain configured
- API token with permissions:
  - `Account → Cloudflare Tunnel → Edit`
  - `Zone → DNS → Edit`
  - `Account → Access: Apps and Policies → Edit` (if using Access)
- OpenTofu or Terraform >= 1.5.0

### Deploy the Tunnel

1. Set your API token:

```bash
export CLOUDFLARE_API_TOKEN="your-token-here"
```

2. Navigate to the environment:

```bash
cd terraform/envs/cloudflare_ztna
```

3. Review and customize `main.tf`:

```terraform
module \"cloudflare_ztna\" {
  source = \"../../modules/cloudflare_ztna\"

  account_id  = \"your-account-id\"
  zone_name   = \"yourdomain.com\"
  tunnel_name = \"prod-homelab-tunnel-001\"

  origins = {
    proxmox = \"https://10.23.45.10:8006\"
    # Add more services here
  }

  # Optional: Enable Zero Trust Access
  access_enabled = true
  access_apps    = [\"proxmox\"]
  access_emails  = [\"your-email@example.com\"]
}
```

4. Deploy:

```bash
tofu init
tofu plan
tofu apply
```

5. Install cloudflared on a machine that can reach your internal services:

```bash
# Get the tunnel token from Cloudflare dashboard
cloudflared tunnel run --token <your-tunnel-token>
```

## Module Usage

### Basic Configuration

```terraform
module \"cloudflare_ztna\" {
  source = \"../../modules/cloudflare_ztna\"

  account_id  = \"8d7f7fe4b9e7ed7f3c70ee1dcfe3eca6\"
  zone_name   = \"chriswagner.dev\"
  tunnel_name = \"homelab-tunnel\"

  origins = {
    service1 = \"http://10.0.0.10:8080\"
    service2 = \"https://10.0.0.20:443\"
  }
}
```

### With Zero Trust Access

```terraform
module \"cloudflare_ztna\" {
  source = \"../../modules/cloudflare_ztna\"

  account_id  = \"8d7f7fe4b9e7ed7f3c70ee1dcfe3eca6\"
  zone_name   = \"chriswagner.dev\"
  tunnel_name = \"homelab-tunnel\"

  origins = {
    proxmox  = \"https://10.23.45.10:8006\"
    portainer = \"https://10.23.45.20:9443\"
  }

  # Enable Access for sensitive services
  access_enabled    = true
  access_apps       = [\"proxmox\", \"portainer\"]
  access_emails     = [\"admin@example.com\"]
  session_duration  = \"24h\"
}
```

## Complete Example with Tiered Access

```terraform
module "cloudflare_ztna" {
  source = "../../modules/cloudflare_ztna"

  account_id  = "your-account-id"
  zone_name   = "chriswagner.dev"
  tunnel_name = "prod-homelab-tunnel-001"

  # Expose internal services through the tunnel
  origins = {
    proxmox  = "https://10.23.45.10:8006"
    argocd   = "https://10.23.45.20:8080"
    grafana  = "https://10.23.45.30:3000"
  }

  # Tier 1: Admin services with WARP
  # Tier 2: Monitoring accessible from mobile
  access_applications = {
    # Tier 1: Proxmox requires WARP
    proxmox = {
      session_duration = "24h"
      policies = [{
        name     = "Allow Managed Devices"
        decision = "allow"
        include = {
          emails = ["admin@example.com"]
        }
        require = {
          warp_enabled    = true
          device_enrolled = true
          countries       = ["US"]
        }
      }]
    }

    # Tier 1: ArgoCD requires WARP
    argocd = {
      session_duration = "12h"
      policies = [{
        name     = "Allow Managed Devices"
        decision = "allow"
        include = {
          emails = ["admin@example.com"]
        }
        require = {
          warp_enabled    = true
          device_enrolled = true
        }
      }]
    }

    # Tier 2: Grafana accessible from any device
    grafana = {
      session_duration = "24h"
      policies = [{
        name     = "Allow Any Device"
        decision = "allow"
        include = {
          emails = ["admin@example.com"]
        }
        require = {
          countries = ["US"]
        }
      }]
    }
  }
}
```

## Documentation

- [Access Policies](access-policies.md) - Detailed guide on tiered access control
- [cloudflared LXC](cloudflared-lxc.md) - Deploy the cloudflared LXC container
- [OpenTofu Modules](../opentofu/modules.md) - Learn about other Terraform modules
