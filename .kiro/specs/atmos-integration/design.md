# Design Document

## Overview

The Atmos integration transforms the existing homelab infrastructure repository into an Atmos-orchestrated system that provides unified component management, stack-based configuration, and workflow automation. This design builds upon the existing Packer, OpenTofu, and Kubernetes infrastructure by introducing Atmos as the orchestration layer that manages all three toolchains through a consistent interface.

The integration emphasizes:

- Unified component management across Packer, OpenTofu, and Kubernetes
- Stack-based configuration with inheritance and deep merging
- Declarative workflow orchestration for end-to-end deployments
- Environment-agnostic component definitions with stack-specific overrides
- Native Atmos support for both Packer and OpenTofu commands
- Catalog-based configuration reuse for future expansion

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Atmos Orchestration Layer                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │    Atmos     │    │    Atmos     │    │    Atmos     │      │
│  │   Packer     │───▶│  Terraform   │───▶│  Workflows   │      │
│  │  Component   │    │  Component   │    │              │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│         │                    │                    │              │
└─────────┼────────────────────┼────────────────────┼─────────────┘
          │                    │                    │
          ▼                    ▼                    ▼
    ┌──────────┐         ┌──────────┐        ┌──────────┐
    │  Packer  │         │ OpenTofu │        │ kubectl  │
    │  Build   │         │  Deploy  │        │  Apply   │
    └──────────┘         └──────────┘        └──────────┘
```

### Component Interaction Flow

1. **Configuration Phase**: Atmos reads atmos.yaml and loads stack manifests from stacks/deploy/
2. **Stack Resolution Phase**: Atmos merges catalog imports with stack-specific configuration
3. **Component Execution Phase**: Atmos injects variables and executes component commands
4. **Workflow Orchestration Phase**: Atmos chains multiple component operations in sequence

### Directory Structure Migration

```
homelab/
├── atmos.yaml                       # Atmos CLI configuration
├── components/                      # All components organized by toolchain
│   ├── terraform/                   # OpenTofu components (root modules)
│   │   ├── k3s-cluster/            # Single-node k3s cluster component
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── versions.tf
│   │   └── proxmox-vm/             # Reusable VM module (if needed)
│   └── packer/                      # Packer components (templates)
│       └── alma9-k3s-optimized/    # AlmaLinux 9 + k3s image
│           ├── main.pkr.hcl
│           ├── variables.pkr.hcl
│           ├── http/
│           └── scripts/
├── stacks/                          # Stack configurations
│   ├── catalog/                     # Reusable base configurations
│   │   └── proxmox.yaml            # Common Proxmox settings
│   ├── deploy/                      # Deployable stacks
│   │   └── pve-prod.yaml           # Production Proxmox environment
│   └── workflows/                   # Workflow definitions
│       ├── packer.yaml             # Packer build workflows
│       ├── infrastructure.yaml     # OpenTofu workflows
│       └── kubernetes.yaml         # K8s bootstrap workflows
├── k8s/                            # Kubernetes manifests (unchanged)
│   ├── argo/
│   └── clusters/home/
└── scripts/                        # Helper scripts
    └── preflight.sh
```

## Components and Interfaces

### 1. Atmos CLI Configuration (atmos.yaml)

#### Purpose

Defines base paths, component locations, and global settings for Atmos.

#### Configuration Structure

```yaml
base_path: "./"

components:
  terraform:
    command: "tofu"
    base_path: "components/terraform"
    apply_auto_approve: false
    deploy_run_init: true
    init_run_reconfigure: true
    auto_generate_backend_file: false
    init:
      pass_vars: true # Required for OpenTofu backend configuration

  packer:
    command: "packer"
    base_path: "components/packer"

stacks:
  base_path: "stacks"
  included_paths:
    - "deploy/**/*"
  excluded_paths:
    - "catalog/**/*"
  name_pattern: "{{ .vars.environment }}"

logs:
  file: "/dev/stderr"
  level: Info

templates:
  settings:
    enabled: true
    evaluations: 1
    sprig:
      enabled: true
    gomplate:
      enabled: true
