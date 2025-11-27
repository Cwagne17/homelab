# GitOps with Argo CD

This guide covers how to deploy and manage applications using GitOps patterns with Argo CD.

## What is GitOps?

GitOps is an operational framework where:

- **Git is the source of truth** for infrastructure and applications
- **Automated sync** applies changes from Git to the cluster
- **Declarative configuration** describes the desired state
- **Continuous reconciliation** ensures actual state matches desired

## Why Argo CD?

Argo CD provides:

| Feature | Benefit |
|---------|---------|
| App-of-Apps | Manage all applications from one root app |
| Automated Sync | Deploy changes automatically |
| Self-Heal | Revert manual drift back to Git state |
| Prune | Remove resources deleted from Git |
| Web UI | Visual management and debugging |

## Accessing Argo CD

After bootstrap:

```bash
# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

Open https://localhost:8080 with username `admin`.

## Application Structure

```
k8s/
├── argo/
│   ├── app-of-apps.yaml      # Root application
│   └── projects/
│       └── default-project.yaml
└── clusters/home/
    ├── kustomization.yaml    # Root kustomization
    ├── bootstrap/            # Argo CD (manual apply)
    ├── infra/                # Infrastructure apps
    │   └── phpipam/          # Example app
    └── apps/                 # User applications
```

## Example: phpIPAM

The phpIPAM application demonstrates:

- Helm chart integration with Kustomize
- Namespace isolation
- Values customization
- TODO markers for configuration

### What is phpIPAM?

phpIPAM is an open-source IP address management (IPAM) application. It helps track:

- IP addresses and subnets
- VLANs and network segments
- Network documentation
- Device tracking

### Accessing phpIPAM

```bash
# Port forward to access
kubectl port-forward svc/phpipam -n ipam 8081:80

# Open http://localhost:8081
# Default admin password: See values.yaml (TODO: changeme)
```

### Configuration TODOs

Before production use, update `values.yaml`:

1. **MetalLB IP**: Set `loadBalancerIP` when using LoadBalancer service
2. **Domain**: Configure ingress host
3. **Passwords**: Change all `CHANGEME` passwords:
   - `mariadb.auth.password`
   - `mariadb.auth.rootPassword`
   - `phpipam.adminPassword`

## Adding New Applications

1. Create directory in `k8s/clusters/home/apps/` or `infra/`
2. Add `kustomization.yaml` with resources
3. Update parent `kustomization.yaml` to include new app
4. Commit and push - Argo CD auto-syncs

Example structure:

```
apps/my-app/
├── kustomization.yaml
├── namespace.yaml
├── deployment.yaml
└── service.yaml
```

## Sync Policies

The app-of-apps uses these sync settings:

```yaml
syncPolicy:
  automated:
    prune: true      # Delete removed resources
    selfHeal: true   # Revert manual changes
```

## Next Steps

- [Cluster Setup](cluster.md) - Configure k3s options
- [Overview](index.md) - Return to k3s overview
