# Requirements Document

## Introduction

This document specifies the requirements for integrating Atmos, an Infrastructure-as-Code orchestration tool, into the existing homelab infrastructure repository. The system will migrate the current OpenTofu configuration to follow Atmos folder structure conventions, implement Atmos stacks for environment management, and leverage Atmos workflows for orchestrating Packer builds, infrastructure provisioning, and Kubernetes deployments. This integration builds upon the existing homelab-infra implementation.

## Glossary

- **Atmos**: Universal tool for DevOps and cloud automation that orchestrates workflows and manages configurations across multiple environments
- **Atmos Stack**: A configuration file that defines component instances, variables, and settings for a specific environment
- **Atmos Component**: A reusable infrastructure unit (typically an OpenTofu module, Packer template, or Helm chart) managed by Atmos
- **Atmos Workflow**: A sequence of commands and steps defined in YAML that automate complex operations
- **Stack Manifest**: YAML file in the stacks directory that defines infrastructure configuration for environments
- **Component Manifest**: Configuration defining how a component should be deployed in a specific stack
- **Atmos CLI**: Command-line interface for executing Atmos commands and workflows
- **Homelab System**: The complete infrastructure automation system including Packer, OpenTofu, Atmos, and Kubernetes components
- **Stack Inheritance**: Atmos feature allowing stacks to import and override configuration from other stacks
- **Atmos Vendoring**: Process of pulling external components and configurations into the repository
- **Backend Configuration**: Settings for OpenTofu state storage managed by Atmos
- **Packer Component**: A Packer template managed by Atmos with stack-based variable injection
- **OpenTofu Component**: An OpenTofu root module managed by Atmos with stack-based configuration

## Requirements

### Requirement 1

**User Story:** As a homelab administrator, I want to migrate the existing OpenTofu configuration to Atmos folder structure, so that I can leverage Atmos orchestration capabilities.

#### Acceptance Criteria

1. WHEN the Homelab System organizes components THEN the Homelab System SHALL place OpenTofu modules in the components/terraform directory and Packer templates in the components/packer directory
2. WHEN the Homelab System structures the repository THEN the Homelab System SHALL create stacks/deploy for deployable stack configurations
3. WHEN the Homelab System configures Atmos THEN the Homelab System SHALL create an atmos.yaml file in the repository root with base_path settings for terraform, packer, and stacks
4. WHEN the Homelab System migrates the proxmox-vm module THEN the Homelab System SHALL move it to components/terraform/proxmox-vm as a root module
5. WHEN the Homelab System migrates the Packer configuration THEN the Homelab System SHALL move packer/alma9-k3s-optimized to components/packer/alma9-k3s-optimized

### Requirement 2

**User Story:** As a homelab administrator, I want an Atmos stack manifest for my Proxmox environment, so that I can manage my homelab infrastructure with consistent configuration patterns.

#### Acceptance Criteria

1. WHEN the Homelab System creates a stack manifest THEN the Homelab System SHALL define the stack in YAML format with components section containing component configurations
2. WHEN the Homelab System defines the pve-prod stack THEN the Homelab System SHALL place it in stacks/deploy/pve-prod.yaml with configurations for both Packer and OpenTofu components
3. WHEN the Homelab System organizes stacks THEN the Homelab System SHALL support stack inheritance using the import directive to reference catalog configurations
4. WHEN the Homelab System configures backend settings THEN the Homelab System SHALL define OpenTofu backend configuration in the component's backend section
5. WHEN the Homelab System references components THEN the Homelab System SHALL use the component key to map to the directory path in components/terraform or components/packer

### Requirement 3

**User Story:** As a homelab administrator, I want a catalog configuration for common Proxmox settings, so that I can maintain reusable configuration that can be extended in the future.

#### Acceptance Criteria

1. WHEN the Homelab System creates a catalog configuration THEN the Homelab System SHALL place it in stacks/catalog/proxmox.yaml with common variables for Proxmox connection, storage, and network settings
2. WHEN the Homelab System defines the catalog configuration THEN the Homelab System SHALL use the vars section to specify default values for VM resources and Packer image settings
3. WHEN the pve-prod stack imports the catalog configuration THEN the Homelab System SHALL merge the configurations with stack-specific values taking precedence using deep merge strategy
4. WHEN the Homelab System organizes catalog configurations THEN the Homelab System SHALL create logical groupings for Proxmox-related settings including connection details and resource defaults
5. WHEN the Homelab System defines global settings THEN the Homelab System SHALL include Proxmox API endpoint, node name, storage pool, network bridge, and k3s version in the catalog configuration

### Requirement 4

**User Story:** As a homelab administrator, I want to manage Packer builds through Atmos components and stacks, so that I can build k3s-optimized images with stack-based variable injection.

#### Acceptance Criteria

1. WHEN the Homelab System configures Packer in atmos.yaml THEN the Homelab System SHALL set components.packer.command to packer and components.packer.base_path to components/packer
2. WHEN the Homelab System creates a Packer component THEN the Homelab System SHALL place the template in components/packer/alma9-k3s-optimized with variables for Proxmox connection, k3s version, and image configuration
3. WHEN the Homelab System defines the pve-prod stack THEN the Homelab System SHALL include the alma9-k3s-optimized component configuration with Proxmox-specific variables
4. WHEN the Homelab System executes atmos packer build alma9-k3s-optimized -s pve-prod THEN the Homelab System SHALL inject variables from the stack manifest into the Packer template
5. WHEN the Homelab System validates Packer configuration THEN the Homelab System SHALL support atmos packer validate alma9-k3s-optimized -s pve-prod command

