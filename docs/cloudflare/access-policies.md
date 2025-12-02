---
icon: material/shield-lock
---

# Cloudflare Access Policies

Cloudflare Access provides Zero Trust Network Access (ZTNA) with identity-based authentication and device posture checks. This guide covers implementing tiered access policies for different security levels.

## Policy Architecture

The ZTNA module supports three security tiers:

### Tier 1: Super Strict (Admin-Only, WARP Required)

**Use for:**

- Proxmox
- Kubernetes dashboards (ArgoCD, Rancher)
- Monitoring (Grafana, Loki, Prometheus)
- Any service with "root of your homelab" power

**Requirements:**

- ✅ Identity verification (email/IdP)
- ✅ Device enrolled in your organization
- ✅ WARP client active at request time
- ✅ Optional: Country restriction, OS verification

**Result:** Even if someone steals the URL, they need your identity, an enrolled device, and WARP active.

### Tier 2: Strong But Usable (Phones, Tablets)

**Use for:**

- Services you might access from mobile devices
- Grafana (if you want mobile access)
- Home Assistant
- Personal documentation

**Requirements:**

- ✅ Identity verification (email/IdP)
- ✅ Country or IP range restriction
- ❌ No WARP required (works on mobile browsers)

**Result:** Still requires authentication, but accessible from any device.

### Tier 3: Consumer Apps (TVs, Streaming)

**Use for:**

- Jellyfin (media streaming)
- Plex
- Services accessed by TVs or devices that can't do SSO

**Protection:**