```

### 2. Catalog Configuration (stacks/catalog/proxmox.yaml)

#### Purpose

Provides reusable base configuration for Proxmox-related components that can be imported by deployment stacks.

#### Configuration Structure

```yaml
vars:
  # Proxmox connection settings
  proxmox_url: "https://10.23.45.10:8006/api2/json"
  proxmox_node: "pve"
  proxmox_storage: "vmdata"
  proxmox_bridge: "vmbr0"

  # Network settings
  network_gateway: "10.23.45.1"
  network_nameserver: "10.23.45.1"
  network_cidr: "24"

  # k3s settings
  k3s_version: "v1.28.5+k3s1"

  # VM defaults
  default_cores: 4
  default_memory: 24576 # 24GB in MB
  default_disk_size: "32G"

  # Packer image settings
  alma_version: "9"
  alma_iso_url: "https://repo.almalinux.org/almalinux/9/isos/x86_64/AlmaLinux-9-latest-x86_64-minimal.iso"
  alma_iso_checksum: "sha256:..."
  image_architecture: "amd64"

components:
  terraform:
    k3s-cluster:
      metadata:
        component: "k3s-cluster"
        type: "real"
      vars: {}

  packer:
    alma9-k3s-optimized:
      metadata:
        component: "alma9-k3s-optimized"
        type: "real"
      settings:
        packer:
          template: "main.pkr.hcl"
      vars: {}
```

### 3. Deployment Stack (stacks/deploy/pve-prod.yaml)

#### Purpose

Defines the pve-prod stack with specific configurations for both Packer and OpenTofu components.

#### Configuration Structure

```yaml
import:
  - catalog/proxmox

vars:
  environment: "pve-prod"

  # VM-specific settings for this stack
  vm_name: "k3s-s1"
  vm_ip: "10.23.45.31"
  vm_cores: 4
  vm_memory: 24576
  vm_disk_size: "32G"

  # Cloud-init settings
  ci_user: "admin"
  ci_ssh_pubkey: "ssh-ed25519 AAAA..." # TODO: Replace with actual key

components:
  terraform:
    k3s-cluster:
      backend_type: "local"
      backend:
        local:
          path: "./terraform.tfstate"

      vars:
        # Proxmox provider configuration
        pm_api_url: "{{ .vars.proxmox_url }}"
        pm_api_token_id: "root@pam!terraform" # TODO: Use environment variable
        pm_api_token_secret: "${PM_API_TOKEN_SECRET}"

        # VM configuration
        vm_name: "{{ .vars.vm_name }}"
        vm_template: "alma9-k3-node-amd64-v1.28.5-v1" # TODO: Get from Packer output
        vm_node: "{{ .vars.proxmox_node }}"
        vm_storage: "{{ .vars.proxmox_storage }}"
        vm_bridge: "{{ .vars.proxmox_bridge }}"
        vm_cores: "{{ .vars.vm_cores }}"
        vm_memory: "{{ .vars.vm_memory }}"
        vm_disk_size: "{{ .vars.vm_disk_size }}"

        # Network configuration
        vm_ip: "{{ .vars.vm_ip }}/{{ .vars.network_cidr }}"
        vm_gateway: "{{ .vars.network_gateway }}"
        vm_nameserver: "{{ .vars.network_nameserver }}"

        # Cloud-init configuration
        ci_user: "{{ .vars.ci_user }}"
        ci_ssh_pubkey: "{{ .vars.ci_ssh_pubkey }}"

  packer:
    alma9-k3s-optimized:
      vars:
        # Proxmox connection
        proxmox_url: "{{ .vars.proxmox_url }}"
        proxmox_username: "root@pam"
        proxmox_token: "${PROXMOX_TOKEN}"
        proxmox_node: "{{ .vars.proxmox_node }}"
        proxmox_storage: "{{ .vars.proxmox_storage }}"

        # Image configuration
        image_version: "alma9-k3-node-amd64-v1.28.5-v1"
        alma_iso_url: "{{ .vars.alma_iso_url }}"
        alma_iso_checksum: "{{ .vars.alma_iso_checksum }}"
        k3s_version: "{{ .vars.k3s_version }}"

        # Build settings
        vm_name: "packer-alma9-k3s"
        vm_cores: 2
        vm_memory: 4096
        vm_disk_size: "20G"
```

### 4. Packer Component (components/packer/alma9-k3s-optimized)

#### Purpose

Builds k3s-optimized AlmaLinux 9 images using Atmos-injected variables from stack manifests.

#### Key Changes from Original

- Variables are now injected by Atmos from stack manifests
- No need for separate `.pkrvars.hcl` files
- Component is stack-agnostic and reusable

#### Variable Definitions (variables.pkr.hcl)

```hcl
variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL"
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox API username"
}