### Requirement 5

**User Story:** As a homelab administrator, I want to manage OpenTofu operations through Atmos components and stacks, so that I can deploy VMs to my Proxmox environment using stack-aware commands.

#### Acceptance Criteria

1. WHEN the Homelab System configures OpenTofu in atmos.yaml THEN the Homelab System SHALL set components.terraform.command to tofu, components.terraform.base_path to components/terraform, and components.terraform.init.pass_vars to true
2. WHEN the Homelab System creates an OpenTofu component THEN the Homelab System SHALL place the root module in components/terraform/k3s-cluster with variables for VM configuration and k3s setup
3. WHEN the Homelab System defines the pve-prod stack THEN the Homelab System SHALL include the k3s-cluster component configuration with VM specifications for the single-node cluster
4. WHEN the Homelab System executes atmos terraform apply k3s-cluster -s pve-prod THEN the Homelab System SHALL inject variables from the stack manifest and use the backend configuration from the component section
5. WHEN the Homelab System manages OpenTofu state THEN the Homelab System SHALL use backend configuration defined in the component's backend section of the stack manifest

### Requirement 6

**User Story:** As a homelab administrator, I want Atmos workflows to orchestrate Kubernetes deployments, so that I can bootstrap clusters and deploy applications through Atmos.

#### Acceptance Criteria

1. WHEN the Homelab System defines a k8s-bootstrap workflow THEN the Homelab System SHALL create it in stacks/workflows/kubernetes.yaml with steps that execute kubectl apply commands for Kustomize manifests
2. WHEN the k8s-bootstrap workflow runs THEN the Homelab System SHALL apply manifests from the k8s/bootstrap directory
3. WHEN the Homelab System defines an argo-deploy workflow THEN the Homelab System SHALL apply the app-of-apps root application
4. WHEN Kubernetes workflows execute THEN the Homelab System SHALL use the kubeconfig from the deployed infrastructure
5. WHEN the Homelab System organizes Kubernetes workflows THEN the Homelab System SHALL place workflow definitions in stacks/workflows directory as separate YAML files

### Requirement 7

**User Story:** As a homelab administrator, I want an end-to-end workflow that orchestrates the complete deployment, so that I can provision my homelab infrastructure from image build to application deployment with a single command.

#### Acceptance Criteria

1. WHEN the deploy-homelab workflow is invoked THEN the Homelab System SHALL execute atmos packer build alma9-k3s-optimized, atmos terraform apply k3s-cluster, and kubectl apply steps in sequence for the pve-prod stack
2. WHEN the deploy-homelab workflow executes THEN the Homelab System SHALL use the pve-prod stack for all component operations
3. WHEN a workflow step fails THEN the Homelab System SHALL halt execution and report the error with the failed command details
4. WHEN the deploy-homelab workflow completes successfully THEN the Homelab System SHALL output the deployed infrastructure details including VM IP and kubeconfig path
5. WHEN the Homelab System chains workflow steps THEN the Homelab System SHALL verify the Packer image was created before proceeding to OpenTofu deployment

### Requirement 8

**User Story:** As a homelab administrator, I want Atmos to validate stack configurations, so that I can catch configuration errors before deployment.

#### Acceptance Criteria

1. WHEN the Homelab System validates a stack THEN the Homelab System SHALL execute atmos validate stacks command
2. WHEN stack validation runs THEN the Homelab System SHALL check for syntax errors in YAML manifests
3. WHEN stack validation runs THEN the Homelab System SHALL verify that imported stacks exist
4. WHEN stack validation runs THEN the Homelab System SHALL confirm that referenced components exist in the components directory
5. WHEN validation errors are detected THEN the Homelab System SHALL report the specific stack file and error details

### Requirement 9

**User Story:** As a homelab administrator, I want Atmos to describe stack configurations, so that I can inspect the final merged configuration for any environment.

#### Acceptance Criteria

1. WHEN the atmos describe stacks command is invoked THEN the Homelab System SHALL output the complete merged configuration for all stacks
2. WHEN the atmos describe component command is invoked THEN the Homelab System SHALL display the final configuration for a specific component in a stack
3. WHEN describing a component THEN the Homelab System SHALL show all variables including those inherited from base stacks
4. WHEN describing a component THEN the Homelab System SHALL display the backend configuration that will be used
5. WHEN the Homelab System outputs descriptions THEN the Homelab System SHALL format the output in YAML or JSON based on the specified flag

### Requirement 10

**User Story:** As a homelab administrator, I want updated documentation for the Atmos-based workflow, so that I can understand how to use Atmos commands and workflows.

#### Acceptance Criteria

1. WHEN the repository documentation is updated THEN the Homelab System SHALL include instructions for installing Atmos CLI
2. WHEN the README describes usage THEN the Homelab System SHALL provide examples of atmos workflow commands for common operations
3. WHEN the README describes stack management THEN the Homelab System SHALL explain how to create new environment stacks
4. WHEN the README describes the folder structure THEN the Homelab System SHALL document the purpose of components, stacks, and workflows directories
5. WHEN the documentation provides examples THEN the Homelab System SHALL show how to override variables in environment-specific stacks
