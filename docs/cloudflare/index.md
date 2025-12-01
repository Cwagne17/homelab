---
icon: material/cloud
---

# Cloudflare Integration

Cloudflare provides secure external access to homelab services through Cloudflare Tunnels.

## Overview

Cloudflare Tunnels create a secure, outbound-only connection from your infrastructure to Cloudflare's edge network, eliminating the need to:

- Open inbound ports on your firewall
- Expose your home IP address
- Manage SSL certificates manually

```mermaid
graph LR
    subgraph Homelab["Homelab Network"]
        CF[cloudflared LXC]
        PVE[Proxmox]
        Services[Other Services]
    end

    subgraph Cloudflare["Cloudflare Edge"]
        Tunnel[Tunnel Endpoint]
        DNS[DNS Records]
    end

    Internet[Internet Users]

    CF -->|Outbound Connection| Tunnel
    Tunnel --> DNS
    Internet -->|HTTPS| DNS
    CF -->|Internal| PVE
    CF -->|Internal| Services

    style Homelab fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    style Cloudflare fill:#fff3e0,stroke:#e65100,stroke-width:2px
```

## Components

### cloudflared LXC

A lightweight LXC container running the `cloudflared` daemon that:

- Establishes persistent tunnel connections to Cloudflare
- Routes incoming requests to internal services
- Handles TLS termination and authentication

### Terraform Environment

The `terraform/envs/cloudflared_lxc/` environment automates:

- Provisioning the LXC container on Proxmox
- Creating Cloudflare tunnel and DNS records
- Generating configuration files

## Benefits

!!! success "Security"
    - No exposed ports or public IP
    - Built-in DDoS protection
    - Zero Trust access control (optional)

!!! success "Simplicity"
    - Automatic SSL certificates
    - Single point of configuration
    - Infrastructure as Code

!!! success "Performance"
    - Global edge network
    - Automatic routing optimization
    - Built-in caching

## Next Steps

- [cloudflared LXC](cloudflared-lxc.md) - Deploy the cloudflared LXC container
