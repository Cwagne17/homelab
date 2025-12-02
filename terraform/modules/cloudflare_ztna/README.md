# Cloudflare ZTNA Module

Terraform/OpenTofu module for managing Cloudflare Zero Trust Network Access with Cloudflare Tunnels and tiered access policies.

## Features

- 🔒 **Zero Trust Access** - Identity-based authentication with login methods
- 🌐 **Cloudflare Tunnel** - Secure outbound-only connections (no exposed ports)
- 🎯 **Tiered Policies** - Flexible security levels (strict IdP-required to country-restricted)
- 🔄 **Dynamic Configuration** - Manage multiple services with ingress rules
- 📝 **DNS Automation** - Automatic CNAME record creation
- 🔑 **Login Methods** - GitHub, Google, and other identity provider support

## Usage

### Basic Tunnel Only

Create a tunnel without Access protection:

```terraform
module "cloudflare_ztna" {
  source = "../../modules/cloudflare_ztna"

  account_id  = "your-account-id"
  zone_name   = "example.com"
  tunnel_name = "homelab-tunnel"

  origins = {
    service1 = "https://10.0.0.10:8443"
    service2 = "http://10.0.0.20:8080"
  }
}
```

### Tier 1: Admin with GitHub (Most Secure)

Require GitHub login:

```terraform
module "cloudflare_ztna" {
  source = "../../modules/cloudflare_ztna"

  account_id  = "your-account-id"
  zone_name   = "example.com"
  tunnel_name = "homelab-tunnel"

  origins = {
    proxmox = "https://10.0.0.10:8006"
  }

  access_applications = {
    proxmox = {
      session_duration = "24h"
      policy_name      = "Allow via GitHub"
      include = {
        emails = ["admin@example.com"]
      }
      require = {
        login_methods = ["github"]
        countries     = ["US"]
      }
    }
  }
}
```

### Tier 2: Flexible Access (Mobile-Friendly)

Allow access from any device with country restriction:

```terraform
module "cloudflare_ztna" {
  source = "../../modules/cloudflare_ztna"

  account_id  = "your-account-id"
  zone_name   = "example.com"
  tunnel_name = "homelab-tunnel"

  origins = {
    grafana = "https://10.0.0.20:3000"
  }

  access_applications = {
    grafana = {
      session_duration = "24h"
      policy_name      = "Allow From US"
      include = {
        emails = ["admin@example.com"]
      }
      require = {
        countries = ["US"]
      }
    }
  }
}
```

## Input Variables

### Required

| Name          | Type          | Description                              |
| ------------- | ------------- | ---------------------------------------- |
| `account_id`  | `string`      | Cloudflare account ID                    |
| `zone_name`   | `string`      | Cloudflare zone name (e.g., example.com) |
| `tunnel_name` | `string`      | Name for the Cloudflare tunnel           |
| `origins`     | `map(string)` | Map of subdomain → internal origin URL   |

### Optional

| Name                  | Type          | Default | Description                                     |
| --------------------- | ------------- | ------- | ----------------------------------------------- |
| `access_applications` | `map(object)` | `{}`    | Access application configurations with policies |

### Access Application Object

```terraform
{
  session_duration = string  # "24h", "12h", "168h" (7 days)
  policy_name      = string  # Policy name (optional, default: "Allow Access")

  include = object({
    emails = list(string)  # Email addresses (required)
  })

  require = object({       # All conditions must match (optional)
    login_methods = list(string)  # Login methods: "github", "google", etc.
    countries     = list(string)  # ISO 3166-1 country codes
    ip_ranges     = list(string)  # CIDR ranges
  })

  exclude = object({       # None can match (optional)
    emails    = list(string)
    countries = list(string)
    ip_ranges = list(string)
  })
}
```

## Outputs

| Name                      | Description                                |
| ------------------------- | ------------------------------------------ |
| `tunnel_id`               | Cloudflare tunnel ID                       |
| `tunnel_cname`            | Tunnel CNAME (e.g., uuid.cfargotunnel.com) |
| `zone_id`                 | Cloudflare zone ID                         |
| `hostnames`               | List of fully-qualified hostnames          |
| `access_applications`     | Map of application names to IDs            |
| `access_application_urls` | Map of application names to URLs           |

## Policy Components

### Include Rules (OR Logic)

At least one condition must match:

- `emails` - List of email addresses (required)

### Require Rules (AND Logic)

All conditions must match:

- `login_methods` - List of login methods (e.g., "github", "google")
- `countries` - Must be from these countries (ISO 3166-1 codes)
- `ip_ranges` - Must be from these IP ranges (CIDR notation)

### Exclude Rules (NOT Logic)

None of these can match:

- `emails` - Block specific emails
- `countries` - Block specific countries (ISO 3166-1 codes)
- `ip_ranges` - Block specific IP ranges (CIDR notation)

## Security Tiers

### Tier 1: Admin Services (GitHub Required)

**Use for:** Proxmox, Kubernetes, infrastructure

```terraform
require = {
  login_methods = ["github"]
  countries     = ["US"]
}
```

### Tier 2: Flexible Access (Country Restricted)

**Use for:** Grafana (mobile), documentation, development tools

```terraform
require = {
  countries = ["US"]
}
```

### Tier 3: No Access Protection

**Use for:** Jellyfin, Plex, services for TVs

- Don't add to `access_applications`
- Protect with application-level auth + WAF

## Login Methods Setup

### 1. Create Zero Trust Organization

1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Settings → General → Create organization

### 2. Configure GitHub Identity Provider

1. Settings → Authentication → Login methods
2. Click "Add new" → Select "GitHub"
3. Follow OAuth setup instructions:
   - Create OAuth app in GitHub
   - Configure redirect URLs
   - Add Client ID and Secret to Cloudflare

### 3. Test Authentication

1. Access a protected service
2. Should redirect to GitHub login
3. After successful login, access should be granted

## Running the Connector

After creating the tunnel with Terraform, you need to run the cloudflared connector:

### Get Tunnel Token

From Cloudflare Dashboard:

1. Zero Trust → Networks → Tunnels
2. Click your tunnel → Configure
3. Copy the installation command token

### Run Connector

```bash
# Docker
docker run -d \
  --name cloudflared \
  --restart unless-stopped \
  cloudflare/cloudflared:latest tunnel run --token <TOKEN>

# systemd
cloudflared tunnel run --token <TOKEN>

# LXC
pct exec <VMID> -- cloudflared tunnel run --token <TOKEN>
```

## Examples

See the [documentation](../../../docs/cloudflare/) for complete examples:

- [Access Policies Guide](../../../docs/cloudflare/access-policies.md)
- [Cloudflare Overview](../../../docs/cloudflare/index.md)

## Requirements

- Terraform/OpenTofu >= 1.5.0
- Cloudflare provider ~> 5.0
- Cloudflare API token with permissions:
  - `Account → Cloudflare Tunnel → Edit`
  - `Zone → DNS → Edit`
  - `Account → Access: Apps and Policies → Edit`

## License

Part of the [homelab](https://github.com/Cwagne17/homelab) project.
