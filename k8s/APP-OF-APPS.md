# Kubernetes Manifests - App-of-Apps Pattern

This repository uses ArgoCD with the app-of-apps pattern and Kustomize overlays to manage platform add-ons and workloads across dev and prod environments.

## Directory Structure

```
k8s/
├── base/
│   └── bootstrap/              # Bootstrap resources
│       ├── argocd-namespace.yaml
│       ├── argocd-install.yaml
│       └── root-app.yaml       # Root app-of-apps (patched per env)
│
├── overlays/
│   ├── dev/                    # Dev bootstrap
│   │   ├── kustomization.yaml
│   │   └── root-app-dev.patch.yaml
│   └── prod/                   # Prod bootstrap
│       ├── kustomization.yaml
│       └── root-app-prod.patch.yaml
│
└── apps/
    ├── base/
    │   ├── platform/           # Platform add-ons
    │   │   ├── argocd.yaml
    │   │   ├── cert-manager.yaml
    │   │   ├── grafana.yaml
    │   │   ├── istio.yaml
    │   │   ├── keycloak.yaml
    │   │   └── kyverno.yaml
    │   └── workloads/          # Application workloads
    │       ├── home-assistant.yaml
    │       ├── jellyfin.yaml
    │       └── netbox.yaml
    │
    └── overlays/
        ├── dev/                # Dev apps configuration
        │   ├── kustomization.yaml
        │   ├── platform/       # Dev platform patches
        │   │   ├── cert-manager-values.patch.yaml
        │   │   ├── grafana-values.patch.yaml
        │   │   ├── istio-values.patch.yaml
        │   │   ├── keycloak-values.patch.yaml
        │   │   └── kyverno-values.patch.yaml
        │   └── workloads/      # Dev workload patches
        │       ├── home-assistant-values.patch.yaml
        │       ├── jellyfin-values.patch.yaml
        │       └── netbox-values.patch.yaml
        │
        └── prod/               # Prod apps configuration
            ├── kustomization.yaml
            ├── platform/       # Prod platform patches
            │   └── (same files as dev)
            └── workloads/      # Prod workload patches
                └── (same files as dev)
```

## Bootstrap Process

### Development (kind/minikube)

```bash
# Create cluster
kind create cluster --name homelab-dev

# Bootstrap ArgoCD and apps
kubectl apply -k k8s/overlays/dev

# Wait for ArgoCD
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

### Production (k3s cluster)

```bash
# Bootstrap (ArgoCD installed via k3s HelmChart)
kubectl apply -k k8s/overlays/prod

# Monitor applications
kubectl get applications -n argocd
argocd app list
```

## How It Works

1. **Bootstrap Layer** (`k8s/overlays/{env}/`)

   - Installs ArgoCD
   - Creates root app-of-apps
   - Root app points to `k8s/apps/overlays/{env}`

2. **App Layer** (`k8s/apps/`)

   - **Base** defines ArgoCD Applications for all platform/workloads
   - **Overlays** patch Helm values per environment
   - No manifest duplication - only value overrides

3. **Root App-of-Apps** watches `k8s/apps/overlays/{env}/`
   - Syncs all Application manifests
   - ArgoCD then deploys each app according to its spec

## Adding New Applications

### 1. Create Base Application

Add to `k8s/apps/base/platform/` or `k8s/apps/base/workloads/`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: platform # or workloads
  source:
    repoURL: https://charts.example.com
    chart: my-app
    targetRevision: 1.0.0
    helm:
      values: |
        # Base values here
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 2. Add to Overlays

Reference in `k8s/apps/overlays/{env}/kustomization.yaml`:

```yaml
resources:
  - ../../base/platform/my-app.yaml

patches:
  - path: platform/my-app-values.patch.yaml
```

### 3. Create Environment Patches

Create `k8s/apps/overlays/dev/platform/my-app-values.patch.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
spec:
  source:
    helm:
      values: |
        # Dev-specific overrides
        replicaCount: 1
        resources:
          requests:
            cpu: 50m
```

Create similar file for prod with production values.

### 4. Apply

```bash
# Dev
kubectl apply -k k8s/overlays/dev

# Prod
kubectl apply -k k8s/overlays/prod
```

ArgoCD will detect and sync the new application.

## TODOs

### Repository Configuration

- [ ] Update `repoURL` in all files from placeholder to actual GitHub org/repo

### Platform Apps

- [ ] **ArgoCD**: Configure Helm chart version and values
- [ ] **Cert-Manager**: Add ACME issuer configuration (Let's Encrypt)
- [ ] **Grafana**: Configure admin password (use secrets), add dashboards
- [ ] **Istio**: Add istiod and ingress gateway Applications, configure profiles
- [ ] **Keycloak**: Configure realms, clients, identity providers, use secrets for passwords
- [ ] **Kyverno**: Add policy Applications, configure pod security standards

### Workload Apps

- [ ] **Home Assistant**: Choose Helm chart or create raw manifests in `k8s/configs/home-assistant/`
- [ ] **Jellyfin**: Choose Helm chart or create raw manifests, configure hardware acceleration
- [ ] **NetBox**: Choose Helm chart or create raw manifests, configure plugins

### Environment-Specific

- [ ] **Dev**: Test all apps work in kind/minikube with reduced resources
- [ ] **Prod**: Configure proper storage classes (currently using `local-path` placeholder)
- [ ] **Prod**: Set up secret management (Sealed Secrets, External Secrets, or Vault)
- [ ] **Prod**: Configure ingress/TLS for exposed services
- [ ] **Prod**: Set up monitoring (Prometheus) and logging (Loki)
- [ ] **Prod**: Configure backups for stateful applications

### Projects

- [ ] Create ArgoCD Projects for `platform` and `workloads` with appropriate permissions
- [ ] Configure RBAC for projects

## Validation

```bash
# Validate manifests
kubectl kustomize k8s/overlays/dev
kubectl kustomize k8s/overlays/prod

# Check for differences
diff <(kubectl kustomize k8s/overlays/dev) \
     <(kubectl kustomize k8s/overlays/prod)

# Dry-run
kubectl apply -k k8s/overlays/dev --dry-run=server
```

## Troubleshooting

### Application Not Syncing

```bash
# Check application status
kubectl get application -n argocd my-app -o yaml

# View ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller

# Force sync
argocd app sync my-app
```

### Resource Conflicts

```bash
# Check for existing resources
kubectl get all -n my-app

# Prune old resources
argocd app sync my-app --prune
```

### Patch Not Applying

```bash
# Validate kustomization
kubectl kustomize k8s/apps/overlays/dev

# Check patch syntax
kubectl kustomize k8s/apps/overlays/dev | grep -A 20 my-app
```
