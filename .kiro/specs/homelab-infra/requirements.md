# Requirements Document

## Introduction

This document specifies the requirements for a homelab infrastructure repository that automates the creation of k3s-optimized virtual machine images using Packer, deploys infrastructure using OpenTofu on Proxmox, and manages Kubernetes workloads using Kustomize and Argo CD. The system bakes k3s directly into the AlmaLinux 9 VM image for faster boot times and consistent k3s versions across deployments.

## Glossary

- **Packer**: HashiCorp tool for creating machine images from configuration files
- **OpenTofu**: Open-source infrastructure-as-code tool for provisioning and managing infrastructure (Terraform fork)
- **Proxmox**: Open-source virtualization platform
- **k3s**: Lightweight Kubernetes distribution
- **Kustomize**: Kubernetes native configuration management tool
- **Argo CD**: GitOps continuous delivery tool for Kubernetes
- **Cloud-init**: Industry-standard method for cloud instance initialization
- **QEMU**: Open-source machine emulator and virtualizer
- **Golden Image**: Pre-configured VM template ready for cloning with k3s pre-installed
- **Homelab System**: The complete infrastructure automation system including Packer, OpenTofu, and Kubernetes components
- **Image Builder**: The Packer-based subsystem that creates k3s-optimized VM images
- **Infrastructure Provisioner**: The OpenTofu-based subsystem that deploys VMs
- **Kubernetes Manager**: The Kustomize and Argo CD subsystem that manages workloads
- **Image Version**: Semantic version string in format alma{version}-k3-node-{arch}-{k3s-version}-v{distribution-release}

## Requirements

### Requirement 1

**User Story:** As a homelab administrator, I want to build k3s-optimized AlmaLinux 9 golden images with Packer, so that I can deploy consistent VM templates to Proxmox with k3s pre-installed.

#### Acceptance Criteria

1. WHEN the Image Builder executes a build THEN the Homelab System SHALL create a QEMU-based AlmaLinux 9 image with UEFI firmware
2. WHEN the Image Builder completes a build THEN the Homelab System SHALL produce a qcow2 disk image file
3. WHEN the Image Builder provisions the image THEN the Homelab System SHALL install OS updates, qemu-guest-agent, and k3s server
4. WHEN the Image Builder uploads the image THEN the Homelab System SHALL transfer the qcow2 file to Proxmox via SSH and create a VM template
5. WHEN the Image Builder creates a template THEN the Homelab System SHALL name the template using the format alma{version}-k3-node-{arch}-{k3s-version}-v{distribution-release}

### Requirement 2

**User Story:** As a homelab administrator, I want k3s pre-installed and configured in the golden image, so that VMs boot quickly with a ready-to-use Kubernetes cluster.

#### Acceptance Criteria

1. WHEN the Image Builder provisions the image THEN the Homelab System SHALL install k3s server with Traefik ingress controller disabled
2. WHEN the Image Builder installs k3s THEN the Homelab System SHALL enable the k3s systemd service for automatic startup
3. WHEN the Image Builder completes k3s installation THEN the Homelab System SHALL verify the k3s binary is present and executable
4. WHEN a VM boots from the golden image THEN the Homelab System SHALL start k3s automatically without additional provisioning
5. WHEN the Image Builder stores k3s version information THEN the Homelab System SHALL include the k3s version in the image name

### Requirement 3

**User Story:** As a homelab administrator, I want to deploy VMs to Proxmox using OpenTofu, so that I can provision infrastructure declaratively with open-source tooling.

#### Acceptance Criteria

1. WHEN the Infrastructure Provisioner creates a VM THEN the Homelab System SHALL clone the VM from the specified golden image template
2. WHEN the Infrastructure Provisioner configures a VM THEN the Homelab System SHALL apply cloud-init settings for hostname, IP address, gateway, nameserver, and SSH keys
3. WHEN the Infrastructure Provisioner updates a VM resource THEN the Homelab System SHALL use create_before_destroy lifecycle policy
4. WHEN the Infrastructure Provisioner deploys the k3s-single environment THEN the Homelab System SHALL create one VM with 4 cores, 24GB RAM, and a static IP address
5. WHEN the Infrastructure Provisioner completes deployment THEN the Homelab System SHALL output the VM IP address and kubectl context information

### Requirement 4

**User Story:** As a homelab administrator, I want a reusable OpenTofu module for Proxmox VMs, so that I can deploy multiple environments with consistent configuration.

#### Acceptance Criteria

1. WHEN the proxmox-vm module is invoked THEN the Homelab System SHALL accept parameters for name, template, node, storage, bridge, cores, memory, disk_size, networking, and cloud-init configuration
2. WHEN the proxmox-vm module creates a VM THEN the Homelab System SHALL configure one SCSI disk with SSD emulation and discard enabled
3. WHEN the proxmox-vm module creates a VM THEN the Homelab System SHALL configure one virtio network interface on the specified bridge
4. WHEN the proxmox-vm module receives optional user_data THEN the Homelab System SHALL configure cloud-init to use the custom user-data snippet
5. WHEN the proxmox-vm module completes THEN the Homelab System SHALL output the VM ID and IP address