- ❌ No Cloudflare Access (TVs can't do SSO/WARP)
- ✅ Application-level authentication (Jellyfin users)
- ✅ Cloudflare WAF rules
- ✅ Rate limiting
- ✅ Country-based blocking

## Configuration Examples

### Tier 1: Proxmox (Admin with WARP)

```terraform
access_applications = {
  proxmox = {
    session_duration = "24h"
    policies = [
      {
        name     = "Allow Chris Managed Devices"
        decision = "allow"
        priority = 1
        include = {
          emails = ["chris@example.com"]
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
```

### Tier 2: Grafana (Flexible Access)

```terraform
access_applications = {
  grafana = {
    session_duration = "24h"
    policies = [
      {
        name     = "Allow Chris Any Device"
        decision = "allow"
        priority = 1
        include = {
          emails = ["chris@example.com"]
        }
        require = {
          countries = ["US"]
        }
      }
    ]
  }
}
```

### Mixed Tier: Grafana with Split Policies

Allow WARP-enrolled devices OR mobile devices from specific countries:

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
          emails = ["chris@example.com"]
        }
        require = {
          warp_enabled    = true
          device_enrolled = true
        }
      },
      {
        name     = "Allow Mobile Devices from US"
        decision = "allow"
        priority = 2
        include = {
          emails = ["chris@example.com"]
        }
        require = {
          countries = ["US"]
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
```

### Multiple Applications

```terraform
access_applications = {
  # Tier 1: Admin services
  proxmox = {
    session_duration = "24h"
    policies = [{
      name     = "Allow Managed Devices"
      decision = "allow"
      include = {
        emails = ["chris@example.com"]
      }
      require = {
        warp_enabled    = true
        device_enrolled = true
      }
    }]
  }

  argocd = {
    session_duration = "12h"
    policies = [{
      name     = "Allow Managed Devices"
      decision = "allow"
      include = {
        emails = ["chris@example.com"]
      }
      require = {
        warp_enabled    = true
        device_enrolled = true
      }
    }]
  }

  # Tier 2: Monitoring accessible from mobile
  grafana = {
    session_duration = "24h"
    policies = [{
      name     = "Allow Any Device"
      decision = "allow"
      include = {
        emails = ["chris@example.com"]
      }
      require = {
        countries = ["US"]
      }
    }]
  }
}
```

## Policy Components

### Include Rules

At least one `include` condition must match for the policy to apply:

```terraform
include = {
  emails    = ["user@example.com"]         # Email addresses
  groups    = ["group-id-123"]             # Access group IDs
  everyone  = true                         # Everyone (use for deny policies)
  ip_ranges = ["10.0.0.0/8"]              # IP CIDR ranges
  countries = ["US", "CA"]                 # Country codes (ISO 3166-1)
}
```

### Require Rules

All `require` conditions must match (AND logic):

```terraform
require = {
  warp_enabled        = true                # WARP client must be active
  device_enrolled     = true                # Device must be enrolled in org
  countries           = ["US"]              # Must be from these countries
  ip_ranges           = ["10.0.0.0/8"]     # Must be from these IP ranges
  certificate_present = true                # mTLS certificate required
}
```

### Exclude Rules

None of the `exclude` conditions can match:

```terraform
exclude = {
  emails    = ["blocked@example.com"]     # Block specific emails
  groups    = ["blocked-group-id"]        # Block specific groups
  countries = ["CN", "RU"]                # Block specific countries
  ip_ranges = ["192.0.2.0/24"]           # Block specific IP ranges
}
```

## Device Posture with WARP

### Setting Up WARP

1. **Create a Zero Trust Organization:**

   - Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
   - Settings → General → Create your organization name

2. **Enroll Your Device:**

   - Install WARP client: https://1.1.1.1/
   - Open WARP → Settings → Preferences → Account
   - Login with your organization name
   - Authenticate with your email

3. **Verify Enrollment:**
   - WARP should show "Connected"
   - Zero Trust Dashboard → My Team → Devices should list your device

### Device Posture Checks

Beyond WARP, you can add additional posture checks:

- **Operating System:** Require specific OS (macOS, Windows, Linux)
- **OS Version:** Minimum OS version
- **Disk Encryption:** Require FileVault/BitLocker
- **Firewall Enabled:** Require OS firewall active
- **Application Installed:** Require specific apps
- **Serial Number:** Whitelist specific devices
- **Domain Joined:** Require AD/AAD domain membership

Configure in: Zero Trust Dashboard → Settings → WARP Client → Device posture

## Security Best Practices

### 1. Always Have a Default Deny

Every Access application should end with a deny-all policy:

```terraform
{
  name     = "Default Deny"
  decision = "deny"
  priority = 100
  include = {
    everyone = true
  }
}
```

### 2. Use Priority Ordering

- **Priority 1-10:** Allow policies for specific users/conditions
- **Priority 11-50:** Additional allow policies
- **Priority 51-99:** Specific deny policies
- **Priority 100:** Default deny

### 3. Layer Defenses

Don't rely on Access alone:

- ✅ Strong application-level passwords
- ✅ Application-level MFA where available
- ✅ Cloudflare WAF rules
- ✅ Rate limiting on login endpoints
- ✅ Regular security audits

### 4. Session Duration

Choose appropriate session durations:

- **4-8h:** Highly sensitive services (Proxmox, K8s)
- **24h:** Standard admin services
- **168h (7d):** Low-risk services

### 5. Country Restrictions

Use country restrictions even with WARP:

```terraform
require = {
  warp_enabled = true
  countries    = ["US", "CA"]  # Your expected locations
}
```

This adds another layer if credentials are compromised.

## Testing Access Policies

### Test with Different Conditions

1. **Test without WARP:**

   - Disconnect WARP client
   - Try accessing the service
   - Should be denied if WARP is required

2. **Test from Different Countries:**

   - Use VPN to appear from different country
   - Should be denied if country restrictions apply

3. **Test with Incognito:**
   - Open incognito window
   - Should require full authentication flow

### View Access Logs

Monitor access attempts:

1. Go to Zero Trust Dashboard → Logs → Access
2. Filter by application name
3. Review:
   - Successful authentications
   - Denied attempts
   - Policy matches

## Troubleshooting

### "Access Denied" When I Should Have Access

1. **Check WARP Status:**

   ```bash
   # macOS/Linux
   warp-cli status

   # Should show: "Connected"
   ```

2. **Verify Email Matches:**

   - Email in policy must exactly match your IdP email
   - Check for typos

3. **Check Country Detection:**

   - Go to: https://www.cloudflare.com/cdn-cgi/trace
   - Look for `loc=` line (your country code)
   - Must match allowed countries

4. **Review Access Logs:**
   - Zero Trust Dashboard → Logs → Access
   - Find your attempt
   - Check which policy matched and why

### WARP Not Connecting

```bash
# Reset WARP
warp-cli disconnect
warp-cli connect

# Check registration
warp-cli registration show

# Re-register if needed
warp-cli registration delete
warp-cli registration new
```

### Device Not Showing in Dashboard

- Wait 5-10 minutes after enrollment
- Disconnect and reconnect WARP
- Check organization name is correct
- Verify email authentication succeeded

## Policy Decision Matrix

Reference table for choosing the right tier:

| Service Type         | Access? | WARP?    | Example                  |
| -------------------- | ------- | -------- | ------------------------ |
| Infrastructure Admin | ✅ Yes  | ✅ Yes   | Proxmox, ArgoCD, Rancher |
| Monitoring (Admin)   | ✅ Yes  | ✅ Yes   | Grafana, Prometheus      |
| Monitoring (View)    | ✅ Yes  | ❌ No    | Grafana (mobile)         |
| Development Tools    | ✅ Yes  | Optional | GitLab, Gitea            |
| Documentation        | ✅ Yes  | ❌ No    | Wiki, Docs               |
| Media (Personal)     | ❌ No   | ❌ No    | Jellyfin, Plex           |
| Media (Shared)       | ❌ No   | ❌ No    | Jellyfin for family      |
| IoT/Smart Home       | ❌ No   | ❌ No    | Home Assistant           |

## Next Steps

- [Cloudflare Overview](index.md) - Return to Cloudflare overview
- [cloudflared LXC](cloudflared-lxc.md) - Deploy the cloudflared connector
- [OpenTofu Modules](../opentofu/modules.md) - Learn about other Terraform modules
