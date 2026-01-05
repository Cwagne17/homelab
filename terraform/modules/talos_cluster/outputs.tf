output "talosconfig" {
  description = "Talos client configuration for managing the cluster"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubernetes cluster configuration"
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "cluster_name" {
  description = "Name of the Talos cluster"
  value       = var.cluster.name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = "https://${var.cluster.endpoint}"
}

output "control_plane_nodes" {
  description = "Map of control plane node names to IP addresses"
  value = {
    for k, v in var.nodes : k => local.node_ips[k]
    if v.machine_type == "controlplane"
  }
}

output "worker_nodes" {
  description = "Map of worker node names to IP addresses"
  value = {
    for k, v in var.nodes : k => local.node_ips[k]
    if v.machine_type == "worker"
  }
}

output "talos_schematic_id" {
  description = "Talos Image Factory schematic ID"
  value       = talos_image_factory_schematic.this.id
}

output "talos_version" {
  description = "Talos version used for the cluster"
  value       = var.cluster.talos_version
}