### Requirement 5

**User Story:** As a homelab administrator, I want to manage Kubernetes workloads using Kustomize and Argo CD, so that I can implement GitOps practices.

#### Acceptance Criteria

1. WHEN the Kubernetes Manager bootstraps a cluster THEN the Homelab System SHALL install Argo CD using upstream manifests
2. WHEN the Kubernetes Manager deploys the app-of-apps pattern THEN the Homelab System SHALL configure Argo CD to automatically sync, prune, and self-heal applications
3. WHEN the Kubernetes Manager organizes manifests THEN the Homelab System SHALL structure them into bootstrap, infra, and apps directories
4. WHEN the Kubernetes Manager renders manifests THEN the Homelab System SHALL use Kustomize to compose the final configuration
5. WHEN the Kubernetes Manager deploys the phpIPAM example application THEN the Homelab System SHALL create the necessary namespace, deployment, and service resources

### Requirement 6

**User Story:** As a homelab administrator, I want a Makefile to orchestrate build and deployment tasks, so that I can execute complex workflows with simple commands.

#### Acceptance Criteria

1. WHEN the make packer target is invoked THEN the Homelab System SHALL initialize Packer and build the image with the specified IMAGE_VERSION
2. WHEN the make tf-apply target is invoked THEN the Homelab System SHALL apply OpenTofu configuration for the specified ENV
3. WHEN the make tf-destroy target is invoked THEN the Homelab System SHALL destroy OpenTofu-managed resources for the specified ENV
4. WHEN the make k8s-bootstrap target is invoked THEN the Homelab System SHALL apply Kustomize manifests from the bootstrap directory
5. WHEN the make argo target is invoked THEN the Homelab System SHALL apply the app-of-apps root application

### Requirement 7

**User Story:** As a homelab administrator, I want clear documentation and examples for configuration, so that I can customize the system for my environment.

#### Acceptance Criteria

1. WHEN the repository is cloned THEN the Homelab System SHALL include a README with prerequisites, quickstart instructions, and usage examples
2. WHEN OpenTofu variables require customization THEN the Homelab System SHALL provide terraform.tfvars.example files with documented defaults
3. WHEN secrets or environment-specific values are needed THEN the Homelab System SHALL include TODO comments indicating where to insert them
4. WHEN the .gitignore file is present THEN the Homelab System SHALL exclude Packer output, OpenTofu state, and secret files from version control
5. WHEN configuration files contain placeholders THEN the Homelab System SHALL use clear naming conventions like TODO or CHANGEME

### Requirement 8

**User Story:** As a homelab administrator, I want stub implementations for security hardening, so that I can extend the system later.

#### Acceptance Criteria

1. WHEN the Image Builder provisions an image THEN the Homelab System SHALL include a stub script for OpenSCAP hardening with commented commands
2. WHEN stub scripts are present THEN the Homelab System SHALL include comments explaining how to enable or extend them
3. WHEN the preflight script is invoked THEN the Homelab System SHALL provide stubs for format, validate, and lint operations
4. WHEN the Image Builder organizes provisioning scripts THEN the Homelab System SHALL place them in the packer/alma9-k3s-optimized/scripts directory
5. WHEN the Image Builder references the image directory THEN the Homelab System SHALL use the path packer/alma9-k3s-optimized

### Requirement 9

**User Story:** As a homelab administrator, I want Packer to create VM templates directly on Proxmox, so that images are immediately ready for OpenTofu to use.

#### Acceptance Criteria

1. WHEN the Image Builder connects to Proxmox THEN the Homelab System SHALL use the Proxmox API for authentication and VM operations
2. WHEN the Image Builder creates a VM THEN the Homelab System SHALL configure the VM with UEFI BIOS, q35 machine type, and QEMU guest agent enabled
3. WHEN the Image Builder completes provisioning THEN the Homelab System SHALL convert the VM to a template on Proxmox
4. WHEN the Image Builder finishes THEN the Homelab System SHALL output the template name for use by OpenTofu
5. WHEN the Image Builder serves installation files THEN the Homelab System SHALL use HTTP to provide kickstart configuration to the VM

### Requirement 10

**User Story:** As a homelab administrator, I want the phpIPAM example application to demonstrate Kubernetes Helm chart deployment patterns, so that I can learn how to deploy similar applications.

#### Acceptance Criteria

1. WHEN the phpIPAM application is deployed THEN the Homelab System SHALL create a dedicated namespace
2. WHEN the phpIPAM application is deployed THEN the Homelab System SHALL use the official phpIPAM Helm chart version 1.0.1
3. WHEN the phpIPAM application configuration is provided THEN the Homelab System SHALL include a values.yaml file with minimal settings and TODO comments for MetalLB IP, domain, and passwords
4. WHEN the phpIPAM Helm chart is deployed THEN the Homelab System SHALL include MariaDB database as part of the chart dependencies
5. WHEN the phpIPAM application is accessed THEN the Homelab System SHALL expose it via a ClusterIP service with TODO comments for LoadBalancer configuration