variable "proxmox_token" {
  type        = string
  description = "Proxmox API token"
  sensitive   = true
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name"
}

variable "proxmox_storage" {
  type        = string
  description = "Proxmox storage pool"
}

variable "image_version" {
  type        = string
  description = "Image version identifier"
}

variable "alma_iso_url" {
  type        = string
  description = "AlmaLinux ISO URL"
}

variable "alma_iso_checksum" {
  type        = string
  description = "AlmaLinux ISO checksum"
}

variable "k3s_version" {
  type        = string
  description = "k3s version to install"
}

variable "vm_name" {
  type        = string
  description = "Temporary VM name during build"
}

variable "vm_cores" {
  type        = number
  description = "CPU cores for build VM"
}

variable "vm_memory" {
  type        = number
  description = "Memory in MB for build VM"
}

variable "vm_disk_size" {
  type        = string
  description = "Disk size for build VM"
}
```

#### Atmos Commands

```bash
# Validate Packer configuration
atmos packer validate alma9-k3s-optimized -s pve-prod

# Initialize Packer plugins
atmos packer init alma9-k3s-optimized -s pve-prod

# Build image
atmos packer build alma9-k3s-optimized -s pve-prod

# Get build output (Atmos-specific command)
atmos packer output alma9-k3s-optimized -s pve-prod
```

### 5. OpenTofu Component (components/terraform/k3s-cluster)

#### Purpose

Deploys a single-node k3s cluster to Proxmox using Atmos-injected variables from stack manifests.

#### Key Changes from Original

- Converted from environment-specific configuration to reusable component
- Variables are injected by Atmos from stack manifests
- Backend configuration is defined in stack manifest
- No need for separate `.tfvars` files

#### Variable Definitions (variables.tf)

```hcl
variable "pm_api_url" {
  type        = string
  description = "Proxmox API URL"
}

variable "pm_api_token_id" {
  type        = string
  description = "Proxmox API token ID"
}

variable "pm_api_token_secret" {
  type        = string
  description = "Proxmox API token secret"
  sensitive   = true
}

variable "vm_name" {
  type        = string
  description = "VM hostname"
}

variable "vm_template" {
  type        = string
  description = "Proxmox template name to clone"
}

variable "vm_node" {
  type        = string
  description = "Proxmox node name"
}

variable "vm_storage" {
  type        = string
  description = "Storage pool for VM disks"
}

variable "vm_bridge" {
  type        = string
  description = "Network bridge"
}

variable "vm_cores" {
  type        = number
  description = "CPU cores"
}

variable "vm_memory" {
  type        = number
  description = "RAM in MB"
}

variable "vm_disk_size" {
  type        = string
  description = "Disk size"
}

variable "vm_ip" {
  type        = string
  description = "Static IP with CIDR"
}

variable "vm_gateway" {
  type        = string
  description = "Network gateway"
}

variable "vm_nameserver" {
  type        = string
  description = "DNS nameserver"
}

variable "ci_user" {
  type        = string
  description = "Cloud-init default user"
}

variable "ci_ssh_pubkey" {
  type        = string
  description = "SSH public key"
}
```

#### Main Configuration (main.tf)

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

resource "proxmox_vm_qemu" "k3s_node" {
  name        = var.vm_name
  target_node = var.vm_node
  clone       = var.vm_template

  cores  = var.vm_cores
  memory = var.vm_memory

  disk {
    type    = "scsi"
    storage = var.vm_storage
    size    = var.vm_disk_size
    ssd     = 1
    discard = "on"
  }

  network {
    model  = "virtio"
    bridge = var.vm_bridge
  }

  ciuser     = var.ci_user
  sshkeys    = var.ci_ssh_pubkey
  ipconfig0  = "ip=${var.vm_ip},gw=${var.vm_gateway}"
  nameserver = var.vm_nameserver

  lifecycle {
    create_before_destroy = true
  }
}
```

#### Outputs (outputs.tf)

