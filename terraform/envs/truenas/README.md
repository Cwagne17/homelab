# TrueNAS SCALE VM Environment

This Terraform environment provisions a TrueNAS SCALE virtual machine on Proxmox VE with hardware disk passthrough for a production NAS/storage server.

## Architecture Overview

This configuration creates a TrueNAS SCALE VM with:

- **UEFI boot** with Secure Boot support (OVMF BIOS, Q35 machine type)
- **8GB RAM** and **2 CPU cores** (host CPU passthrough for optimal performance)
- **32GB OS disk** on fast storage (vmdata) with iothread enabled
- **Two 6TB WD drives** passed through directly to the VM for ZFS pool
- **VirtIO networking** with dedicated MAC address for stable network identity

The VM is configured to boot from the TrueNAS installation ISO on first boot, allowing you to install TrueNAS SCALE and configure your storage pool.

## Prerequisites

Before applying this configuration, ensure:

1. **TrueNAS ISO uploaded**: The TrueNAS SCALE 25.10.1 ISO must be uploaded to the `local-120` storage on your Proxmox node
   - Download from: https://www.truenas.com/download-truenas-scale/
   - Upload via Proxmox web UI: Datacenter → Storage → local-120 → ISO Images → Upload

2. **Physical disks available**: Two WD 6TB drives must be present and accessible at:
   - `/dev/disk/by-id/ata-WDC_WD60EFPX-68C5ZN0_WD-WX22DA5CFRHD`
   - `/dev/disk/by-id/ata-WDC_WD60EFPX-68C5ZN0_WD-WX22DA54007K`
   
   **⚠️ WARNING**: These disks will be owned exclusively by the VM. All existing data will be managed by TrueNAS and should not be accessed directly by the Proxmox host.

3. **Network**: Bridge `vmbr0` must be configured on the Proxmox node

4. **Storage**: The `vmdata` datastore must have at least 32GB free space for the OS disk

## Environment Variables

The Proxmox provider requires authentication via environment variables. Set these before running Terraform commands:

```bash
# Required variables
export PROXMOX_VE_ENDPOINT="https://consul.tplinkdns.com:8006/api2/json"
export PROXMOX_VE_USERNAME="your-username@pam!your-token-id"
export PROXMOX_VE_TOKEN="your-token-secret"

# Optional: Skip TLS verification (for self-signed certificates)
export PROXMOX_VE_INSECURE=true
```

### Creating a Proxmox API Token

If you don't have an API token yet:

1. Log in to Proxmox web UI
2. Navigate to: Datacenter → Permissions → API Tokens
3. Click "Add" and create a token for your user
4. Copy the token ID and secret (you won't be able to see the secret again!)
5. Ensure the token has necessary permissions (typically `PVEVMAdmin` role)

## Usage

### Initial Setup

```bash
# Navigate to this environment
cd terraform/envs/truenas

# Initialize Terraform (download providers)
tofu init

# Copy the example configuration and customize if needed
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars to verify/adjust values
# At minimum, verify the node name and disk paths
nano terraform.tfvars

# Review the planned changes
tofu plan

# Apply the configuration to create the VM
tofu apply
```

### Post-Installation Steps

After Terraform creates the VM:

1. **Install TrueNAS SCALE**:
   - Access the VM console via Proxmox web UI (VM → Console)
   - The VM will boot from the TrueNAS ISO automatically
   - Follow the TrueNAS installation wizard
   - Install to the 32GB SCSI0 disk (will show as first disk)
   - Complete installation and reboot

2. **Change Boot Order** (Important!):
   - After TrueNAS is installed, change boot order to boot from disk instead of CD-ROM
   - **Option A - Via Proxmox Web UI**:
     - VM → Hardware → Select CD/DVD Drive (ide2) → Edit → Set to "Do not use any media"
     - Or remove the CD-ROM drive entirely
     - The `ignore_changes = [cdrom]` lifecycle rule prevents Terraform from reverting this change
   
   - **Option B - Via Proxmox CLI**:
     ```bash
     qm set 900 --boot order=scsi0;net0
     ```

3. **Initial TrueNAS Configuration**:
   - Access TrueNAS web UI at the IP assigned by DHCP (check your router/DHCP server)
   - The VM uses MAC address `02:23:45:21:9a:7c` - you can create a DHCP reservation
   - Complete the setup wizard
   - Configure your admin password and network settings

4. **Create ZFS Pool**:
   - In TrueNAS UI, go to Storage → Pools → Add
   - Select the two 6TB WD drives
   - Create a mirror vdev (recommended for redundancy) or stripe (for capacity)
   - Name your pool (e.g., "tank")
   - Configure datasets and shares as needed

## Configuration Variables

All variables are defined in `variables.tf` with sensible defaults. The most common ones to customize:

| Variable | Default | Description |
|----------|---------|-------------|
| `node` | (required) | Proxmox node name (e.g., "pve") |
| `vmid` | `900` | VM ID in Proxmox |
| `vm_name` | `truenas.home.arpa` | VM hostname |
| `memory_mb` | `8192` | RAM in megabytes |
| `cores` | `2` | CPU cores |
| `passthrough_disk1_by_id` | (required) | Path to first passthrough disk |
| `passthrough_disk2_by_id` | (required) | Path to second passthrough disk |
| `macaddr` | `02:23:45:21:9a:7c` | VM MAC address |

See `variables.tf` for the complete list and `terraform.tfvars.example` for examples.

## Safety Notes

### Passthrough Disk Warnings

**⚠️ CRITICAL**: The two WD 6TB drives are passed through directly to the VM:

- **Exclusive ownership**: Once passed through, these disks belong to TrueNAS. Do not attempt to access them from the Proxmox host.
- **Data risk**: Any data on these disks will be managed by TrueNAS. If you destroy the VM without proper shutdown, data could be corrupted.
- **No Proxmox backups**: Proxmox cannot back up raw passthrough disks. Use TrueNAS's own backup/replication features.
- **Physical dependency**: The VM cannot start if these disks are unavailable or their paths change.

### Lifecycle Management

- The `create_before_destroy` lifecycle rule ensures safer VM recreation
- The `ignore_changes = [cdrom]` rule allows you to modify/remove the CD-ROM after installation without Terraform reverting it
- To destroy the VM: `tofu destroy` (ensure TrueNAS is properly shut down first)

## Troubleshooting

### VM Won't Start

- Verify disk paths exist: `ls -l /dev/disk/by-id/ata-WDC_*`
- Check Proxmox logs: `journalctl -u pve-cluster -f`
- Verify ISO is present: Check Proxmox UI → local-120 → ISO Images

### Can't Find VM IP Address

- Check your router/DHCP server for the MAC address `02:23:45:21:9a:7c`
- Use Proxmox VM console to check TrueNAS network settings
- Create a DHCP reservation for stable IP addressing

### Terraform State

This environment uses local state by default (stored in `terraform.tfstate`). For team environments, consider configuring a remote backend (S3, Terraform Cloud, etc.) in `main.tf`.

## Next Steps

After TrueNAS is running:

- Configure SMB/NFS shares for your network
- Set up automated snapshots for data protection
- Configure S3 cloud sync or replication for off-site backups
- Consider additional datasets for different use cases (media, backups, docker volumes)
- Configure email alerts for system health monitoring

## References

- [TrueNAS SCALE Documentation](https://www.truenas.com/docs/scale/)
- [bpg/proxmox Provider Documentation](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
