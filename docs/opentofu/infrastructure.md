# Infrastructure Deployment

This guide covers deploying Talos Kubernetes clusters on Proxmox using OpenTofu.

## Why OpenTofu?

OpenTofu enables:

- **Declarative Infrastructure**: Define what you want, not how to build it
- **State Management**: Track infrastructure changes in S3
- **Idempotent Operations**: Safe to run repeatedly
- **Plan Before Apply**: Preview changes before making them

## Environments

The `terraform/envs/` directory contains environment-specific configurations:

```
terraform/envs/
├── talos_cluster/        # Talos Kubernetes cluster
│   ├── main.tf           # Module invocation
│   ├── providers.tf      # Provider configuration with S3 backend
│   ├── outputs.tf        # Kubeconfig and talosconfig outputs
│   └── terraform.auto.tfvars  # Proxmox API credentials
└── cloudflare_ztna/      # Cloudflare ZTNA environment
    ├── main.tf           # Cloudflare Tunnel, DNS, Access
    └── providers.tf      # Cloudflare provider
```

## Talos Cluster Environment

Deploys a multi-node Talos Kubernetes cluster:

### Cluster Specifications

| Node     | Role          | vCPU | RAM  | Disk  | IP          |
| -------- | ------------- | ---- | ---- | ----- | ----------- |
| k8s-cp00 | Control Plane | 2    | 4 GB | 20 GB | 10.23.45.30 |
| k8s-wk00 | Worker        | 4    | 8 GB | 50 GB | 10.23.45.31 |

### Quick Start

#### 1. Set Up Proxmox API Token

Create the terraform user and generate an API token:

```bash
# Create the terraform user
pveum user add terraform@pve

# Create a custom role with required permissions
pveum role add Terraform -privs "Datastore.AllocateSpace Datastore.Audit Pool.Allocate Sys.Audit Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.PowerMgmt"

# Assign the role to the terraform user
pveum aclmod / -user terraform@pve -role Terraform

# Generate the API token
pveum user token add terraform@pve terraform -privsep 0
```

**Configure SSH Access:**

The Proxmox provider requires SSH access for image downloads:

```bash
# Generate SSH key if needed
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_proxmox

# Copy to Proxmox
ssh-copy-id -i ~/.ssh/id_rsa_proxmox root@10.23.45.10

# Load key in ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa_proxmox
```

#### 2. Configure Credentials

Create API token file:

```bash
cat > terraform/envs/talos_cluster/terraform.auto.tfvars <<EOF
proxmox_api_token = "root@pam!terraform=your-token-here"
EOF
```

#### 3. Deploy Cluster

```bash
cd terraform/envs/talos_cluster

# Initialize (sets up S3 backend)
tofu init

# Plan (review changes)
tofu plan

# Apply (deploy cluster)
tofu apply
```

Or use the Makefile:

```bash
make tf-apply ENV=talos_cluster
```

### Deployment Process

The deployment takes approximately 10-15 minutes:

1. **Initialize Backend** (~30s): Configure S3 state storage
2. **Download Talos Image** (~2-3 min): Fetch from Talos Image Factory
3. **Create VMs** (~1 min): Provision control plane and worker
4. **Apply Machine Configs** (~5-7 min): Configure Talos on each node
5. **Bootstrap Cluster** (~2-3 min): Initialize Kubernetes
6. **Health Check** (~1 min): Verify cluster is ready

### Required Configuration

**Environment Variables:**

- `proxmox_api_token`: Set in `terraform.auto.tfvars`
- `AWS_PROFILE`: Set to `chris-personal-mgmt` for S3 backend

**SSH Agent:**

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa_proxmox
```

### Fetching Kubeconfig

After successful deployment:

```bash
# Export kubeconfig to ~/.kube/config
make k8s-kubeconfig

# Or manually export
export KUBECONFIG=$PWD/output/kubeconfig

