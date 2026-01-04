locals {
  # Extract IP address from CIDR notation for each node
  node_ips = {
    for k, v in var.nodes : k => split("/", v.ip_cidr)[0]
  }

  # Extract subnet mask from CIDR notation
  node_subnet_masks = {
    for k, v in var.nodes : k => split("/", v.ip_cidr)[1]
  }

  # Find first control plane node IP for bootstrap
  first_controlplane_ip = [
    for k, v in var.nodes : local.node_ips[k]
    if v.machine_type == "controlplane"
  ][0]

  # Extract endpoint host (remove :port if present)
  endpoint_host = split(":", var.cluster.endpoint)[0]
}

# Generate Talos machine secrets (certificates, tokens, etc.)
resource "talos_machine_secrets" "this" {
  talos_version = var.cluster.talos_version
}

# Generate Talos client configuration (talosconfig)
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster.name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [for k, v in var.nodes : local.node_ips[k]]
  endpoints            = [for k, v in var.nodes : local.node_ips[k] if v.machine_type == "controlplane"]
}

# Generate machine configuration for each node
data "talos_machine_configuration" "this" {
  for_each = var.nodes

  cluster_name     = var.cluster.name
  cluster_endpoint = "https://${var.cluster.endpoint}"
  talos_version    = var.cluster.talos_version
  machine_type     = each.value.machine_type
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname = each.key
          interfaces = [{
            interface = "eth0"
            addresses = [each.value.ip_cidr]
            routes = [{
              network = "0.0.0.0/0"
              gateway = var.network_gateway
            }]
            dhcp = false
          }]
        }
        nodeLabels = merge(
          var.cluster.proxmox_cluster != "" ? {
            "topology.kubernetes.io/region" = var.cluster.proxmox_cluster
            "topology.kubernetes.io/zone"   = var.proxmox_host_node
          } : {},
          {
            "node.kubernetes.io/instance-type" = each.value.machine_type
          }
        )
      }
      cluster = each.value.machine_type == "controlplane" ? {
        allowSchedulingOnControlPlanes = true
      } : null
    })
  ]
}

# Apply machine configuration to each node
resource "talos_machine_configuration_apply" "this" {
  depends_on = [proxmox_virtual_environment_vm.this]

  for_each = var.nodes

  node                        = local.node_ips[each.key]
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
  depends_on = [talos_machine_configuration_apply.this]

  node                 = local.first_controlplane_ip
  client_configuration = talos_machine_secrets.this.client_configuration
}

# Wait for cluster to be healthy
data "talos_cluster_health" "this" {
  depends_on = [
    talos_machine_configuration_apply.this,
    talos_machine_bootstrap.this
  ]

  client_configuration = data.talos_client_configuration.this.client_configuration
  control_plane_nodes  = [for k, v in var.nodes : local.node_ips[k] if v.machine_type == "controlplane"]
  worker_nodes         = [for k, v in var.nodes : local.node_ips[k] if v.machine_type == "worker"]
  endpoints            = data.talos_client_configuration.this.endpoints

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

  node                 = local.first_controlplane_ip
  client_configuration = talos_machine_secrets.this.client_configuration

  timeouts = {
    read = "2m"
  }
}
