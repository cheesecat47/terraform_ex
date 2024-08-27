resource "azurerm_network_interface" "managed_node_nic" {
  count               = var.managed_node_count
  name                = "${var.resource_prefix}nic_managed_node_${count.index + 1}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_pub_10.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.10.${count.index + 11}"
  }
}

resource "azurerm_linux_virtual_machine" "vm_managed_node" {
  count               = var.managed_node_count
  name                = "${var.resource_prefix}vm_managed_node_${count.index + 1}"
  computer_name       = "ubuntu"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_B1ls"
  admin_username      = var.vm_admin_username

  network_interface_ids = [
    azurerm_network_interface.managed_node_nic[count.index].id,
  ]

  os_disk {
    name                 = "${var.resource_prefix}vm_managed_node_${count.index + 1}_os_disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = azapi_resource_action.pubkey_gen.output.publicKey
  }
}
