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

| Resource | Value          |
| -------- | -------------- |
| CPU      | 4 cores        |
| Memory   | 24 GB          |
| Disk     | 32 GB          |
| IP       | 10.23.45.31/24 |

### Quick Start

#### 1. Set Up Proxmox API Token

Create the terraform user and generate an API token (in Proxmox shell):

```bash
# Create the terraform user
pveum user add terraform@pve

# Create a custom role with required permissions
pveum role add Terraform -privs "Datastore.AllocateSpace Datastore.Audit Datastore.AllocateTemplate Pool.Allocate SDN.Use Sys.Audit Sys.Console Sys.Modify Sys.PowerMgmt VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.PowerMgmt"

# Assign the role to the terraform user
pveum aclmod / -user terraform@pve -role Terraform

# Generate the API token
pveum user token add terraform@pve terraform -privsep 0
```

**Or regenerate if the token already exists:**

```bash
# Remove the old token
pveum user token remove terraform@pve terraform

# Create a new one
pveum user token add terraform@pve terraform -privsep 0
```

Copy the token output and export it:

```bash
export TF_VAR_pm_api_token_secret="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

#### 2. Deploy Infrastructure

```bash
cd terraform/envs/k3s-single

# Initialize
tofu init

# Plan (review changes)
tofu plan

# Apply
tofu apply
```

### Required Variables

Only one environment variable is required:

```bash
export TF_VAR_pm_api_token_secret="your-token-secret"
```

All other values have sensible defaults:

- **Template**: `alma9.6-k3s-v1.31.3-k3s1-202512061542` (latest from Packer)
- **VM IP**: `10.23.45.31/24` (Proxmox will error if already in use)
- **Resources**: 4 cores, 24GB RAM, 32GB disk
- **Storage**: VM disks on `vmdata`, cloned from template on `local-lvm`

**SSH keys are generated automatically** and saved to `~/.ssh/{vm-name}` and `~/.ssh/{vm-name}.pub`

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

| Output                 | Description                       |
| ---------------------- | --------------------------------- |
| `vm_id`                | Proxmox VM ID                     |
| `vm_name`              | VM hostname                       |
| `vm_ip`                | VM IP address                     |
| `vm_node`              | Proxmox node hosting the VM       |
| `ssh_private_key_path` | Path to generated SSH private key |
| `ssh_public_key_path`  | Path to generated SSH public key  |
| `ssh_command`          | SSH connection command (with key) |
| `kubeconfig_command`   | Command to fetch kubeconfig       |
| `kubectl_context`      | Setup instructions for kubectl    |

## Destroying Infrastructure

```bash
cd terraform/envs/k3s-single
tofu destroy
```

## Troubleshooting

### Template Not Found Error

**Problem**: `Error: no guest with name 'template-name' found`

**Root Cause**: The telmate/proxmox provider v3.x requires using the template's VM ID (integer) rather than the template name (string).

**Solution**:

1. Find the template VM ID in Proxmox:

   ```bash
   qm list | grep template-name
   ```

2. Use the VM ID in your Terraform variable:

   ```hcl
   variable "template_name" {
     type    = number
     default = 100  # Use the actual VM ID
   }
   ```

3. In the module, use `clone_id` instead of `clone`:
   ```hcl
   resource "proxmox_vm_qemu" "vm" {
     clone_id   = var.template_name  # Integer VM ID
     full_clone = true
     # ...
   }
   ```

**Get template ID from Packer manifest:**

```bash
cat packer/alma9-k3s-optimized/manifest.json | jq -r '.builds[-1].artifact_id'
```

### Insufficient Permissions Error

**Problem**: `permissions for user/token are not sufficient` or `VM.Monitor permission missing`

**Solution**: Grant the terraform user Administrator role on required resources:

```bash
# Root level (VM operations)
pveum aclmod / -user terraform@pve -role Administrator

# Storage where templates are stored
pveum aclmod /storage/local-lvm -user terraform@pve -role Administrator

# Storage where VMs will be created
pveum aclmod /storage/vmdata -user terraform@pve -role Administrator
```

**Verify API token has privilege separation disabled:**

```bash
pveum user token list terraform@pve
```

If privilege separation is enabled (1), recreate the token:

```bash
pveum user token remove terraform@pve terraform
pveum user token add terraform@pve terraform -privsep 0
```

### Provider Version Compatibility

**Problem**: Deprecated arguments or unsupported syntax

**Solution**: Use telmate/proxmox v3.0.2-rc6 or later with the correct syntax:

- Use `clone_id` (integer) instead of `clone` (string) for templates
- Use `onboot` (not `start_at_node_boot`)
- Use `cpu` block with `type` (not `cpu_type`)
- Use `disk` with `slot = "scsi0"` and `type = "disk"`
- Use `network` with `id = 0`

**Enable debug logging** to troubleshoot provider issues:

```hcl
provider "proxmox" {
  pm_api_url      = "https://10.23.45.10:8006/api2/json"
  pm_api_token_id = "terraform@pve!terraform"
  pm_tls_insecure = true

  # Debug logging
  pm_log_enable = true
  pm_log_file   = "terraform-plugin-proxmox.log"
  pm_log_levels = {
    _default    = "debug"
    _capturelog = ""
  }
}
```

## State Management

!!! warning "State Security"
Terraform state may contain sensitive values. Consider using: - Remote state (S3, Consul) with encryption - State locking with DynamoDB or similar - Access controls on state storage

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

| Resource | Value         |
| -------- | ------------- |
| Type     | LXC Container |
| CPU      | 1 core        |
| Memory   | 512 MB        |
| Disk     | 4 GB          |

This environment also configures:

- Cloudflare Tunnel
- DNS records for proxied services

For detailed instructions, see [cloudflared LXC](../cloudflare/cloudflared-lxc.md).

## Next Steps

- [Modules](modules.md) - Understand the proxmox-vm module
- [Cloudflare](../cloudflare/index.md) - Cloudflare tunnel integration
- [Overview](index.md) - Return to OpenTofu overview
