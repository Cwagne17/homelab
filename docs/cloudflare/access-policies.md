---
icon: material/shield-lock
---

# Cloudflare Access Policies

Cloudflare Access provides Zero Trust Network Access (ZTNA) with identity-based authentication and device posture checks. This guide covers implementing tiered access policies for different security levels.

## Policy Architecture

The ZTNA module supports three security tiers:

### Tier 1: Super Strict (Admin-Only, GitHub Login Required)

**Use for:**

- Proxmox
- Kubernetes dashboards (ArgoCD, Rancher)
- Monitoring (Grafana, Loki, Prometheus)
- Any service with "root of your homelab" power

**Requirements:**

- ✅ Identity verification (email)
- ✅ Login via GitHub (or other configured IdP)
- ✅ Optional: Country restriction, IP range restriction

**Result:** Even if someone steals the URL, they need your email and GitHub login access.

### Tier 2: Strong But Usable (Phones, Tablets)

**Use for:**

- Services you might access from mobile devices
- Grafana (if you want mobile access)
- Home Assistant
- Personal documentation

**Requirements:**

- ✅ Identity verification (email)
- ✅ Country or IP range restriction
- ✅ Works on any device with browser

**Result:** Still requires authentication, accessible from any device.

### Tier 3: Consumer Apps (TVs, Streaming)

**Use for:**

- Jellyfin (media streaming)
- Plex
- Services accessed by TVs or devices that can't do SSO

**Protection:**

- ❌ No Cloudflare Access (TVs can't do SSO)
- ✅ Application-level authentication (Jellyfin users)
- ✅ Cloudflare WAF rules
- ✅ Rate limiting
- ✅ Country-based blocking

## Configuration Examples

### Tier 1: Proxmox (Admin with GitHub)

```terraform
access_applications = {
  proxmox = {
    session_duration = "24h"
    policy_name      = "Allow Chris via GitHub"
    include = {
      emails = ["chris@example.com"]
    }
    require = {
      login_methods = ["github"]
      countries     = ["US"]
    }
  }
}
```

### Tier 2: Grafana (Flexible Access)

```terraform
access_applications = {
  grafana = {
    session_duration = "24h"
    policy_name      = "Allow Chris Any Device"
    include = {
      emails = ["chris@example.com"]
    }
    require = {
      countries = ["US"]
    }
  }
}
```

### Multiple Applications

```terraform
access_applications = {
  # Tier 1: Admin services with GitHub login
  proxmox = {
    session_duration = "24h"
    policy_name      = "Allow via GitHub"
    include = {
      emails = ["chris@example.com"]
    }
    require = {
      login_methods = ["github"]
      countries     = ["US"]
    }
  }

  argocd = {
    session_duration = "12h"
    policy_name      = "Allow via GitHub"
    include = {
      emails = ["chris@example.com"]
    }
    require = {
      login_methods = ["github"]
    }
  }

  # Tier 2: Monitoring accessible from any device
  grafana = {
    session_duration = "24h"
    policy_name      = "Allow Any Device"
    include = {
      emails = ["chris@example.com"]
    }
    require = {
      countries = ["US"]
    }
  }
}
```

## Policy Components

### Include Rules

At least one `include` condition must match for the policy to apply:

```terraform
include = {
  emails = ["user@example.com"]  # Email addresses (required)
}
```

### Require Rules

All `require` conditions must match (AND logic):

```terraform
require = {
  login_methods = ["github"]         # Login via GitHub (or other IdP)
  countries     = ["US"]             # Must be from these countries
  ip_ranges     = ["10.0.0.0/8"]    # Must be from these IP ranges
}
```

### Exclude Rules

None of the `exclude` conditions can match:

```terraform
exclude = {
  emails    = ["blocked@example.com"]  # Block specific emails
  countries = ["CN", "RU"]             # Block specific countries
  ip_ranges = ["192.0.2.0/24"]        # Block specific IP ranges
}
```

## Login Methods Setup

### Configuring GitHub as Identity Provider

1. **Create a Zero Trust Organization:**

   - Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
   - Settings → General → Create your organization name

2. **Add GitHub as Identity Provider:**

   - Settings → Authentication → Login methods
   - Click "Add new" → Select "GitHub"
   - Follow the OAuth setup instructions
   - Configure authorized domains and user groups as needed

3. **Test Authentication:**
   - Try accessing a protected service
   - Should redirect to GitHub for authentication
   - After GitHub login, should be granted access based on policies

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

Use country restrictions with login methods:

```terraform
require = {
  login_methods = ["github"]
  countries     = ["US", "CA"]  # Your expected locations
}
```

This adds another layer if credentials are compromised.

## Testing Access Policies

### Test with Different Conditions

1. **Test without Authentication:**

   - Open incognito window
   - Try accessing the service
   - Should redirect to GitHub login

2. **Test from Different Countries:**

   - Use VPN to appear from different country
   - Should be denied if country restrictions apply

3. **Test with Different Email:**
   - Use different GitHub account
   - Should be denied if email not in allowed list

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

1. **Verify Email Matches:**

   - Email in policy must exactly match your GitHub email
   - Check for typos in the policy configuration

2. **Check GitHub Authentication:**

   - Ensure you're logged into the correct GitHub account
   - Verify the GitHub OAuth app is authorized
   - Check that your GitHub email is verified

3. **Check Country Detection:**

   - Go to: https://www.cloudflare.com/cdn-cgi/trace
   - Look for `loc=` line (your country code)
   - Must match allowed countries

4. **Review Access Logs:**
   - Zero Trust Dashboard → Logs → Access
   - Find your attempt
   - Check which policy matched and why

### GitHub Login Not Working

- Verify GitHub is configured as identity provider in Cloudflare
- Check OAuth app settings in GitHub
- Ensure redirect URLs are correctly configured
- Try re-authorizing the OAuth app

## Policy Decision Matrix

Reference table for choosing the right tier:

| Service Type         | Access? | GitHub Login? | Example                  |
| -------------------- | ------- | ------------- | ------------------------ |
| Infrastructure Admin | ✅ Yes  | ✅ Yes        | Proxmox, ArgoCD, Rancher |
| Monitoring (Admin)   | ✅ Yes  | ✅ Yes        | Grafana, Prometheus      |
| Monitoring (View)    | ✅ Yes  | ❌ No         | Grafana (mobile)         |
| Development Tools    | ✅ Yes  | Optional      | GitLab, Gitea            |
| Documentation        | ✅ Yes  | ❌ No         | Wiki, Docs               |
| Media (Personal)     | ❌ No   | ❌ No         | Jellyfin, Plex           |
| Media (Shared)       | ❌ No   | ❌ No         | Jellyfin for family      |
| IoT/Smart Home       | ❌ No   | ❌ No         | Home Assistant           |

## Next Steps

- [Cloudflare Overview](index.md) - Return to Cloudflare overview
- [cloudflared LXC](cloudflared-lxc.md) - Deploy the cloudflared connector
- [OpenTofu Modules](../opentofu/modules.md) - Learn about other Terraform modules
