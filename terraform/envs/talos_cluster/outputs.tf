# Create output directory for generated configs
resource "local_file" "talosconfig" {
  content         = module.talos_cluster.talosconfig
  filename        = "${path.module}/output/talosconfig"
  file_permission = "0600"
}

resource "local_file" "kubeconfig" {
  content         = module.talos_cluster.kubeconfig
  filename        = "${path.module}/output/kubeconfig"
  file_permission = "0600"
}

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