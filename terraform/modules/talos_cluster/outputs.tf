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
  value       = "https://${local.control_plane_ip}:6443"
}

output "control_plane_nodes" {
  description = "List of control plane node IP addresses"
  value       = [local.control_plane_ip]
}

output "worker_nodes" {
  description = "List of worker node IP addresses"
  value       = compact([for k, v in var.nodes : local.get_dhcp_ip[k] if v.machine_type == "worker"])
}

output "talos_schematic_id" {
  description = "Talos Image Factory schematic ID"
  value       = talos_image_factory_schematic.this.id
}

output "talos_version" {
  description = "Talos version used for the cluster"
  value       = var.cluster.talos_version
}

output "node_details" {
  description = "Detailed node information including hostname, IP address, MAC address, and machine type"
  value = {
    for k, v in var.nodes : k => {
      hostname     = k
      ip_address   = coalesce(local.get_dhcp_ip[k], "pending")
      mac_address  = v.mac_address
      machine_type = v.machine_type
    }
  }
}
