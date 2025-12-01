# Infrastructure Deployment

This guide covers deploying Proxmox VMs and LXC containers using OpenTofu/Terraform.

## Why OpenTofu?

OpenTofu (or Terraform) enables:

- **Declarative Infrastructure**: Define what you want, not how to build it
- **State Management**: Track and manage infrastructure changes
- **Idempotent Operations**: Safe to run repeatedly
- **Plan Before Apply**: Preview changes before making them

## Environments

The `terraform/envs/` directory contains environment-specific configurations:

```
terraform/envs/
├── k3s-single/           # Single-node k3s cluster
│   ├── main.tf           # Module invocation and provider
│   ├── variables.tf      # Input variables
│   ├── outputs.tf        # Output values
│   └── terraform.tfvars.example
└── cloudflared_lxc/      # Cloudflare tunnel LXC container
    ├── main.tf           # Main configuration
    ├── providers.tf      # Proxmox and Cloudflare providers
    ├── variables.tf      # Input variables
    ├── outputs.tf        # Output values
    ├── lxc.tf            # Proxmox LXC resource
    ├── cloudflare.tf     # Cloudflare tunnel and DNS
    ├── locals.tf         # Computed values
    ├── config.yaml       # cloudflared config template
    └── terraform.tfvars.example
```

## k3s-single Environment

Deploys a single-node k3s cluster with these specs:

| Resource | Value |
|----------|-------|
| CPU | 4 cores |
| Memory | 24 GB |
| Disk | 32 GB |
| IP | 10.23.45.31/24 |

### Quick Start

```bash
cd terraform/envs/k3s-single

# Initialize
tofu init

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Plan
tofu plan -var-file=../../globals.tfvars

# Apply
tofu apply -var-file=../../globals.tfvars
```

### Using Environment Variables

You can set Proxmox credentials via environment variables:

```bash
export PM_API_URL="https://10.23.45.10:8006/api2/json"
export PM_API_TOKEN_ID="root@pam!terraform"
export PM_API_TOKEN_SECRET="your-token-secret"

tofu apply -var-file=../../globals.tfvars
```

### Changing the Image Version

To use a different golden image:

```bash
tofu apply \
  -var-file=../../globals.tfvars \
  -var="template_name=alma9-k3-node-amd64-v1.29.0-v1"
```

### Fetching Kubeconfig

After deployment, get the kubeconfig:

```bash
# Option 1: From Terraform output
tofu output -raw kubeconfig_command | bash > ~/.kube/k3s-s1.yaml

# Option 2: Direct SSH
ssh admin@10.23.45.31 'sudo cat /etc/rancher/k3s/k3s.yaml' | \
  sed 's/127.0.0.1/10.23.45.31/g' > ~/.kube/k3s-s1.yaml

# Use the kubeconfig
export KUBECONFIG=~/.kube/k3s-s1.yaml
kubectl get nodes
```

### Outputs

After `tofu apply`, these outputs are available:

| Output | Description |
|--------|-------------|
| `vm_id` | Proxmox VM ID |
| `vm_ip` | VM IP address |
| `ssh_command` | SSH connection command |
| `kubeconfig_command` | Command to fetch kubeconfig |
| `kubectl_context` | Setup instructions for kubectl |

## Destroying Infrastructure

```bash
cd terraform/envs/k3s-single
tofu destroy -var-file=../../globals.tfvars
```

## State Management

!!! warning "State Security"
    Terraform state may contain sensitive values. Consider using:
    - Remote state (S3, Consul) with encryption
    - State locking with DynamoDB or similar
    - Access controls on state storage

### Example Remote Backend

Uncomment and configure in `main.tf`:

```hcl
backend "s3" {
  bucket         = "homelab-terraform-state"
  key            = "k3s-single/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-lock"
}
```

## cloudflared_lxc Environment

Deploys a cloudflared LXC container with Cloudflare tunnel integration.

| Resource | Value |
|----------|-------|
| Type | LXC Container |
| CPU | 1 core |
| Memory | 512 MB |
| Disk | 4 GB |

This environment also configures:

- Cloudflare Tunnel
- DNS records for proxied services

For detailed instructions, see [cloudflared LXC](../cloudflare/cloudflared-lxc.md).

## Next Steps

- [Modules](modules.md) - Understand the proxmox-vm module
- [Cloudflare](../cloudflare/index.md) - Cloudflare tunnel integration
- [Overview](index.md) - Return to OpenTofu overview
