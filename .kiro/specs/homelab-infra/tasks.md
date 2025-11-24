# Implementation Plan

- [ ] 1. Set up repository structure and documentation

  - Create root directory structure with packer/, terraform/, k8s/, scripts/ folders
  - Create .gitignore file excluding Packer output, OpenTofu state, and secrets
  - Create README.md with prerequisites, quickstart instructions, and usage examples
  - _Requirements: 7.1, 7.4_

- [ ] 2. Implement Packer image builder for AlmaLinux 9 + k3s

  - Create packer/alma9-k3s-optimized directory structure
  - _Requirements: 1.1, 8.4, 8.5_

- [ ] 2.1 Create Packer variables configuration

  - Write packer/alma9-k3s-optimized/variables.pkr.hcl with image_version, proxmox_url, proxmox_username, proxmox_token, proxmox_node, alma_iso_url, k3s_version variables
  - Include TODO comments for Proxmox API credentials and ISO URL
  - _Requirements: 1.5, 7.2, 7.3_

- [ ] 2.2 Create Packer builder configuration

  - Write packer/alma9-k3s-optimized/packer.pkr.hcl with proxmox-iso builder
  - Configure UEFI firmware, q35 machine type, and QEMU guest agent
  - Set up HTTP server for kickstart file delivery
  - Configure template conversion with proper naming
  - _Requirements: 1.1, 1.2, 1.4, 1.5, 9.1, 9.2, 9.3, 9.4, 9.5_

- [ ] 2.3 Create kickstart configuration for automated installation

  - Write packer/alma9-k3s-optimized/http/ks.cfg for unattended AlmaLinux installation
  - Configure partitioning, networking, and base packages
  - _Requirements: 1.1, 1.3_

- [ ] 2.4 Create OS update provisioning script

  - Write packer/alma9-k3s-optimized/scripts/os-update.sh
  - Install system updates, timezone configuration, and basic tooling
  - _Requirements: 1.3_

- [ ] 2.5 Create guest agent provisioning script

  - Write packer/alma9-k3s-optimized/scripts/guest-agent.sh
  - Install and enable qemu-guest-agent
  - _Requirements: 1.3, 9.2_

- [ ] 2.6 Create k3s installation provisioning script

  - Write packer/alma9-k3s-optimized/scripts/k3s-install.sh
  - Install k3s server with Traefik disabled
  - Enable k3s systemd service
  - Verify k3s binary is executable
  - _Requirements: 1.3, 2.1, 2.2, 2.3, 2.4_

- [ ] 2.7 Create security hardening stub script

  - Write packer/alma9-k3s-optimized/scripts/hardening-oscap.sh with commented commands
  - Include comments explaining how to enable OpenSCAP hardening
  - _Requirements: 8.1, 8.2_

- [ ] 2.8 Create common Packer configuration

  - Write packer/common.pkr.hcl with shared locals for image naming
  - _Requirements: 1.5_

- [ ] 3. Implement OpenTofu infrastructure provisioning

  - Create terraform/modules/proxmox-vm directory
  - Create terraform/envs/k3s-single directory
  - _Requirements: 3.1, 4.1_

- [ ] 3.1 Create reusable Proxmox VM module

  - Write terraform/modules/proxmox-vm/variables.tf with all required inputs
  - Write terraform/modules/proxmox-vm/main.tf with proxmox_vm_qemu resource
  - Configure SCSI disk with SSD emulation and discard enabled
  - Configure virtio network interface
  - Configure cloud-init with ciuser, sshkeys, ipconfig0, nameserver
  - Add create_before_destroy lifecycle policy
  - Write terraform/modules/proxmox-vm/outputs.tf with vm_id and ip_address
  - _Requirements: 3.2, 3.3, 4.1, 4.2, 4.3, 4.4, 4.5_