```hcl
output "vm_id" {
  value       = proxmox_vm_qemu.k3s_node.vmid
  description = "Proxmox VM ID"
}

output "vm_ip" {
  value       = var.vm_ip
  description = "VM IP address"
}

output "vm_name" {
  value       = var.vm_name
  description = "VM hostname"
}

output "kubeconfig_command" {
  value       = "scp ${var.ci_user}@${split("/", var.vm_ip)[0]}:/etc/rancher/k3s/k3s.yaml ~/.kube/config"
  description = "Command to retrieve kubeconfig"
}
```

#### Atmos Commands

```bash
# Validate OpenTofu configuration
atmos terraform validate k3s-cluster -s pve-prod

# Plan infrastructure changes
atmos terraform plan k3s-cluster -s pve-prod

# Apply infrastructure changes
atmos terraform apply k3s-cluster -s pve-prod

# Show outputs
atmos terraform output k3s-cluster -s pve-prod

# Destroy infrastructure
atmos terraform destroy k3s-cluster -s pve-prod
```

### 6. Atmos Workflows

#### Purpose

Orchestrate multi-step deployments by chaining Packer builds, OpenTofu deployments, and Kubernetes bootstrapping.

#### Workflow: Deploy Homelab (stacks/workflows/deploy.yaml)

```yaml
workflows:
  deploy-homelab:
    description: "End-to-end homelab deployment: build image, provision VM, bootstrap k8s"
    steps:
      - name: "Build k3s-optimized image"
        command: "atmos packer build alma9-k3s-optimized -s pve-prod"

      - name: "Wait for image availability"
        command: "sleep 30"

      - name: "Deploy k3s cluster"
        command: "atmos terraform apply k3s-cluster -s pve-prod -auto-approve"

      - name: "Wait for VM boot"
        command: "sleep 60"

      - name: "Bootstrap Argo CD"
        command: "kubectl apply -k k8s/clusters/home/bootstrap"

      - name: "Deploy app-of-apps"
        command: "kubectl apply -f k8s/argo/app-of-apps.yaml"

  build-image:
    description: "Build k3s-optimized AlmaLinux image"
    steps:
      - name: "Validate Packer configuration"
        command: "atmos packer validate alma9-k3s-optimized -s pve-prod"

      - name: "Initialize Packer"
        command: "atmos packer init alma9-k3s-optimized -s pve-prod"

      - name: "Build image"
        command: "atmos packer build alma9-k3s-optimized -s pve-prod"

  deploy-infrastructure:
    description: "Deploy k3s cluster to Proxmox"
    steps:
      - name: "Validate OpenTofu configuration"
        command: "atmos terraform validate k3s-cluster -s pve-prod"

      - name: "Plan infrastructure changes"
        command: "atmos terraform plan k3s-cluster -s pve-prod"

      - name: "Apply infrastructure changes"
        command: "atmos terraform apply k3s-cluster -s pve-prod -auto-approve"

  bootstrap-kubernetes:
    description: "Bootstrap Kubernetes with Argo CD"
    steps:
      - name: "Get kubeconfig"
        command: "atmos terraform output k3s-cluster -s pve-prod kubeconfig_command"

      - name: "Bootstrap Argo CD"
        command: "kubectl apply -k k8s/clusters/home/bootstrap"

      - name: "Wait for Argo CD"
        command: "kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd"

      - name: "Deploy app-of-apps"
        command: "kubectl apply -f k8s/argo/app-of-apps.yaml"

  destroy-infrastructure:
    description: "Destroy k3s cluster"
    steps:
      - name: "Destroy infrastructure"
        command: "atmos terraform destroy k3s-cluster -s pve-prod -auto-approve"
```

#### Workflow Execution

```bash
# Run end-to-end deployment
atmos workflow deploy-homelab -f stacks/workflows/deploy.yaml

# Run individual workflows
atmos workflow build-image -f stacks/workflows/deploy.yaml
atmos workflow deploy-infrastructure -f stacks/workflows/deploy.yaml
atmos workflow bootstrap-kubernetes -f stacks/workflows/deploy.yaml

# Destroy infrastructure
atmos workflow destroy-infrastructure -f stacks/workflows/deploy.yaml
```

### 7. Stack Validation and Inspection

#### Purpose

Validate stack configurations and inspect merged configurations before deployment.

#### Validation Commands

