# Design Document

## Overview

The homelab infrastructure system is a GitOps-ready automation framework that combines Packer for image building, OpenTofu for infrastructure provisioning, and Kustomize/Argo CD for Kubernetes workload management. The system creates k3s-optimized AlmaLinux 9 golden images with k3s pre-installed, deploys them to Proxmox using declarative infrastructure-as-code, and manages Kubernetes applications through GitOps patterns.

The design emphasizes:

- Fast VM boot times through pre-baked k3s installation
- Declarative infrastructure management with OpenTofu
- GitOps-based application deployment with Argo CD
- Reproducible builds with semantic versioning
- Clear separation of concerns between image building, infrastructure provisioning, and workload management

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Homelab Repository                       │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │   Packer     │    │   OpenTofu   │    │  Kubernetes  │  │
│  │ Image Builder│───▶│ Infrastructure│───▶│   Manager    │  │
│  │              │    │  Provisioner  │    │              │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│         │                    │                    │          │
└─────────┼────────────────────┼────────────────────┼─────────┘
          │                    │                    │
          ▼                    ▼                    ▼
    ┌──────────┐         ┌──────────┐        ┌──────────┐
    │ Proxmox  │         │ Proxmox  │        │   k3s    │
    │ Template │         │    VM    │        │ Cluster  │
    │  Store   │         │ Instances│        │          │
    └──────────┘         └──────────┘        └──────────┘
