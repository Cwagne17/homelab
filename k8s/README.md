# Kubernetes GitOps Structure

This directory contains the Kubernetes manifests managed via GitOps with ArgoCD.

## Directory Structure

```
k8s/
├── base/
│   ├── argocd/              # ArgoCD installation and app-of-apps bootstrap
│   │   ├── app-of-apps.yaml
│   │   └── kustomization.yaml
│   └── apps/                # ArgoCD Application definitions
│       ├── addons/          # Cluster addon applications
│       │   ├── argocd-config.yaml
│       │   ├── cert-manager.yaml      # Helm chart
│       │   ├── grafana.yaml            # Helm chart
│       │   ├── istio.yaml              # Helm chart
│       │   ├── keycloak.yaml           # Helm chart
│       │   ├── kyverno.yaml            # Helm chart
│       │   └── kyverno-policies.yaml
│       ├── apps/            # End-user applications
│       │   ├── homeassistant.yaml
│       │   ├── jellyfin.yaml
│       │   └── netbox.yaml
│       └── kustomization.yaml
└── overlays/
    └── prod/                # Production overlay
        └── kustomization.yaml
```

## Application Structure

Applications are organized in `k8s/apps/`:

```
k8s/apps/
├── addons/                  # Cluster infrastructure
│   ├── argocd-config/       # ArgoCD configuration
│   ├── cert-manager/        # Certificate management (Helm)
│   ├── grafana/             # Monitoring dashboards (Helm)
│   ├── istio/               # Service mesh (Helm)
│   ├── keycloak/            # Identity management (Helm)
│   ├── kyverno/             # Policy engine (Helm)
│   └── kyverno-policies/    # Kyverno policy definitions
├── homeassistant/           # Home automation
├── jellyfin/                # Media server
└── netbox/                  # Network documentation
```

## Bootstrap Process

### Automatic ArgoCD Installation

ArgoCD is **automatically installed** when the k3s cluster starts. The Packer golden image includes a HelmChart manifest at `/var/lib/rancher/k3s/server/manifests/argocd.yaml` that k3s deploys on first boot.

No manual ArgoCD installation needed!

### 1. Wait for ArgoCD to be Ready

```bash
# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=5m
```

### 2. Bootstrap Applications

```bash
kubectl apply -k k8s/overlays/prod
```

This deploys the app-of-apps Application, which then automatically deploys all apps defined in `k8s/base/apps/`.

### 3. Access ArgoCD UI

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access at: https://localhost:8080

## How It Works

1. **k3s auto-deploys ArgoCD**:

   - HelmChart manifest baked into the golden image at `/var/lib/rancher/k3s/server/manifests/argocd.yaml`
   - k3s Helm controller automatically installs ArgoCD on cluster startup
   - No kubectl commands needed for ArgoCD installation

2. **base/argocd/** contains:

   - App-of-apps Application manifest (ArgoCD itself is installed via k3s)

3. **base/apps/** contains:

   - ArgoCD Application CRDs for each app
   - Each Application points to its directory in `k8s/apps/`

4. **overlays/prod/** references the base and can add environment-specific patches

5. **App-of-apps pattern**:
   - The app-of-apps Application points to `k8s/base/apps/`
   - ArgoCD reads all Application manifests there
   - Each Application deploys its respective app

## Adding a New Application

### 1. Create Application Definition

Create `k8s/base/apps/addons/my-app.yaml` (or under `apps/` for end-user apps):

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/cwagne17/homelab.git
    targetRevision: HEAD
    path: k8s/apps/my-app
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 2. Add to Kustomization

Edit `k8s/base/apps/kustomization.yaml`:

```yaml
resources:
  - addons/my-app.yaml
```

### 3. Create App Manifests

Create `k8s/apps/my-app/` with your Kubernetes manifests or Helm chart.

### 4. Commit and Push

```bash
git add .
git commit -m "Add my-app"
git push
```

ArgoCD will automatically detect and deploy the new app!

## Cluster Addons vs End-User Apps

**Cluster Addons** (`base/apps/addons/`):

- Infrastructure components
- Required for cluster functionality
- Many deployed via Helm charts
- Examples: cert-manager, istio, keycloak, kyverno, grafana, argocd-config

**End-User Apps** (`base/apps/apps/`):

- Workload applications
- Not required for cluster operation
- Examples: jellyfin, homeassistant, netbox

## References

- [ArgoCD App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Kustomize Documentation](https://kubectl.docs.kubernetes.io/references/kustomize/)
