output "load_balancer_public_ip" {
  description = "Public IP address of the Azure Load Balancer."
  value       = azurerm_public_ip.lb.ip_address
}

output "load_balancer_url" {
  description = "Direct URL to the Azure Load Balancer (bypasses Route 53)."
  value       = "http://${azurerm_public_ip.lb.ip_address}"
}

output "vm_name" {
  description = "Azure VM name (useful for chaos testing via CLI)."
  value       = azurerm_linux_virtual_machine.app.name
}

output "resource_group_name" {
  description = "Azure resource group name."
  value       = azurerm_resource_group.main.name
}

output "ssh_private_key" {
  description = "SSH private key for the Azure VM (sensitive)."
  value       = tls_private_key.vm.private_key_pem
  sensitive   = true
}

output "ssh_command" {
  description = "Example SSH command (VM has no public IP; use Azure Bastion or serial console for advanced access)."
  value       = "az vm run-command invoke -g ${azurerm_resource_group.main.name} -n ${azurerm_linux_virtual_machine.app.name} --command-id RunShellScript --scripts 'sudo systemctl status nginx'"
}