```

### Component Interaction Flow

1. **Image Building Phase**: Packer builds AlmaLinux 9 QEMU image, installs k3s, uploads to Proxmox as template
2. **Infrastructure Provisioning Phase**: OpenTofu clones template, applies cloud-init configuration, creates VM instances
3. **Workload Management Phase**: Kustomize renders manifests, Argo CD syncs applications to k3s cluster

### Directory Structure

```
homelab/
├── packer/                          # Image building
│   ├── common.pkr.hcl              # Shared configuration
│   └── alma9-k3s-optimized/        # AlmaLinux 9 + k3s image
│       ├── packer.pkr.hcl          # QEMU builder config
│       ├── variables.pkr.hcl       # Build variables
│       ├── http/userdata/          # Cloud-init templates
│       └── scripts/                # Provisioning scripts
├── terraform/                       # Infrastructure provisioning
│   ├── modules/proxmox-vm/         # Reusable VM module
│   └── envs/k3s-single/            # Environment configs
├── k8s/                            # Kubernetes manifests
│   ├── argo/                       # Argo CD app-of-apps
│   └── clusters/home/              # Cluster-specific configs
│       ├── bootstrap/              # Argo CD installation
│       ├── infra/                  # Infrastructure apps
│       └── apps/                   # User applications
├── scripts/                        # Helper scripts
│   └── preflight.sh                # Validation and linting
└── Makefile                        # Orchestration
```

## Components and Interfaces

### 1. Packer Image Builder

#### Purpose

Creates reproducible, k3s-optimized AlmaLinux 9 golden images for Proxmox.

#### Key Files

- `packer/common.pkr.hcl`: Shared locals and configuration
- `packer/alma9-k3s-optimized/packer.pkr.hcl`: Proxmox-ISO builder configuration
- `packer/alma9-k3s-optimized/variables.pkr.hcl`: Build-time variables
- `packer/alma9-k3s-optimized/scripts/*.sh`: Provisioning scripts
- `packer/alma9-k3s-optimized/http/`: HTTP-served kickstart files

#### Build Process

1. Packer connects to Proxmox API
2. Creates temporary VM with AlmaLinux 9 ISO attached
3. Boots VM with UEFI firmware
4. Serves kickstart file via HTTP for automated installation
5. Installs AlmaLinux 9 base system
6. Runs provisioning scripts:
   - `os-update.sh`: System updates and base packages
   - `guest-agent.sh`: QEMU guest agent installation
   - `k3s-install.sh`: k3s server installation (Traefik disabled)
   - `hardening-oscap.sh`: Security hardening (stub)
7. Converts VM to template directly on Proxmox
8. Template is immediately available for cloning

#### Variables

```hcl
variable "image_version" {
  type        = string
  description = "Semantic version: alma{version}-k3-node-{arch}-{k3s-version}-v{distribution-release}"
}

variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL (e.g., https://10.23.45.10:8006/api2/json)"
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox API username (e.g., root@pam)"
}

variable "proxmox_token" {
  type        = string
  description = "Proxmox API token"
  sensitive   = true
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name to build on"
}

variable "alma_iso_url" {
  type        = string
  description = "AlmaLinux 9 Minimal ISO URL"
}

variable "k3s_version" {
  type        = string
  description = "k3s version to install"
  default     = "v1.28.5+k3s1"
}
```

#### Image Naming Convention

Format: `alma{version}-k3-node-{arch}-{k3s-version}-v{distribution-release}`

Example: `alma9-k3-node-amd64-v1.28.5-v1`

Components:

- `alma{version}`: AlmaLinux major version (e.g., alma9)
- `k3-node`: Indicates k3s pre-installed
- `{arch}`: CPU architecture (amd64, arm64)
- `{k3s-version}`: k3s version (e.g., v1.28.5)
- `v{distribution-release}`: Image iteration (v1, v2, etc.)

### 2. OpenTofu Infrastructure Provisioner

#### Purpose

Declaratively provisions Proxmox VMs from golden image templates.

#### Module: `terraform/modules/proxmox-vm`

#### Inputs

```hcl
variable "name" {
  type        = string
  description = "VM hostname"
}

variable "template" {
  type        = string
  description = "Proxmox template name"
}

variable "node" {
  type        = string
  description = "Proxmox node name"
}

variable "storage" {
  type        = string
  description = "Storage pool for VM disks"
}

variable "bridge" {
  type        = string
  description = "Network bridge"
}

variable "cores" {
  type        = number
  description = "CPU cores"
}

variable "memory" {
  type        = number
  description = "RAM in MB"
}

variable "disk_size" {
  type        = string
  description = "Disk size (e.g., 32G)"
}

variable "ci_user" {
  type        = string
  description = "Cloud-init default user"
}

variable "ssh_pubkey" {
  type        = string
  description = "SSH public key for cloud-init"
}

variable "ip" {
  type        = string
  description = "Static IP address with CIDR (e.g., 10.23.45.31/24)"
}

variable "gateway" {
  type        = string
  description = "Network gateway"
}

variable "nameserver" {
  type        = string
  description = "DNS nameserver"
}

variable "user_data" {
  type        = string
  description = "Optional cloud-init user-data snippet name"
  default     = ""
}
```

#### Outputs

```hcl
output "vm_id" {
  value       = proxmox_vm_qemu.vm.vmid
  description = "Proxmox VM ID"
}

output "ip_address" {
  value       = var.ip
  description = "VM IP address"
}
```

#### Resource Configuration

```hcl
resource "proxmox_vm_qemu" "vm" {
  name        = var.name
  target_node = var.node
  clone       = var.template

  cores  = var.cores
  memory = var.memory

  disk {
    type    = "scsi"
    storage = var.storage
    size    = var.disk_size
    ssd     = 1
    discard = "on"
  }

  network {
    model  = "virtio"
    bridge = var.bridge
  }

  # Cloud-init configuration
  ciuser     = var.ci_user
  sshkeys    = var.ssh_pubkey
  ipconfig0  = "ip=${var.ip},gw=${var.gateway}"
  nameserver = var.nameserver

  # Optional custom user-data
  cicustom = var.user_data != "" ? "user=local:snippets/${var.user_data}" : null

  lifecycle {
    create_before_destroy = true
  }
}
```

### 3. Environment: k3s-single

#### Purpose

Deploys a single-node k3s cluster for homelab use.

#### Configuration

- VM Name: `k3s-s1`
- Cores: 4
- Memory: 24GB (24576 MB)
- Disk: 32GB
- IP: 10.23.45.31/24
- Gateway: 10.23.45.1
- Nameserver: 10.23.45.1

#### Provider Configuration

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}
```

#### Environment Variables

- `PM_API_URL`: Proxmox API endpoint (e.g., https://10.23.45.10:8006/api2/json)
- `PM_API_TOKEN_ID`: API token ID (e.g., root@pam!terraform)
- `PM_API_TOKEN_SECRET`: API token secret

### 4. Kubernetes Manager

#### Purpose

Manages Kubernetes workloads using GitOps patterns with Argo CD.

#### Bootstrap Process

1. Apply Argo CD installation manifests
2. Deploy app-of-apps root application
3. Argo CD syncs all applications from Git

#### Directory Structure

```
k8s/
├── argo/
│   ├── app-of-apps.yaml              # Root application
│   └── projects/default-project.yaml # Argo CD project
└── clusters/home/
    ├── kustomization.yaml            # Root kustomization
    ├── bootstrap/
    │   ├── kustomization.yaml
    │   └── argocd-install.yaml       # Argo CD manifests
    ├── infra/
    │   ├── kustomization.yaml
    │   └── phpipam/                  # Example app
    │       ├── kustomization.yaml
    │       ├── namespace.yaml
    │       ├── deployment.yaml
    │       ├── service.yaml
    │       └── values.yaml
    └── apps/
        └── kustomization.yaml
```

#### Argo CD Configuration

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: <GIT_REPO_URL>
    targetRevision: HEAD
    path: k8s/clusters/home
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 5. Example Application: phpIPAM

#### Purpose

Demonstrates Kubernetes deployment patterns for homelab applications using Helm charts.

#### Components

- Namespace: `ipam`
- Helm Chart: phpipam/phpipam v1.0.1 from https://artifacthub.io/packages/helm/phpipam/phpipam
- Includes: phpIPAM web interface, MariaDB database, and services
- Service: ClusterIP (TODO: MetalLB LoadBalancer)

#### Helm Chart Deployment

Using Kustomize HelmChartInflationGenerator or Argo CD Helm support:

```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ipam

resources:
  - namespace.yaml

helmCharts:
  - name: phpipam
    repo: https://phpipam.github.io/helm-charts
    version: 1.0.1
    releaseName: phpipam
    namespace: ipam
    valuesFile: values.yaml
```

```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ipam
```

#### values.yaml

```yaml
# Minimal phpIPAM Helm values
# Full values: https://github.com/phpipam/helm-charts/blob/main/charts/phpipam/values.yaml

# TODO: Configure MetalLB LoadBalancer IP
service:
  type: ClusterIP # Change to LoadBalancer when MetalLB is configured
  # loadBalancerIP: 10.23.45.100

# TODO: Configure ingress domain
ingress:
  enabled: false
  # enabled: true
  # hosts:
  #   - host: ipam.home.arpa
  #     paths:
  #       - path: /
  #         pathType: Prefix

# Database configuration (MariaDB included in chart)
mariadb:
  enabled: true
  auth:
    database: phpipam
    username: phpipam
    # TODO: Set secure password
    password: changeme
    rootPassword: changeme

# phpIPAM configuration
phpipam:
  # TODO: Configure admin password
  adminPassword: changeme
  name: phpipam
  user: phpipam
  # password: <secret>
```

### 7. Makefile Orchestration

#### Purpose

Provides simple interface for complex multi-tool workflows.

#### Targets

**Image Building**

```makefile
packer:
  cd packer/alma9-k3s-optimized && \
  packer init . && \
  packer build \
    -var "image_version=$(IMAGE_VERSION)" \
    -var "k3s_version=$(K3S_VERSION)" \
    .
```

**Infrastructure Management**

```makefile
tf-init:
  cd terraform/envs/$(ENV) && tofu init

tf-plan:
  cd terraform/envs/$(ENV) && \
  tofu plan -var-file=../../globals.tfvars

tf-apply:
  cd terraform/envs/$(ENV) && \
  tofu apply -var-file=../../globals.tfvars

tf-destroy:
  cd terraform/envs/$(ENV) && \
  tofu destroy -var-file=../../globals.tfvars
```

**Kubernetes Management**

```makefile
k8s-bootstrap:
  kubectl apply -k k8s/clusters/home/bootstrap

argo:
  kubectl apply -f k8s/argo/app-of-apps.yaml

k8s-diff:
  kubectl diff -k k8s/clusters/home
```

**Utility Targets**

```makefile
preflight:
  ./scripts/preflight.sh

clean:
  rm -rf packer/**/output/
  find terraform -name ".terraform" -type d -exec rm -rf {} +
