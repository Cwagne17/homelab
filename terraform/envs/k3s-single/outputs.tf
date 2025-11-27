# =============================================================================
# k3s-single Environment - Outputs
#
# Provides key information after deployment for accessing the k3s cluster.
#
# Refs: Req 3.5
# =============================================================================

# -----------------------------------------------------------------------------
# VM Information
# -----------------------------------------------------------------------------

output "vm_id" {
  value       = module.k3s_node.vm_id
  description = "Proxmox VM ID"
}

output "vm_name" {
  value       = module.k3s_node.name
  description = "VM hostname"
}

output "vm_ip" {
  value       = module.k3s_node.ip_address
  description = "VM IP address"
}

output "vm_node" {
  value       = module.k3s_node.node
  description = "Proxmox node hosting the VM"
}

# -----------------------------------------------------------------------------
# Access Commands
# -----------------------------------------------------------------------------

output "ssh_command" {
  value       = module.k3s_node.ssh_command
  description = "SSH command to connect to the VM"
}

output "kubeconfig_command" {
  value       = module.k3s_node.kubeconfig_command
  description = "Command to fetch kubeconfig from the k3s node"
}

# -----------------------------------------------------------------------------
# kubectl Context Information (Req 3.5)
# -----------------------------------------------------------------------------

output "kubectl_context" {
  value = {
    cluster_name  = var.vm_name
    cluster_ip    = split("/", var.vm_ip)[0]
    cluster_port  = 6443
    context_setup = <<-EOT
      # Fetch kubeconfig
      ${module.k3s_node.kubeconfig_command} > ~/.kube/${var.vm_name}.yaml

      # Set KUBECONFIG or merge with existing
      export KUBECONFIG=~/.kube/${var.vm_name}.yaml

      # Or merge with existing config
      # KUBECONFIG=~/.kube/config:~/.kube/${var.vm_name}.yaml kubectl config view --flatten > ~/.kube/config.new
      # mv ~/.kube/config.new ~/.kube/config

      # Verify connection
      kubectl get nodes
    EOT
  }
  description = "Instructions for setting up kubectl context"
}
