# =============================================================================
# cloudflared-lxc Environment - Main Configuration
#
# This is the main entry point for the cloudflared LXC Terraform environment.
# It orchestrates the creation of:
#   - Proxmox LXC container running cloudflared
#   - Cloudflare tunnel and DNS records
#
# Usage:
#   cd terraform/envs/cloudflared_lxc
#   tofu init
#   tofu plan -var-file=terraform.tfvars
#   tofu apply -var-file=terraform.tfvars
#
# =============================================================================

# The terraform block and providers are defined in providers.tf

# Resources are organized in separate files:
#   - lxc.tf       - Proxmox LXC container
#   - cloudflare.tf - Cloudflare tunnel and DNS
#   - locals.tf    - Computed values
#   - variables.tf - Input variables
#   - outputs.tf   - Output values