```

## Data Models

### Image Metadata

```hcl
{
  version           = "alma9-k3-node-amd64-v1.28.5-v1"
  base_os           = "AlmaLinux 9"
  architecture      = "amd64"
  k3s_version       = "v1.28.5+k3s1"
  distribution_release = "v1"
  build_date        = "2024-01-15T10:30:00Z"
  qcow2_path        = "output/alma9-k3s-optimized.qcow2"
  qcow2_size_gb     = 2.1
  template_id       = 9000
}
```

### VM Configuration

```hcl
{
  name       = "k3s-s1"
  vmid       = 101
  template   = "alma9-k3-node-amd64-v1.28.5-v1"
  node       = "pve"
  cores      = 4
  memory     = 24576
  disk_size  = "32G"
  storage    = "vmdata"
  bridge     = "vmbr0"

  cloud_init = {
    user       = "admin"
    ssh_keys   = ["ssh-ed25519 AAAA..."]
    ip         = "10.23.45.31/24"
    gateway    = "10.23.45.1"
    nameserver = "10.23.45.1"
  }
}
```

### Kubernetes Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: phpipam
  namespace: argocd
spec:
  project: default
  source:
    repoURL: <GIT_REPO_URL>
    targetRevision: HEAD
    path: k8s/clusters/home/infra/phpipam
  destination:
    server: https://kubernetes.default.svc
    namespace: ipam
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Correctness Properties

_A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees._

### Property 1: Image naming convention consistency

_For any_ combination of AlmaLinux version, architecture, k3s version, and distribution release, the generated template name should match the format `alma{version}-k3-node-{arch}-{k3s-version}-v{distribution-release}` with all components properly formatted and separated by hyphens.

**Validates: Requirements 1.5, 2.5**

### Property 2: VM cloning from specified template

_For any_ VM creation request with a specified template name, the resulting VM should have that template as its parent/clone source in Proxmox.

**Validates: Requirements 3.1**

### Property 3: Cloud-init configuration completeness

_For any_ VM provisioned with cloud-init parameters (hostname, IP, gateway, nameserver, SSH keys), all provided parameters should be present in the VM's cloud-init configuration.

**Validates: Requirements 3.2**

### Property 4: Infrastructure provisioner output completeness

_For any_ successful OpenTofu deployment, the outputs should include both the VM IP address and kubectl context information.

**Validates: Requirements 3.5**

### Property 5: Proxmox VM disk configuration

_For any_ VM created by the proxmox-vm module, the disk configuration should specify exactly one SCSI disk with SSD emulation enabled and discard set to "on".

**Validates: Requirements 4.2**

### Property 6: Proxmox VM network configuration

_For any_ VM created by the proxmox-vm module with a specified bridge, the network configuration should have exactly one virtio interface attached to that bridge.

**Validates: Requirements 4.3**

### Property 7: Cloud-init user-data conditional configuration

_For any_ proxmox-vm module invocation, if user_data is provided (non-empty), then the VM's cicustom configuration should reference that user-data snippet; if user_data is empty, cicustom should be null.

**Validates: Requirements 4.4**

### Property 8: Module output presence

_For any_ completed proxmox-vm module execution, the outputs should include both vm_id and ip_address values.

**Validates: Requirements 4.5**

### Property 9: Configuration file placeholder conventions

_For any_ configuration file containing placeholder values for secrets or environment-specific settings, the placeholders should use the naming conventions "TODO" or "CHANGEME".

**Validates: Requirements 7.3, 7.5**

### Property 10: Stub script documentation

_For any_ stub script file in the provisioning scripts directory, the file should contain comments explaining how to enable or extend the functionality.

**Validates: Requirements 8.2**

### Property 11: Image directory path consistency

_For any_ reference to the AlmaLinux k3s-optimized image directory in configuration files or scripts, the path should be `packer/alma9-k3s-optimized`.

**Validates: Requirements 8.5**

### Property 12: Upload script template creation

_For any_ successful execution of the upload script with a qcow2 file and version string, the script should create a Proxmox template and output the template name matching the provided version string.

**Validates: Requirements 9.5**

## Error Handling

### Packer Build Failures

**ISO Download Failures**

- Retry with exponential backoff
- Provide clear error message with ISO URL
- Suggest manual download and local file path

**Provisioning Script Failures**

- Fail fast on critical errors (OS updates, k3s installation)
- Log detailed error output
- Preserve partial build for debugging

**Upload Failures**

- Verify SSH connectivity before upload
- Check Proxmox storage availability
- Provide rollback instructions

### OpenTofu Deployment Failures

**Template Not Found**

- Validate template exists before VM creation
- Provide clear error with available templates
- Suggest running Packer build first

**Resource Conflicts**

- Check for existing VMs with same name
- Validate IP address availability
- Use create_before_destroy to minimize downtime

**Cloud-init Failures**

- Validate SSH key format
- Check network configuration syntax
- Provide cloud-init logs location

### Kubernetes Deployment Failures

**Argo CD Installation Failures**

- Verify cluster connectivity
- Check for existing Argo CD installation
- Provide manual installation fallback

**Application Sync Failures**

- Validate Git repository accessibility
- Check manifest syntax with kustomize build
- Provide Argo CD UI URL for debugging

**Resource Creation Failures**

- Check for namespace conflicts
- Validate RBAC permissions
- Provide kubectl commands for manual verification

### Script Execution Failures

**Upload Script Failures**

- Validate qcow2 file exists and is readable
- Check Proxmox SSH connectivity
- Verify sufficient storage space
- Provide manual qm commands as fallback

**Makefile Target Failures**

- Validate required environment variables
- Check tool availability (packer, tofu, kubectl)
- Provide clear error messages with resolution steps

## Testing Strategy

### Unit Testing

Unit tests will verify specific examples and edge cases for individual components:

**Packer Configuration**

- Validate variable definitions and types
- Test provisioning script syntax
- Verify ISO checksum validation

**OpenTofu Modules**

- Test module variable validation
- Verify resource configuration syntax
- Test output expressions

**Kubernetes Manifests**

- Validate YAML syntax
- Test kustomize build output
- Verify resource schema compliance

**Shell Scripts**

- Test argument parsing
- Verify error handling paths
- Test SSH command construction

### Property-Based Testing

Property-based tests will verify universal properties across all inputs using **fast-check** for JavaScript/TypeScript components and **ShellCheck** for shell scripts. Each property-based test will run a minimum of 100 iterations.

**Image Naming Property Tests**

- Generate random version components (alma version, arch, k3s version, release)
- Verify naming format matches specification
- Test with edge cases (long versions, special characters)
- **Feature: homelab-infra, Property 1: Image naming convention consistency**

**OpenTofu Configuration Property Tests**

- Generate random VM configurations
- Verify all required parameters are accepted
- Test cloud-init configuration completeness
- **Feature: homelab-infra, Property 3: Cloud-init configuration completeness**
- **Feature: homelab-infra, Property 5: Proxmox VM disk configuration**
- **Feature: homelab-infra, Property 6: Proxmox VM network configuration**

**Placeholder Convention Property Tests**

- Scan all configuration files for placeholder patterns
- Verify all placeholders use TODO or CHANGEME conventions
- **Feature: homelab-infra, Property 9: Configuration file placeholder conventions**

**Path Consistency Property Tests**

- Scan all files for image directory references
- Verify all paths use `packer/alma9-k3s-optimized`
- **Feature: homelab-infra, Property 11: Image directory path consistency**

### Integration Testing

Integration tests will verify end-to-end workflows:

**Image Build and Upload**

1. Run Packer build with test configuration
2. Verify qcow2 output exists
3. Mock Proxmox upload
4. Verify template creation

**Infrastructure Deployment**

1. Mock Proxmox API responses
2. Run OpenTofu plan
3. Verify VM configuration matches specification
4. Test cloud-init rendering

**Kubernetes Bootstrap**

1. Use kind or k3d for test cluster
2. Apply bootstrap manifests
3. Verify Argo CD installation
4. Test app-of-apps deployment

**End-to-End Workflow**

1. Build image (or use cached)
2. Deploy VM to test Proxmox
3. Verify k3s starts automatically
4. Deploy test application
5. Verify application accessibility

### Testing Tools

- **Packer**: `packer validate`, `packer fmt`
- **OpenTofu**: `tofu validate`, `tofu fmt`, `tofu plan`
- **Kubernetes**: `kubectl apply --dry-run`, `kustomize build`, `kubeval`
- **Shell Scripts**: ShellCheck, BATS (Bash Automated Testing System)
- **Property Testing**: fast-check (for any TypeScript/JavaScript utilities)
- **Linting**: yamllint, tflint, hadolint (for any Dockerfiles)

### Continuous Validation

The `preflight.sh` script provides quick validation:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "==> Formatting checks"
packer fmt -check packer/
tofu fmt -check -recursive terraform/

echo "==> Validation checks"
cd packer/alma9-k3s-optimized && packer validate .
cd ../../terraform/envs/k3s-single && tofu validate

echo "==> Kubernetes manifest validation"
kustomize build k8s/clusters/home/bootstrap > /dev/null
kustomize build k8s/clusters/home/infra > /dev/null

echo "==> Shell script linting"
find scripts -name "*.sh" -exec shellcheck {} \;

echo "==> YAML linting"
find k8s -name "*.yaml" -exec yamllint {} \;

echo "✓ All preflight checks passed"
```

