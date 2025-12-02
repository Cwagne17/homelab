# Cloudflare ZTNA Module

Terraform/OpenTofu module for managing Cloudflare Zero Trust Network Access with Cloudflare Tunnels and tiered access policies.

## Features

- 🔒 **Zero Trust Access** - Identity-based authentication with device posture
- 🌐 **Cloudflare Tunnel** - Secure outbound-only connections (no exposed ports)
- 🎯 **Tiered Policies** - Flexible security levels (strict WARP-required to mobile-friendly)
- 🔄 **Dynamic Configuration** - Manage multiple services with ingress rules
- 📝 **DNS Automation** - Automatic CNAME record creation
- 🛡️ **Device Posture** - WARP client and device enrollment checks

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

### Tier 1: Admin with WARP (Most Secure)

Require WARP client and device enrollment:

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
      policies = [
        {
          name     = "Allow Managed Devices"
          decision = "allow"
          priority = 1
          include = {
            emails = ["admin@example.com"]
          }
          require = {
            warp_enabled    = true
            device_enrolled = true
            countries       = ["US"]
          }
        },
        {
          name     = "Default Deny"
          decision = "deny"
          priority = 100
          include = {
            everyone = true
          }
        }
      ]
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
      policies = [{
        name     = "Allow From US"
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

### Mixed Tier: Split Policies

Different policies for different device types:

```terraform
access_applications = {
  grafana = {
    session_duration = "24h"
    policies = [
      {
        name     = "Allow Managed Devices"
        decision = "allow"
        priority = 1
        include = {
          emails = ["admin@example.com"]
        }
        require = {
          warp_enabled    = true
          device_enrolled = true
        }
      },
      {
        name     = "Allow Mobile from US"
        decision = "allow"
        priority = 2
        include = {
          emails = ["admin@example.com"]
        }
        require = {
          countries = ["US"]
        }
      }
    ]
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
  policies = list(object({
    name     = string        # Policy name
    decision = string        # "allow" or "deny"
    priority = number        # Lower = higher priority (optional)

    include = object({
      emails    = list(string)  # Email addresses
      groups    = list(string)  # Access group IDs
      everyone  = bool          # true for deny-all policies
      ip_ranges = list(string)  # CIDR ranges
      countries = list(string)  # ISO 3166-1 country codes
    })

    require = object({       # All conditions must match
      warp_enabled        = bool          # WARP client active
      device_enrolled     = bool          # Device enrolled in org
      countries           = list(string)  # Country codes
      ip_ranges           = list(string)  # CIDR ranges
      certificate_present = bool          # mTLS cert required
    })

    exclude = object({       # None can match
      emails    = list(string)
      groups    = list(string)
      countries = list(string)
      ip_ranges = list(string)
    })
  }))
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

- `emails` - List of email addresses
- `groups` - List of Access group IDs
- `everyone` - Match everyone (use for deny policies)
- `ip_ranges` - List of IP CIDR ranges
- `countries` - List of ISO 3166-1 country codes

### Require Rules (AND Logic)

All conditions must match:

- `warp_enabled` - WARP client must be active
- `device_enrolled` - Device must be enrolled in organization
- `countries` - Must be from these countries
- `ip_ranges` - Must be from these IP ranges
- `certificate_present` - mTLS certificate required

### Exclude Rules (NOT Logic)

None of these can match:

- `emails` - Block specific emails
- `groups` - Block specific groups
- `countries` - Block specific countries
- `ip_ranges` - Block specific IP ranges

## Security Tiers

### Tier 1: Admin Services (WARP Required)

**Use for:** Proxmox, Kubernetes, infrastructure

```terraform
require = {
  warp_enabled    = true
  device_enrolled = true
  countries       = ["US"]
}
```

### Tier 2: Flexible Access (No WARP)

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

## Device Posture Setup

### 1. Create Zero Trust Organization

1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Settings → General → Create organization

### 2. Install WARP Client

Download from: https://1.1.1.1/

### 3. Enroll Device

1. Open WARP → Settings → Preferences → Account
2. Login with organization name
3. Authenticate with email

### 4. Verify

```bash
warp-cli status
# Should show: Connected
```

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
