locals {
  # Get the first control plane node's hostname
  first_controlplane_key = [for k, v in var.nodes : k if v.machine_type == "controlplane"][0]
  
  # Extract DHCP IP from VM - MUST be within DHCP CIDR range, no fallback
  get_dhcp_ip = { for k, v in proxmox_virtual_environment_vm.this : k =>
    [for ip in flatten(coalescelist(v.ipv4_addresses, [])) : ip if cidrcontains(var.dhcp_cidr, ip)][0]
  }
  
  # Get the control plane IP - will fail if not available
  control_plane_ip = local.get_dhcp_ip[local.first_controlplane_key]
}

# Generate Talos machine secrets (certificates, tokens, etc.)
resource "talos_machine_secrets" "this" {
  talos_version = var.cluster.talos_version
}

# Generate Talos client configuration (talosconfig)
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster.name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = compact(values(local.get_dhcp_ip))
  endpoints            = [local.control_plane_ip]
}

# Generate machine configuration for each node
data "talos_machine_configuration" "this" {
  for_each = var.nodes

  cluster_name     = var.cluster.name
  cluster_endpoint = "https://${local.control_plane_ip}:6443"
  talos_version    = var.cluster.talos_version
  machine_type     = each.value.machine_type
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  
  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname = each.key
        }
      }
    })
  ]
}

# Wait for QEMU agent to report IPs after VM creation
resource "time_sleep" "wait_for_ips" {
  depends_on = [proxmox_virtual_environment_vm.this]
  
  create_duration = "30s"
}

# Apply machine configuration to each node
resource "talos_machine_configuration_apply" "this" {
  depends_on = [time_sleep.wait_for_ips]

  for_each = var.nodes

  node                        = local.get_dhcp_ip[each.key]
  # For fresh nodes, connect directly to the node (not via control plane endpoint)
  # After initial config, subsequent applies will use control plane endpoint via depends_on
  endpoint                    = local.get_dhcp_ip[each.key]
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration
  
  lifecycle {
    replace_triggered_by = [
      proxmox_virtual_environment_vm.this[each.key].id
    ]
  }
}

# Bootstrap the Talos cluster (run once on first control plane)
resource "talos_machine_bootstrap" "this" {
  node                 = local.control_plane_ip
  client_configuration = talos_machine_secrets.this.client_configuration

  # Ensure control plane is configured before bootstrap
  depends_on = [talos_machine_configuration_apply.this]
}

# Wait for cluster to be healthy
data "talos_cluster_health" "this" {
  depends_on = [
    talos_machine_configuration_apply.this,
    talos_machine_bootstrap.this
  ]

  client_configuration = data.talos_client_configuration.this.client_configuration
  control_plane_nodes  = [local.control_plane_ip]
  worker_nodes         = compact([for k, v in var.nodes : local.get_dhcp_ip[k] if v.machine_type == "worker"])
  endpoints            = [local.control_plane_ip]

  timeouts = {
    read = "10m"
  }
}

# Retrieve kubeconfig
resource "talos_cluster_kubeconfig" "this" {
  depends_on = [
    talos_machine_bootstrap.this,
    data.talos_cluster_health.this
  ]

  node                 = local.control_plane_ip
  client_configuration = talos_machine_secrets.this.client_configuration

  timeouts = {
    read = "2m"
  }
}

