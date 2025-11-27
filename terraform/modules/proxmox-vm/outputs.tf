# =============================================================================
# Proxmox VM Module - Outputs
#
# Exposes key information about the created VM for use by other modules
# or for display after terraform apply.
#
# Refs: Req 4.5
# =============================================================================

output "vm_id" {
  value       = proxmox_vm_qemu.vm.vmid
  description = "Proxmox VM ID"
}

output "ip_address" {
  value       = var.ip
  description = "VM IP address (as configured, not discovered)"
}

output "name" {
  value       = proxmox_vm_qemu.vm.name
  description = "VM name/hostname"
}

output "node" {
  value       = proxmox_vm_qemu.vm.target_node
  description = "Proxmox node where VM is running"
}

output "ssh_command" {
  value       = "ssh ${var.ci_user}@${split("/", var.ip)[0]}"
  description = "SSH command to connect to the VM"
}

output "kubeconfig_command" {
  value       = "ssh ${var.ci_user}@${split("/", var.ip)[0]} 'sudo cat /etc/rancher/k3s/k3s.yaml' | sed 's/127.0.0.1/${split("/", var.ip)[0]}/g'"
  description = "Command to fetch kubeconfig from the k3s node"
}