## Implementation Notes

### Packer Considerations

**UEFI Boot**

- Use OVMF firmware for UEFI support
- Configure EFI system partition correctly
- Test both BIOS and UEFI boot modes

**k3s Installation**

- Pin k3s version for reproducibility
- Disable Traefik to avoid port conflicts
- Configure k3s to use systemd cgroups
- Pre-pull common container images to reduce first-boot time

**Image Optimization**

- Run `fstrim` before image creation
- Zero out free space for better compression
- Remove unnecessary packages and logs
- Configure automatic updates (optional)

### OpenTofu Considerations

**State Management**

- Use remote state backend (S3, Consul, etc.)
- Enable state locking
- Configure state encryption
- Document state backup procedures

**Provider Configuration**

- Use environment variables for credentials
- Configure API timeouts appropriately
- Enable detailed logging for debugging
- Pin provider versions

**Module Design**

- Keep modules focused and reusable
- Use sensible defaults
- Document all variables
- Provide examples

### Kubernetes Considerations

**Argo CD Configuration**

- Use declarative setup (app-of-apps pattern)
- Configure RBAC appropriately
- Enable SSO (optional)
- Set up notifications (optional)

**Kustomize Best Practices**

- Use bases and overlays for environment differences
- Keep patches small and focused
- Use strategic merge patches
- Document kustomization structure

