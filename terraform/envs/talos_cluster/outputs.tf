# Output for convenience
output "cluster_info" {
  description = "Cluster connection information"
  value = {
    name              = module.talos_cluster.cluster_name
    endpoint          = module.talos_cluster.cluster_endpoint
    talosconfig_path  = abspath("${path.module}/output/talosconfig")
    kubeconfig_path   = abspath("${path.module}/output/kubeconfig")
    control_plane_ips = module.talos_cluster.control_plane_nodes
    worker_ips        = module.talos_cluster.worker_nodes
  }
}

output "talos_schematic_id" {
  description = "Talos Image Factory schematic ID"
  value       = module.talos_cluster.talos_schematic_id
}

output "talos_version" {
  description = "Talos version used for the cluster"
  value       = module.talos_cluster.talos_version
}

output "control_plane_nodes" {
  description = "Map of control plane node names to IP addresses"
  value       = module.talos_cluster.control_plane_nodes
}

output "worker_nodes" {
  description = "Map of worker node names to IP addresses"
  value       = module.talos_cluster.worker_nodes
}

output "talosconfig" {
  description = "Talos client configuration"
  value       = module.talos_cluster.talosconfig
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubernetes cluster configuration"
  value       = module.talos_cluster.kubeconfig
  sensitive   = true
}

output "node_details" {
  description = "Detailed node information for upgrades"
  value       = module.talos_cluster.node_details
}