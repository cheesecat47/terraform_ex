output "resource_group_id" {
  value = azurerm_resource_group.rg.id
}

output "control_node_public_ip" {
  value = azurerm_public_ip.control_node_pubip.ip_address
}

output "managed_node_private_ip" {
  value = azurerm_linux_virtual_machine.vm_managed_node[*].private_ip_address
}
