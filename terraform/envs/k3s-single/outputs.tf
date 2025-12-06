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
# SSH Key Paths
# -----------------------------------------------------------------------------

output "ssh_private_key_path" {
  value       = local_file.private_key.filename
  description = "Path to generated SSH private key"
}

output "ssh_public_key_path" {
  value       = local_file.public_key.filename
  description = "Path to generated SSH public key"
}

# -----------------------------------------------------------------------------
# Access Commands
# -----------------------------------------------------------------------------

output "ssh_command" {
  value       = "ssh -i ${local_file.private_key.filename} ${local.ci_user}@${split("/", var.vm_ip)[0]}"
  description = "SSH command to connect to the VM"
}

output "kubeconfig_command" {
  value       = "ssh -i ${local_file.private_key.filename} ${local.ci_user}@${split("/", var.vm_ip)[0]} 'sudo cat /etc/rancher/k3s/k3s.yaml' | sed 's/127.0.0.1/${split("/", var.vm_ip)[0]}/g'"
  description = "Command to fetch kubeconfig from the k3s node"
}

# -----------------------------------------------------------------------------
# kubectl Context Information (Req 3.5)
# -----------------------------------------------------------------------------

output "kubectl_context" {
  value = {
    cluster_name  = module.k3s_node.name
    cluster_ip    = split("/", var.vm_ip)[0]
    cluster_port  = 6443
    ssh_key       = local_file.private_key.filename
    context_setup = <<-EOT
      # Fetch kubeconfig
      ssh -i ${local_file.private_key.filename} ${local.ci_user}@${split("/", var.vm_ip)[0]} 'sudo cat /etc/rancher/k3s/k3s.yaml' | sed 's/127.0.0.1/${split("/", var.vm_ip)[0]}/g' > ~/.kube/${module.k3s_node.name}.yaml

      # Set KUBECONFIG or merge with existing
      export KUBECONFIG=~/.kube/${module.k3s_node.name}.yaml

      # Or merge with existing config
      # KUBECONFIG=~/.kube/config:~/.kube/${module.k3s_node.name}.yaml kubectl config view --flatten > ~/.kube/config.new
      # mv ~/.kube/config.new ~/.kube/config

      # Verify connection
      kubectl get nodes
    EOT
  }
  description = "Instructions for setting up kubectl context"
}
