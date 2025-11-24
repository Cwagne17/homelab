# Implementation Plan

- [ ] 1. Set up Atmos configuration and repository structure

  - Create atmos.yaml with base paths for components and stacks
  - Configure Packer and OpenTofu commands in atmos.yaml
  - Enable template processing with Sprig and Gomplate
  - Create directory structure: components/terraform, components/packer, stacks/catalog, stacks/deploy, stacks/workflows
  - Update .gitignore for new Atmos structure
  - _Requirements: 1.1, 1.2, 1.3, 4.1, 5.1_

- [ ]\* 1.1 Write property test for atmos.yaml structure validation

  - **Property 1: Stack manifest structure validity**
  - **Validates: Requirements 2.1**

- [ ] 2. Migrate Packer component to Atmos structure

  - Move packer/alma9-k3s-optimized to components/packer/alma9-k3s-optimized
  - Update Packer variables to use Atmos-injected values
  - Remove environment-specific .pkrvars.hcl files
  - Keep provisioning scripts and HTTP files unchanged
  - Test Packer component structure
  - _Requirements: 1.5, 4.2_

- [ ]\* 2.1 Write property test for Packer variable injection

  - **Property 6: Variable injection for Packer builds**
  - **Validates: Requirements 4.4**

- [ ] 3. Migrate OpenTofu component to Atmos structure

  - Create components/terraform/k3s-cluster as root module
  - Move VM configuration from terraform/envs/k3s-single
  - Update variables to use Atmos-injected values
  - Remove environment-specific .tfvars files
  - Configure Proxmox provider
  - Define outputs for VM ID, IP, and kubeconfig command
  - _Requirements: 1.4, 5.2_

- [ ]\* 3.1 Write property test for OpenTofu variable and backend injection

  - **Property 7: Variable injection for OpenTofu deployments**
  - **Validates: Requirements 5.4**

- [ ] 4. Create catalog configuration for Proxmox

  - Create stacks/catalog/proxmox.yaml
  - Define common Proxmox connection variables (URL, node, storage, bridge)
  - Define network settings (gateway, nameserver, CIDR)
  - Define k3s version and VM resource defaults
  - Define Packer image settings (AlmaLinux version, ISO URL, architecture)
  - Add component metadata for k3s-cluster and alma9-k3s-optimized
  - _Requirements: 3.1, 3.2, 3.5_

- [ ]\* 4.1 Write property test for catalog configuration structure

  - **Property 5: Catalog configuration structure**
  - **Validates: Requirements 3.2**

- [ ] 5. Create pve-prod deployment stack

  - Create stacks/deploy/pve-prod.yaml
  - Import catalog/proxmox configuration
  - Define environment variable (pve-prod)
  - Configure k3s-cluster component with VM specifications
  - Configure alma9-k3s-optimized component with Packer settings
  - Set up backend configuration for OpenTofu state
  - Add TODO comments for secrets and SSH keys
  - _Requirements: 2.2, 2.3, 4.3, 5.3_

- [ ]\* 5.1 Write property test for stack inheritance and merging

  - **Property 2: Stack inheritance and merging**
  - **Validates: Requirements 2.3, 3.3**

- [ ]\* 5.2 Write property test for component reference validity

  - **Property 4: Component reference validity**
  - **Validates: Requirements 2.5**

- [ ] 6. Implement stack validation

  - Test atmos validate stacks command
  - Verify YAML syntax validation
  - Verify import resolution
  - Verify component reference validation
  - Test error reporting with intentional errors
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [ ]\* 6.1 Write property test for validation behavior

  - **Property 10: Stack validation - YAML syntax**
  - **Property 11: Stack validation - import resolution**
  - **Property 12: Stack validation - component existence**
  - **Property 13: Validation error reporting**
  - **Validates: Requirements 8.2, 8.3, 8.4, 8.5**

- [ ] 7. Implement stack inspection commands

  - Test atmos describe stacks command
  - Test atmos describe component command for k3s-cluster
  - Test atmos describe component command for alma9-k3s-optimized
  - Verify inherited variables are displayed
  - Verify backend configuration is displayed
  - Test output format flags (--format yaml, --format json)
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

- [ ]\* 7.1 Write property test for component description completeness

  - **Property 14: Component description completeness**
  - **Property 15: Backend configuration display**
  - **Validates: Requirements 9.2, 9.3, 9.4**

- [ ]\* 7.2 Write property test for output format compliance

  - **Property 16: Output format compliance**
  - **Validates: Requirements 9.5**

- [ ] 8. Test Packer component with Atmos

  - Run atmos packer validate alma9-k3s-optimized -s pve-prod
  - Run atmos packer init alma9-k3s-optimized -s pve-prod
  - Verify variables are injected from stack manifest
  - Document Packer commands in README
  - _Requirements: 4.4, 4.5_

- [ ] 9. Test OpenTofu component with Atmos

  - Run atmos terraform validate k3s-cluster -s pve-prod
  - Run atmos terraform plan k3s-cluster -s pve-prod
  - Verify variables are injected from stack manifest
  - Verify backend configuration is used
  - Document OpenTofu commands in README
  - _Requirements: 5.4, 5.5_

- [ ] 10. Create Packer build workflow

  - Create stacks/workflows/packer.yaml
  - Define build-image workflow with validate, init, and build steps
  - Test workflow execution
  - _Requirements: 6.1, 6.5_

- [ ] 11. Create infrastructure deployment workflow

  - Create stacks/workflows/infrastructure.yaml
  - Define deploy-infrastructure workflow with validate, plan, and apply steps
  - Define destroy-infrastructure workflow
  - Test workflow execution
  - _Requirements: 6.5_

- [ ] 12. Create Kubernetes bootstrap workflow

  - Create stacks/workflows/kubernetes.yaml
  - Define k8s-bootstrap workflow with kubectl apply steps
  - Define argo-deploy workflow for app-of-apps
  - Configure kubeconfig usage
  - Test workflow execution
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [ ]\* 12.1 Write property test for workflow file organization

  - **Property 17: Workflow file organization**
  - **Validates: Requirements 6.5**

- [ ] 13. Create end-to-end deployment workflow

  - Create stacks/workflows/deploy.yaml
  - Define deploy-homelab workflow chaining Packer, OpenTofu, and Kubernetes steps
  - Add verification steps between major operations
  - Add wait steps for VM boot and service startup
  - Test workflow execution
  - Test error handling on step failure
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [ ]\* 13.1 Write property test for workflow error handling

  - **Property 8: Workflow error handling**
  - **Validates: Requirements 7.3**

- [ ]\* 13.2 Write property test for workflow step verification

  - **Property 9: Workflow step verification**
  - **Validates: Requirements 7.5**

- [ ] 14. Update documentation

  - Update README with Atmos installation instructions
  - Document atmos.yaml configuration
  - Document stack structure and inheritance
  - Document catalog usage
  - Provide examples of atmos workflow commands
  - Document how to create new environment stacks
  - Document folder structure (components, stacks, workflows)
  - Provide examples of variable overrides
  - Add troubleshooting section
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

- [ ] 15. Update preflight script

  - Add atmos validate stacks to preflight checks
  - Add atmos describe stacks validation
  - Add Atmos-based Packer and OpenTofu validation
  - Update formatting checks for new structure
  - Test preflight script execution

- [ ] 16. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.