```bash
# Validate all stacks
atmos validate stacks

# Validate specific stack
atmos validate stacks --stack pve-prod

# Describe all stacks
atmos describe stacks

# Describe specific component in stack
atmos describe component k3s-cluster -s pve-prod

# Describe component with output format
atmos describe component k3s-cluster -s pve-prod --format yaml
atmos describe component k3s-cluster -s pve-prod --format json

# List all components in stack
atmos list components -s pve-prod
```

#### Validation Checks

Atmos performs the following validations:

1. **YAML Syntax**: Validates all stack manifest YAML syntax
2. **Import Resolution**: Verifies all imported stacks exist
3. **Component References**: Confirms referenced components exist in components directory
4. **Variable Interpolation**: Validates template expressions
5. **Schema Validation**: Checks against JSON schemas if defined

## Data Models

### Stack Configuration Model

```yaml
# Stack manifest structure
import:
  - catalog/base-stack-1
  - catalog/base-stack-2

vars:
  key: value
  nested:
    key: value

components:
  terraform:
    component-name:
      metadata:
        component: "component-directory-name"
        type: "real"
      backend_type: "s3"
      backend:
        s3:
          bucket: "terraform-state"
          key: "component.tfstate"
      vars:
        variable_name: value

  packer:
    component-name:
      metadata:
        component: "component-directory-name"
      settings:
        packer:
          template: "main.pkr.hcl"
      vars:
        variable_name: value
```

### Component Metadata Model

```yaml
metadata:
  component: "k3s-cluster" # Component directory name
  type: "real" # Component type (real, abstract)
  inherits: # Optional inheritance
    - "base-component"

settings:
  packer: # Packer-specific settings
    template: "main.pkr.hcl"
  terraform: # Terraform-specific settings
    workspace: "default"
```

### Workflow Model

```yaml
workflows:
  workflow-name:
    description: "Workflow description"
    steps:
      - name: "Step name"
        command: "command to execute"
      - name: "Another step"
        command: "another command"
```

## Correctness Properties

_A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees._

### Property 1: Stack manifest structure validity

_For any_ stack manifest file, parsing it as YAML should succeed and the result should contain a components section with valid component configurations.

**Validates: Requirements 2.1**

### Property 2: Stack inheritance and merging

_For any_ stack that uses the import directive, the final merged configuration should include all variables from imported stacks, with stack-specific values taking precedence over imported values.

**Validates: Requirements 2.3, 3.3**

### Property 3: Backend configuration presence

_For any_ OpenTofu component defined in a stack manifest, if backend configuration is required, it should be present in the component's backend section.

**Validates: Requirements 2.4, 5.5**

### Property 4: Component reference validity

_For any_ component reference in a stack manifest (using the component key), the corresponding directory should exist in either components/terraform or components/packer.

**Validates: Requirements 2.5**

### Property 5: Catalog configuration structure

_For any_ catalog configuration file, it should contain a vars section with properly structured key-value pairs.

**Validates: Requirements 3.2**

### Property 6: Variable injection for Packer builds

_For any_ Packer build command executed through Atmos with a stack parameter, all variables defined in the stack manifest for that component should be available to the Packer template.

**Validates: Requirements 4.4**

### Property 7: Variable injection for OpenTofu deployments

_For any_ OpenTofu apply command executed through Atmos with a stack parameter, all variables defined in the stack manifest for that component should be injected, and the backend configuration from the component section should be used.

**Validates: Requirements 5.4**

### Property 8: Workflow error handling

_For any_ workflow execution where a step fails, the workflow should halt immediately and report an error message that includes the failed command details.

**Validates: Requirements 7.3**

### Property 9: Workflow step verification

_For any_ workflow that chains Packer and OpenTofu steps, there should be a verification mechanism (explicit check or wait step) between the Packer build completion and OpenTofu deployment initiation.

**Validates: Requirements 7.5**

### Property 10: Stack validation - YAML syntax

_For any_ stack validation execution, the validator should check all stack manifest files for YAML syntax errors and report any malformed files.

**Validates: Requirements 8.2**

### Property 11: Stack validation - import resolution

_For any_ stack validation execution, the validator should verify that all imported stacks referenced in import directives exist and are accessible.

**Validates: Requirements 8.3**

### Property 12: Stack validation - component existence

_For any_ stack validation execution, the validator should confirm that all referenced components exist in the components directory.

**Validates: Requirements 8.4**

### Property 13: Validation error reporting

_For any_ validation error detected during stack validation, the error report should include the specific stack file path and detailed error information.

