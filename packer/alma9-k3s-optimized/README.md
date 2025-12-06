# Building AlmaLinux 9 k3s-Optimized Image

Quick reference for building the k3s-optimized golden image.

## Prerequisites

1. **Packer installed** (>= 1.9.0)
2. **Network access** to Proxmox from internal network
3. **API token** for authentication

### Network Requirements

⚠️ **IMPORTANT**: Packer builds must be run from inside your network and connect directly to the Proxmox server's internal IP address (`https://10.23.45.10:8006`).

The public endpoint (`https://proxmox.chriswagner.dev`) is protected by Cloudflare Access with security policies (GitHub login, country restrictions) that will block API token authentication. Packer cannot authenticate through these access controls.

**Options for running builds:**

- From a machine on the same network as Proxmox
- Via VPN connection to your homelab network
- From a bastion/jump host inside the network

## Quick Build

### 1. Initialize Packer

```bash
cd packer/alma9-k3s-optimized
packer init .
```

### 2. Set API Token

```bash
export PKR_VAR_proxmox_token="your-proxmox-api-token-here"
```

Or create a token:

```bash
# In Proxmox shell
pveum user token add packer@pve packer -privsep 0
```

### 3. Validate Configuration

```bash
packer validate .
```

### 4. Build Image

```bash
packer build .
```

## Configuration

The build is configured via `variables.auto.pkrvars.hcl`:

- **Proxmox endpoint**: `https://proxmox.chriswagner.dev/api2/json`
- **k3s version**: `v1.31.3+k3s1`
- **Image name**: `alma9-k3-node-amd64-v1.31.3-v1`
- **VM ID**: `9000` (ensure this is available)

## Build Process

1. Downloads AlmaLinux 9.5 minimal ISO
2. Creates temporary VM (ID 9000) with UEFI
3. Boots from ISO with kickstart automation
4. Provisions:
   - OS updates
   - QEMU guest agent
   - k3s server installation (from stable channel)
   - ArgoCD auto-deploy manifest (installed via k3s on first boot)
   - Cleanup for templating
5. Converts to Proxmox template

## What's Included

- **k3s**: Installed from stable channel with secrets encryption enabled
- **ArgoCD**: HelmChart manifest at `/var/lib/rancher/k3s/server/manifests/argocd.yaml`
  - Automatically deployed when k3s starts
  - No manual installation required
- **QEMU Guest Agent**: For Proxmox integration

## Output

- **Template**: Available in Proxmox as `alma9-k3-node-amd64-v1.31.3-v1`
- **Manifest**: `manifest.json` with build metadata

## Customization

### Change k3s Version

Edit `variables.auto.pkrvars.hcl`:

```hcl
k3s_version   = "v1.30.0+k3s1"
image_version = "alma9-k3-node-amd64-v1.30.0-v1"
```

### Use Local ISO

For faster builds, upload ISO to Proxmox first:

```hcl
alma_iso_url = "local:iso/AlmaLinux-9.5-x86_64-minimal.iso"
```

### Adjust VM Resources

```hcl
vm_cores  = 4
vm_memory = 8192
```

## Troubleshooting

### Check AlmaLinux ISO Checksum

Before building, verify the ISO checksum:

```bash
curl -sL https://repo.almalinux.org/almalinux/9.5/isos/x86_64/CHECKSUM | grep minimal
```

Update `alma_iso_checksum` in `variables.auto.pkrvars.hcl` if needed.

### Build Fails to Connect

- Verify Proxmox is accessible: `curl -k https://proxmox.chriswagner.dev:8006`
- Check API token has sufficient permissions
- Ensure VM ID 9000 is not in use

### Kickstart Timeout

- Check Proxmox console for boot errors
- Verify HTTP server is reachable from Proxmox network
- Increase `ssh_timeout` in variables file

## Next Steps

After building, use the template with Terraform:

```bash
cd terraform/envs/k3s-single
terraform apply
```

See: `docs/packer/` for detailed documentation.