- [ ] 3.2 Create k3s-single environment configuration

  - Write terraform/envs/k3s-single/variables.tf
  - Write terraform/envs/k3s-single/main.tf with provider configuration and module invocation
  - Configure VM with 4 cores, 24GB RAM, static IP 10.23.45.31/24
  - Write terraform/envs/k3s-single/outputs.tf with VM IP and kubectl context info
  - Write terraform/envs/k3s-single/terraform.tfvars.example with documented defaults
  - _Requirements: 3.1, 3.4, 3.5, 7.2, 7.3_

- [ ] 3.3 Create global OpenTofu variables file

  - Write terraform/globals.tfvars.example with common variables
  - Include TODO comments for environment-specific values
  - _Requirements: 7.2, 7.3_

- [ ] 4. Implement Kubernetes manifests and GitOps configuration

  - Create k8s/argo directory
  - Create k8s/clusters/home directory structure
  - _Requirements: 5.3_

- [ ] 4.1 Create Argo CD bootstrap manifests

  - Write k8s/clusters/home/bootstrap/argocd-install.yaml with upstream Argo CD installation
  - Add NOTE comment about default admin password retrieval
  - Write k8s/clusters/home/bootstrap/kustomization.yaml
  - _Requirements: 5.1_

- [ ] 4.2 Create Argo CD app-of-apps configuration

  - Write k8s/argo/app-of-apps.yaml with root Application pointing to k8s/clusters/home
  - Configure automated sync with prune and selfHeal enabled
  - Write k8s/argo/projects/default-project.yaml
  - _Requirements: 5.2_

- [ ] 4.3 Create root kustomization for home cluster

  - Write k8s/clusters/home/kustomization.yaml referencing bootstrap/, infra/, and apps/
  - _Requirements: 5.3, 5.4_

- [ ] 4.4 Create phpIPAM example application manifests

  - Write k8s/clusters/home/infra/phpipam/namespace.yaml for ipam namespace
  - Write k8s/clusters/home/infra/phpipam/kustomization.yaml with Helm chart configuration
  - Write k8s/clusters/home/infra/phpipam/values.yaml with minimal settings and TODO comments for MetalLB IP, domain, and passwords
  - _Requirements: 5.5, 10.1, 10.2, 10.3, 10.4, 10.5_

- [ ] 4.5 Create infrastructure and apps kustomizations

  - Write k8s/clusters/home/infra/kustomization.yaml
  - Write k8s/clusters/home/apps/kustomization.yaml
  - _Requirements: 5.3_

- [ ] 5. Create Makefile for workflow orchestration

  - Write Makefile with IMAGE_VERSION, K3S_VERSION, and ENV variables
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [ ] 5.1 Implement Packer build target

  - Create packer target that initializes and builds the image
  - _Requirements: 6.1_

- [ ] 5.2 Implement OpenTofu targets

  - Create tf-init, tf-plan, tf-apply, and tf-destroy targets
  - _Requirements: 6.2, 6.3_

- [ ] 5.3 Implement Kubernetes targets

  - Create k8s-bootstrap target for applying bootstrap manifests
  - Create argo target for applying app-of-apps
  - _Requirements: 6.4, 6.5_

- [ ] 5.4 Implement utility targets

  - Create preflight target for validation
  - Create clean target for removing build artifacts
  - _Requirements: 8.3_

- [ ] 6. Create helper scripts

  - Create scripts directory
  - _Requirements: 8.3_

- [ ] 6.1 Create preflight validation script

  - Write scripts/preflight.sh with stubs for format, validate, and lint operations
  - Include packer fmt/validate checks
  - Include tofu fmt/validate checks
  - Include kustomize build checks
  - Include shellcheck for shell scripts
  - Include yamllint for YAML files
  - _Requirements: 8.3_

- [ ] 7. Final checkpoint - Verify all components
  - Ensure all tests pass, ask the user if questions arise
  - Verify Packer configuration is valid
  - Verify OpenTofu configuration is valid
  - Verify Kubernetes manifests render correctly
  - Verify Makefile targets are functional
  - Verify documentation is complete