**Validates: Requirements 8.5**

### Property 14: Component description completeness

_For any_ component in any stack, executing the describe component command should display the final merged configuration including all variables inherited from base stacks.

**Validates: Requirements 9.2, 9.3**

### Property 15: Backend configuration display

_For any_ component with backend configuration, the describe component command should display the backend configuration that will be used.

**Validates: Requirements 9.4**

### Property 16: Output format compliance

_For any_ describe command executed with a format flag (--format yaml or --format json), the output should be valid YAML or JSON respectively and parseable by standard parsers.

**Validates: Requirements 9.5**

### Property 17: Workflow file organization

_For any_ workflow definition file, it should be located in the stacks/workflows directory and be a valid YAML file.

**Validates: Requirements 6.5**

## Error Handling

### Atmos Configuration Errors

**Missing atmos.yaml**

- Provide clear error message indicating atmos.yaml is required
- Suggest running initialization command or provide example configuration
- Document required configuration sections

**Invalid Base Paths**

- Validate that base_path directories exist
- Provide clear error with expected vs actual paths
- Suggest creating missing directories

**Invalid Component Configuration**

- Validate component command executables are available
- Check that base_path directories contain valid components
- Report specific configuration issues with remediation steps

### Stack Configuration Errors

**YAML Syntax Errors**

- Report file path and line number of syntax error
- Show context around the error
- Suggest common YAML syntax fixes

**Import Resolution Failures**

- List all failed import paths
- Verify import paths are relative to stacks directory
- Suggest checking for typos or missing files

**Component Reference Errors**

- Report which component reference failed
- List available components in components directory
- Suggest correct component names

**Variable Interpolation Errors**

- Show which variable reference failed
- Display available variables in scope
- Suggest checking variable names and template syntax

### Packer Component Errors

**Variable Injection Failures**

- Verify all required Packer variables are defined in stack
- Report missing variables with their expected types
- Suggest adding variables to stack manifest

**Build Failures**

- Capture and display Packer error output
- Preserve build artifacts for debugging
- Suggest checking Proxmox connectivity and credentials

**Template Not Found**

- Verify Packer template file exists in component directory
- Check settings.packer.template configuration
- Suggest correct template file name

### OpenTofu Component Errors

**Backend Configuration Errors**

- Validate backend configuration syntax
- Check backend credentials and connectivity
- Suggest backend configuration examples

**Variable Type Mismatches**

- Report variable name and expected vs actual type
- Show variable definition from component
- Suggest correct variable value format

**Provider Authentication Failures**

- Check environment variables for credentials
- Verify API endpoints are accessible
- Suggest credential configuration methods

**Resource Creation Failures**

- Display OpenTofu error output
- Suggest checking Proxmox resource availability
- Provide rollback instructions if needed

### Workflow Execution Errors

**Command Not Found**

- Verify required tools (packer, tofu, kubectl) are installed
- Check PATH environment variable
- Suggest installation instructions

**Step Execution Failures**

- Report which step failed and the command that was executed
- Display command output and error messages
- Halt workflow execution to prevent cascading failures

**Timeout Errors**

- Report which step timed out
- Suggest increasing timeout or checking resource availability
- Provide manual execution instructions

### Validation Errors

**Schema Validation Failures**

- Report which schema validation failed
- Show expected vs actual structure
- Suggest corrections based on schema

**Circular Import Detection**

- Report the circular import chain
- Suggest breaking the circular dependency
- Provide import graph visualization

**Duplicate Component Names**

- Report duplicate component names across stacks
- Suggest using unique component names or namespacing
- Show conflicting component definitions

## Testing Strategy

### Unit Testing

Unit tests will verify specific examples and edge cases for individual components:

**Atmos Configuration**

- Validate atmos.yaml syntax and structure
- Test base_path resolution
- Verify component command configuration

**Stack Manifests**

- Validate YAML syntax for all stack files
- Test import directive resolution
- Verify component reference syntax
- Test variable interpolation expressions

**Catalog Configurations**

- Validate catalog file structure
- Test variable definitions
- Verify component metadata

**Workflow Definitions**

- Validate workflow YAML syntax
- Test step command syntax
- Verify workflow structure

### Property-Based Testing

Property-based tests will verify universal properties across all inputs using **fast-check** for JavaScript/TypeScript validation scripts and **yq** for YAML processing. Each property-based test will run a minimum of 100 iterations.

