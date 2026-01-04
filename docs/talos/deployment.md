---
icon: material/rocket-launch-outline
---

# Deploying Talos Cluster

This guide walks through deploying a Talos Kubernetes cluster on Proxmox using OpenTofu.

## Prerequisites

- Proxmox VE server configured and accessible
- OpenTofu installed
- talosctl CLI installed
- Proxmox API token created
- SSH key access to Proxmox root user

## Architecture

The deployment creates:

- **1 Control Plane Node**: `k8s-cp00.home.arpa` (VM ID 800)
  - 2 vCPU, 4GB RAM, 20GB disk
  - Static IP: 10.23.45.30
- **1 Worker Node**: `k8s-wk00.home.arpa` (VM ID 810)
  - 4 vCPU, 8GB RAM, 50GB disk
  - Static IP: 10.23.45.31

## Deployment Steps

### 1. Configure Credentials

Create API token file:

```bash
cat > terraform/envs/talos_cluster/terraform.auto.tfvars <<EOF
proxmox_api_token = "root@pam!terraform=your-token-here"
EOF
```

### 2. Configure SSH Access

Ensure your SSH key is added to Proxmox root user:

```bash
ssh-copy-id root@10.23.45.10
```

The OpenTofu Proxmox provider requires SSH access for certain operations.

### 3. Initialize OpenTofu

```bash
cd terraform/envs/talos_cluster
tofu init
```

### 4. Review Configuration

Check the deployment plan:

```bash
tofu plan
```

This will show:

- Talos image download
- VM creation with specs
- Machine configuration generation
- Cluster bootstrap steps

### 5. Deploy Cluster

Apply the configuration:

```bash
tofu apply
```

Or use the Makefile:

```bash
make tf-apply ENV=talos_cluster
```

The deployment process:

1. **Download Image** (~2-3 minutes): Talos image fetched to Proxmox
2. **Create VMs** (~1 minute): Both nodes provisioned
3. **Apply Configs** (~30 seconds): Machine configurations applied
4. **Bootstrap** (~1 minutes): Kubernetes cluster initialized
5. **Health Check** (~5 minute): Verify cluster status (bootstrap may take time)

Total deployment time: **~10-15 minutes**

### 6. Export Kubeconfig

After successful deployment:

```bash
make k8s-kubeconfig
```

This merges the Talos kubeconfig into `~/.kube/config`.

### 7. Verify Cluster

Check node status:

```bash
kubectl get nodes
```

Expected output:

```
NAME       STATUS   ROLES           AGE   VERSION
k8s-cp00   Ready    control-plane   5m    v1.34.0
k8s-wk00   Ready    <none>          5m    v1.34.0
```

## Network Configuration

The cluster uses a hybrid networking approach:

- **DHCP**: Initial boot assigns dynamic IP from range .100-.199
- **Static IP**: Added as additional address on same interface
- **Gateway**: 10.23.45.1 with metric 1024

This solves the chicken-and-egg problem where OpenTofu needs to connect to VMs before static IPs are configured.

## State Management

The Terraform state is stored in:

- **Backend**: AWS S3
- **Bucket**: `homelab-terraform-state-678730054304`
- **Key**: `talos-cluster/terraform.tfstate`
- **Lock Table**: `homelab-terraform-locks` (DynamoDB)
- **Region**: us-east-1

State is encrypted at rest and locked during operations.

## Outputs

After deployment, OpenTofu provides:

- **talosconfig**: Saved to `output/talosconfig`
- **kubeconfig**: Saved to `output/kubeconfig`
- **Control Plane IPs**: Node addresses
- **Worker IPs**: Node addresses
- **Cluster Endpoint**: API server URL

## Troubleshooting

### VM fails to boot

- Check Proxmox console for errors
- Verify Talos image downloaded successfully
- Ensure sufficient resources available

### Machine config apply hangs

- Verify VMs are running and accessible
- Check network connectivity to VM IPs
- Review talosctl logs: `talosctl logs -n <node-ip>`

### Bootstrap fails

- Ensure control plane config was applied successfully
- Verify etcd is healthy: `talosctl -n 10.23.45.30 service etcd status`
- Check for previous failed bootstrap attempts

### Health check timeout

- Verify all pods are running: `talosctl -n 10.23.45.30 get pods -A`
- Check control plane components
- Review cluster logs

## Next Steps

- [Configure cluster settings](configuration.md)
- [Deploy applications](../k3s/gitops.md) with GitOps
- [Set up monitoring](../k3s/cluster.md#monitoring)
