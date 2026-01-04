---
icon: material/wrench-outline
---

# Maintenance & Operations

Managing, upgrading, and troubleshooting your Talos cluster.

## Cluster Operations

### Accessing Nodes

Talos is API-only. Use talosctl for all operations:

```bash
# Check node status
talosctl -n 10.23.45.30 version

# List services
talosctl -n 10.23.45.30 services

# View logs
talosctl -n 10.23.45.30 logs kubelet
```

### Kubernetes Access

Use kubectl for Kubernetes operations:

```bash
# Verify cluster
kubectl get nodes

# Check system pods
kubectl get pods -A

# Cluster info
kubectl cluster-info
```

## Upgrading Talos

### Version Planning

Check current and available versions:

```bash
talosctl -n 10.23.45.30 version
```

### Upgrade Process

**1. Update Image Version**

Edit `terraform/envs/talos_cluster/main.tf`:

```hcl
cluster = {
  talos_version = "v1.12.0"  # Update version
}
```

**2. Apply with OpenTofu**

```bash
cd terraform/envs/talos_cluster
tofu apply
```

OpenTofu will:

- Update machine configurations
- Talos performs rolling upgrade
- Nodes reboot one at a time
- Kubernetes control plane updated

**3. Verify Upgrade**

```bash
# Check Talos version on all nodes
talosctl -n 10.23.45.30,10.23.45.31 version

# Verify Kubernetes
kubectl get nodes
```

### Upgrade Kubernetes

Kubernetes version is tied to Talos version. Upgrading Talos automatically upgrades Kubernetes to the bundled version.

## Backup & Recovery

### Backup etcd

```bash
talosctl -n 10.23.45.30 etcd snapshot backup.db
```

### Restore from Backup

```bash
talosctl -n 10.23.45.30 etcd snapshot restore backup.db
```

### State Backup

OpenTofu state is automatically backed up:

- **S3 Versioning**: Enabled on state bucket
- **DynamoDB Locking**: Prevents concurrent modifications
- **Local Backup**: `terraform.tfstate.backup` in project directory

## Node Management

### Adding Nodes

Edit `terraform/envs/talos_cluster/main.tf`:

```hcl
nodes = {
  "k8s-cp00" = { ... }
  "k8s-wk00" = { ... }
  "k8s-wk01" = {  # New worker
    role         = "worker"
    vm_id        = 811
    hostname     = "k8s-wk01.home.arpa"
    cpu_cores    = 4
    memory_mb    = 8192
    disk_size_gb = 50
    ip_address   = "10.23.45.32/24"
  }
}
```

Apply with OpenTofu:

```bash
tofu apply
```

### Removing Nodes

**1. Drain Node**

```bash
kubectl drain k8s-wk00 --ignore-daemonsets --delete-emptydir-data
```

**2. Remove from Cluster**

```bash
kubectl delete node k8s-wk00
```

**3. Remove from OpenTofu**

Delete node entry from `main.tf` and apply:

```bash
tofu apply
```

### Node Reboot

```bash
talosctl -n 10.23.45.30 reboot
```

### Node Reset

⚠️ **Warning**: This wipes the node completely

```bash
talosctl -n 10.23.45.30 reset
```

## Monitoring

### Node Health

```bash
# System stats
talosctl -n 10.23.45.30 stats

# Memory usage
talosctl -n 10.23.45.30 memory

# Disk usage
talosctl -n 10.23.45.30 disks
```

### Service Status

```bash
# All services
talosctl -n 10.23.45.30 services

# Specific service
talosctl -n 10.23.45.30 service kubelet status
```

### Logs

```bash
# Kubelet logs
talosctl -n 10.23.45.30 logs kubelet

# Follow logs
talosctl -n 10.23.45.30 logs -f apid

# Kernel logs
talosctl -n 10.23.45.30 dmesg
```

## Troubleshooting

### Node Not Responding

**Check VM Status in Proxmox**

```bash
ssh root@10.23.45.10 "qm status 800"
```

**Access Console**

Via Proxmox web UI or:

```bash
ssh root@10.23.45.10
qm terminal 800
```

**Check Network**

```bash
talosctl -n 10.23.45.30 get links
talosctl -n 10.23.45.30 get addresses
```

### etcd Issues

**Check etcd Health**

```bash
talosctl -n 10.23.45.30 service etcd status
talosctl -n 10.23.45.30 etcd members
```

**View etcd Logs**

```bash
talosctl -n 10.23.45.30 logs etcd
```

### Kubernetes Not Starting

**Check Control Plane Components**

```bash
talosctl -n 10.23.45.30 service kube-apiserver status
talosctl -n 10.23.45.30 service kube-controller-manager status
talosctl -n 10.23.45.30 service kube-scheduler status
```

**View Component Logs**

```bash
talosctl -n 10.23.45.30 logs kube-apiserver
```

### Pod Issues

**Check Kubelet**

```bash
talosctl -n 10.23.45.31 service kubelet status
talosctl -n 10.23.45.31 logs kubelet
```

**View Containers**

```bash
talosctl -n 10.23.45.31 containers -k  # Kubernetes containers
```

### Network Problems

**Check Routes**

```bash
talosctl -n 10.23.45.30 get routes
```

**Test Connectivity**

```bash
talosctl -n 10.23.45.30 netstat -tulpn
```

## Disaster Recovery

### Cluster Rebuild

If the cluster is completely lost but OpenTofu state exists:

```bash
cd terraform/envs/talos_cluster
tofu destroy  # Clean up
tofu apply    # Rebuild from scratch
```

The cluster will be recreated with same configuration.

### State Recovery

If OpenTofu state is lost:

1. Retrieve from S3 backup (versioned)
2. Or import existing resources:

```bash
tofu import module.talos_cluster.proxmox_virtual_environment_vm.vm["k8s-cp00"] 800
```

## Performance Tuning

### Kernel Parameters

Edit machine config templates:

```yaml
machine:
  sysctls:
    vm.max_map_count: "262144"
    net.core.somaxconn: "32768"
```

### Resource Allocation

Adjust VM resources in `main.tf`:

```hcl
cpu_cores    = 8  # Increase CPU
memory_mb    = 16384  # Increase RAM
```

### Disk I/O

Use Proxmox disk cache settings:

```hcl
disk {
  datastore_id = "vmdata"
  size         = 100
  cache        = "writethrough"  # Better performance
}
```

## Best Practices

1. **Regular Backups**: Schedule etcd snapshots
2. **Monitor State**: Watch S3 state bucket
3. **Test Upgrades**: Try in dev environment first
4. **Document Changes**: Keep change log
5. **Staged Rollouts**: Upgrade workers before control plane
6. **Health Checks**: Automate cluster health monitoring

## Useful Commands

```bash
# Quick health check
talosctl -n 10.23.45.30 health

# Get machine config
talosctl -n 10.23.45.30 get machineconfig

# View certificates
talosctl -n 10.23.45.30 get certificates

# Restart service
talosctl -n 10.23.45.30 service kubelet restart

# Upgrade Talos (manual)
talosctl -n 10.23.45.30 upgrade --image ghcr.io/siderolabs/installer:v1.12.0
```

## Additional Resources

- [Talos Maintenance Guide](https://www.talos.dev/latest/talos-guides/maintenance/)
- [Troubleshooting Guide](https://www.talos.dev/latest/talos-guides/troubleshooting/)
- [etcd Operations](https://www.talos.dev/latest/talos-guides/etcd/)