**Stack Manifest Structure Property Tests**

- Generate random stack manifests with varying structures
- Verify all manifests have required components section
- Test with edge cases (empty stacks, deeply nested structures)
- **Feature: atmos-integration, Property 1: Stack manifest structure validity**

**Stack Inheritance and Merging Property Tests**

- Generate random base and derived stacks
- Verify deep merge behavior with various nesting levels
- Test precedence rules (stack values override imported values)
- **Feature: atmos-integration, Property 2: Stack inheritance and merging**

**Component Reference Validity Property Tests**

- Generate random component references
- Verify all references map to existing directories
- Test with various component types (terraform, packer)
- **Feature: atmos-integration, Property 4: Component reference validity**

**Variable Injection Property Tests**

- Generate random variable sets in stack manifests
- Verify variables are properly injected into components
- Test with various variable types and nesting levels
- **Feature: atmos-integration, Property 6: Variable injection for Packer builds**
- **Feature: atmos-integration, Property 7: Variable injection for OpenTofu deployments**

**Validation Behavior Property Tests**

- Generate stacks with various error conditions
- Verify validation catches all error types
- Test error reporting includes required details
- **Feature: atmos-integration, Property 10: Stack validation - YAML syntax**
- **Feature: atmos-integration, Property 11: Stack validation - import resolution**
- **Feature: atmos-integration, Property 12: Stack validation - component existence**
- **Feature: atmos-integration, Property 13: Validation error reporting**

**Output Format Property Tests**

- Generate random component configurations
- Verify describe output is valid YAML/JSON
- Test format flag behavior
- **Feature: atmos-integration, Property 16: Output format compliance**

### Integration Testing

Integration tests will verify end-to-end workflows:

**Stack Configuration Loading**

1. Create test stack with imports
2. Run atmos describe component
3. Verify merged configuration is correct
4. Test variable inheritance

**Packer Component Execution**

1. Create test Packer component
2. Define test stack with variables
3. Run atmos packer validate
4. Verify variables are injected correctly

**OpenTofu Component Execution**

1. Create test OpenTofu component
2. Define test stack with backend config
3. Run atmos terraform plan
4. Verify variables and backend are configured

**Workflow Execution**

1. Define test workflow with multiple steps
2. Execute workflow
3. Verify steps run in sequence
4. Test error handling on step failure

**Validation and Inspection**

1. Create stacks with various configurations
2. Run atmos validate stacks
3. Run atmos describe stacks
4. Verify output correctness

### Testing Tools

- **Atmos**: `atmos validate stacks`, `atmos describe component`
- **YAML**: `yamllint`, `yq` for parsing and validation
- **Packer**: `packer validate`, `packer fmt`
- **OpenTofu**: `tofu validate`, `tofu fmt`
- **Property Testing**: fast-check (for validation scripts)
- **Shell Scripts**: ShellCheck, BATS

### Continuous Validation

Update the `preflight.sh` script to include Atmos validation:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "==> Atmos configuration validation"
atmos validate stacks

echo "==> Atmos stack description"
atmos describe stacks --format yaml > /dev/null

echo "==> Formatting checks"
packer fmt -check -recursive components/packer/
tofu fmt -check -recursive components/terraform/

echo "==> Packer validation"
atmos packer validate alma9-k3s-optimized -s pve-prod

echo "==> OpenTofu validation"
atmos terraform validate k3s-cluster -s pve-prod

echo "==> Kubernetes manifest validation"
kustomize build k8s/clusters/home/bootstrap > /dev/null
kustomize build k8s/clusters/home/infra > /dev/null

echo "==> YAML linting"
find stacks -name "*.yaml" -exec yamllint {} \;
find k8s -name "*.yaml" -exec yamllint {} \;

echo "==> Shell script linting"
find scripts -name "*.sh" -exec shellcheck {} \;