**Application Deployment**

- Use namespaces for isolation
- Configure resource limits
- Implement health checks
- Use secrets management (sealed-secrets, external-secrets)

### Security Considerations

**Image Hardening**

- Apply OpenSCAP security profiles
- Configure SELinux/AppArmor
- Disable unnecessary services
- Configure automatic security updates

**Network Security**

- Use firewall rules (firewalld, iptables)
- Configure network policies in Kubernetes
- Use private networks where possible
- Enable TLS for all services

**Access Control**

- Use SSH key authentication only
- Implement RBAC in Kubernetes
- Use API tokens with limited scope
- Rotate credentials regularly

**Secrets Management**

- Never commit secrets to Git
- Use environment variables or secret managers
- Encrypt secrets at rest
- Implement secret rotation

### Operational Considerations

**Monitoring**

- Deploy Prometheus and Grafana
- Configure alerts for critical services
- Monitor resource usage
- Track deployment metrics

**Backup and Recovery**

- Backup Proxmox VMs regularly
- Backup Kubernetes etcd
- Document recovery procedures
- Test backups periodically

**Updates and Maintenance**

- Plan for k3s upgrades
- Test updates in staging first
- Document rollback procedures
- Keep dependencies up to date

**Documentation**

- Maintain runbooks for common tasks
- Document architecture decisions
- Keep README up to date
- Provide troubleshooting guides