# Verify cluster
kubectl get nodes
```

Expected output:

```
NAME       STATUS   ROLES           AGE   VERSION
k8s-cp00   Ready    control-plane   5m    v1.34.0
k8s-wk00   Ready    <none>          5m    v1.34.0
```

### Outputs

After `tofu apply`, these outputs are available:

| Output              | Description                  |
| ------------------- | ---------------------------- |
| `talosconfig`       | Talos client configuration   |
| `kubeconfig`        | Kubernetes cluster access    |
| `control_plane_ips` | Control plane node addresses |
| `worker_ips`        | Worker node addresses        |
| `cluster_endpoint`  | Kubernetes API endpoint      |

Files are written to `output/` directory with 0600 permissions.

### State Management

The cluster state is stored remotely:

- **Backend**: AWS S3
- **Bucket**: `homelab-terraform-state-678730054304`
- **Key**: `talos-cluster/terraform.tfstate`
- **Lock Table**: `homelab-terraform-locks` (DynamoDB)
- **Encryption**: Enabled (AES-256)
- **Versioning**: Enabled

State is automatically backed up on every change.

## Destroying Infrastructure

```bash
cd terraform/envs/talos_cluster
tofu destroy
```

Or:

```bash
make tf-destroy ENV=talos_cluster
```

## Troubleshooting

### SSH Connection Fails

**Problem**: `Failed to connect via SSH`

**Solutions:**

1. Verify SSH key is loaded:

   ```bash
   ssh-add -l
   ```

2. Test SSH access:

   ```bash
   ssh root@10.23.45.10
   ```

3. Ensure key is in authorized_keys:
   ```bash
   ssh-copy-id root@10.23.45.10
   ```

### Talos Image Download Fails

**Problem**: `Error downloading image from factory.talos.dev`

**Solutions:**

1. Check network connectivity from Proxmox
2. Verify DNS resolution
3. Check available storage space
4. Review OpenTofu logs for specific error

### Machine Config Apply Hangs

**Problem**: Configuration apply times out

**Solutions:**

1. Verify VMs are running in Proxmox
2. Check network connectivity to VM IPs
3. Review Talos logs:
   ```bash
   talosctl -n 10.23.45.30 logs
   ```

### Bootstrap Fails

**Problem**: Cluster bootstrap timeout

**Solutions:**

1. Verify control plane config was applied
2. Check etcd health:
   ```bash
   talosctl -n 10.23.45.30 service etcd status
   ```
3. Review control plane logs:
   ```bash
   talosctl -n 10.23.45.30 logs kube-apiserver
   ```

### State Lock Error

**Problem**: `Error acquiring the state lock`

**Solutions:**

1. Check if another OpenTofu process is running
2. View DynamoDB lock table in AWS console
3. Force unlock (use with caution):
   ```bash
   tofu force-unlock <LOCK_ID>
   ```

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

### VM Stuck at "Booting from hard disk"

**Problem**: VM boots but hangs at "Booting from hard disk" message and never reaches login prompt.

**Root Cause**: The Packer template uses OVMF (EFI) firmware, but when Terraform clones the VM, the provider defaults to SeaBIOS (legacy BIOS). This causes a boot configuration mismatch.

**Symptoms**:

- VM config shows `bios: seabios` instead of `bios: ovmf`
- EFI disk is present but system tries to boot with legacy BIOS
- Boot hangs indefinitely at "Booting from hard disk"

**Solution**: Explicitly configure OVMF/EFI in the Terraform module:

```hcl
resource "proxmox_vm_qemu" "vm" {
  # ... other config ...

  # BIOS/Firmware Configuration
  bios    = "ovmf"
  machine = "q35"

  # EFI disk (required for OVMF BIOS)
  efidisk {
    storage           = "local-lvm"
    efitype           = "4m"
    pre_enrolled_keys = false
  }

  # ... rest of config ...
}
```

**Verification**: Check the VM configuration in Proxmox:

```bash
qm config <vmid> | grep -E '(bios|efidisk|machine)'
```

Should show:

```
bios: ovmf
efidisk0: local-lvm:vm-<id>-disk-X,efitype=4m,pre-enrolled-keys=0,size=4M
machine: q35
```

### Cloud-init Not Running

**Problem**: VM boots but retains default Packer hostname, root password unchanged, network configuration not applied.

**Symptoms**:

- Login prompt shows "packer-alma9 login:" instead of Terraform-configured hostname
- Proxmox Cloud-Init tab shows "no cloud init drive found"
- SSH key not installed, IP address not configured
- `qm config <vmid>` shows no `ide2` or `ide0` cloud-init drive

**Root Cause**: The cloud-init CD-ROM drive (typically IDE2) is not being created when cloning the template. Even though cloud-init parameters (ciuser, ipconfig0, sshkeys) are set in Terraform, without the drive, they cannot be applied to the VM.

**Solution**: Explicitly add the cloud-init drive in the Terraform module:

```hcl
resource "proxmox_vm_qemu" "vm" {
  # ... other config ...

  # Cloud-init drive (IDE2 or IDE0)
  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = "local-lvm"
  }

  # Cloud-init Configuration
  os_type    = "cloud-init"
  ciuser     = var.ci_user
  sshkeys    = var.ssh_pubkey
  ipconfig0  = "ip=${var.ip},gw=${var.gateway}"
  nameserver = var.nameserver

  # ... rest of config ...
}
```

**Verification**: Check the VM configuration in Proxmox:

```bash
qm config <vmid> | grep -E '(ide|ciuser|ipconfig)'
```

Should show:

```
ciuser: admin
ide2: local-lvm:vm-<id>-cloudinit,media=cdrom
ipconfig0: ip=10.23.45.31/24,gw=10.23.45.1
```

**Check cloud-init status inside the VM**:

```bash
# From Proxmox console or SSH
cloud-init status
journalctl -u cloud-init
```

## State Management!!! warning "State Security"

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

## cloudflare_ztna Environment

Configures Cloudflare Zero Trust resources (Cloudflare Tunnel, DNS records, and Access application/policy definitions). This environment does not provision an LXC/container or install the `cloudflared` connector; create that connector separately (for example with the Proxmox community script) and point it at the tunnel credentials managed by this environment.

This environment configures:

- Cloudflare Tunnel
- DNS records for proxied services
- Access applications and policies (optional)

For connector installation and container guidance, see [cloudflared LXC](../cloudflare/cloudflared-lxc.md).

## Next Steps

- [Modules](modules.md) - Understand the proxmox-vm module
- [Cloudflare](../cloudflare/index.md) - Cloudflare tunnel integration
- [Overview](index.md) - Return to OpenTofu overview