echo "✓ All preflight checks passed"
```

## Implementation Notes

### Migration Strategy

**Phase 1: Repository Restructuring**

1. Create new directory structure (components/, stacks/)
2. Move Packer templates to components/packer/
3. Move OpenTofu modules to components/terraform/
4. Keep k8s/ directory unchanged
5. Update .gitignore for new structure

**Phase 2: Atmos Configuration**

1. Create atmos.yaml with base paths
2. Configure Packer and OpenTofu commands
3. Set up stack base path and patterns
4. Enable template processing

**Phase 3: Catalog Creation**

1. Create stacks/catalog/proxmox.yaml
2. Extract common variables from existing configs
3. Define component metadata
4. Document variable purposes

**Phase 4: Stack Creation**

1. Create stacks/deploy/pve-prod.yaml
2. Import catalog configuration
3. Define component-specific variables
4. Configure backend settings

**Phase 5: Component Updates**

1. Update Packer variables to match stack structure
2. Update OpenTofu variables to match stack structure
3. Remove environment-specific variable files
4. Test component validation

**Phase 6: Workflow Creation**

1. Create workflow definitions in stacks/workflows/
2. Define build, deploy, and bootstrap workflows
3. Create end-to-end deployment workflow
4. Test workflow execution

**Phase 7: Documentation**

1. Update README with Atmos instructions
2. Document stack structure and inheritance
3. Provide workflow examples
4. Create troubleshooting guide

### Atmos Best Practices

**Stack Organization**

- Use catalog for reusable base configurations
- Keep deployment stacks focused and minimal
- Use clear, descriptive stack names
- Document stack purpose and dependencies

**Variable Management**

- Define variables at the appropriate level (catalog vs stack)
- Use template expressions for dynamic values
- Keep sensitive values in environment variables
- Document variable purposes and types

**Component Design**

- Keep components generic and reusable
- Use stack variables for environment-specific values
- Avoid hardcoding values in components
- Provide clear variable descriptions

**Workflow Design**

- Keep workflows focused on specific tasks
- Use descriptive step names
- Add verification steps between major operations
- Handle errors gracefully

### Security Considerations

**Secrets Management**

- Never commit secrets to Git
- Use environment variables for sensitive values
- Reference secrets using ${ENV_VAR} syntax
- Document required environment variables

**API Credentials**

- Use API tokens instead of passwords
- Limit token scope to required permissions
- Rotate tokens regularly
- Store tokens in secure secret managers

**State File Security**

- Use remote backend with encryption
- Enable state locking
- Restrict access to state files
- Backup state files securely

### Operational Considerations

**Stack Validation**

- Run `atmos validate stacks` before deployments
- Use `atmos describe component` to verify configurations
- Test changes in non-production stacks first
- Keep validation in CI/CD pipeline

**Component Updates**

- Test component changes with `atmos terraform plan`
- Validate Packer templates before building
- Use version control for component changes
- Document breaking changes

**Workflow Execution**

- Monitor workflow execution for failures
- Log workflow output for debugging
- Implement retry logic for transient failures
- Document manual intervention procedures

**Backup and Recovery**

- Backup stack configurations regularly
- Version control all Atmos configurations
- Document recovery procedures
- Test backup restoration

### Performance Considerations

**Stack Loading**

- Minimize import depth to reduce loading time
- Cache resolved stack configurations
- Use efficient YAML parsing
- Profile stack loading for large configurations

**Component Execution**

- Parallelize independent component operations
- Use caching for Packer builds
- Optimize OpenTofu provider configuration
- Monitor execution times

**Workflow Optimization**

- Minimize wait times between steps
- Use conditional execution where appropriate
- Parallelize independent workflow steps
- Cache workflow artifacts

### Troubleshooting

**Common Issues**

1. **Stack validation fails**: Check YAML syntax, import paths, component references
2. **Variable not found**: Verify variable is defined in stack or catalog
3. **Component not found**: Check component directory exists and is named correctly
4. **Backend configuration error**: Verify backend settings in stack manifest
5. **Workflow step fails**: Check command syntax and tool availability

**Debug Commands**

```bash
# Validate stack configuration
atmos validate stacks --stack pve-prod

# Describe component configuration
atmos describe component k3s-cluster -s pve-prod --format yaml

# List all components in stack
atmos list components -s pve-prod

# Show Atmos version and configuration
atmos version
atmos describe config

# Enable debug logging
export ATMOS_LOGS_LEVEL=Debug
atmos terraform plan k3s-cluster -s pve-prod
```

**Log Locations**

- Atmos logs: stderr (configured in atmos.yaml)
- Packer logs: components/packer/\*/packer.log
- OpenTofu logs: components/terraform/\*/.terraform/
- Workflow logs: stdout during execution
