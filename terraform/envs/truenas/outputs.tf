# =============================================================================
# TrueNAS SCALE VM Outputs
# =============================================================================

output "vm_id" {
  description = "The VM ID of the TrueNAS instance"
  value       = proxmox_virtual_environment_vm.truenas.vm_id
}

output "name" {
  description = "The name of the TrueNAS VM"
  value       = proxmox_virtual_environment_vm.truenas.name
}

output "node" {
  description = "The Proxmox node hosting the TrueNAS VM"
  value       = proxmox_virtual_environment_vm.truenas.node_name
}

output "macaddr" {
  description = "The MAC address of the TrueNAS VM network interface"
  value       = var.macaddr
}

# Note: TrueNAS SCALE does not report its IP address to the Proxmox guest agent
# by default. You will need to find the IP address through your DHCP server,
# router, or by checking the TrueNAS console directly.
