output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.kubeflow.name
}

output "public_ip_address" {
  description = "The public IP address of the virtual machine"
  value       = azurerm_public_ip.public_ip.ip_address
}

output "admin_username" {
  description = "The admin username for the virtual machine"
  value       = azurerm_linux_virtual_machine.vm.admin_username
}

output "ssh_private_key_path" {
  description = "The path to the SSH private key file"
  value       = local_file.private_key.filename
}

output "ssh_connection_command" {
  description = "Command to connect to the VM via SSH"
  value       = "ssh -i ${local_file.private_key.filename} ${azurerm_linux_virtual_machine.vm.admin_username}@${azurerm_public_ip.public_ip.ip_address}"
}

output "vm_name" {
  description = "The name of the virtual machine"
  value       = azurerm_linux_virtual_machine.vm.name
} 