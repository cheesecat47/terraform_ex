resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "terraform_ex_vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "terraform_ex_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "terraform_ex_nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-HTTP-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "80"
  }

  security_rule {
    name                       = "Allow-SSH-Inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "22"
  }
}

resource "azurerm_public_ip" "pubip" {
  name                = "terraform_ex_pubip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface
resource "azurerm_network_interface" "nic" {
  name                = "terraform_ex_nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.2.10"
    public_ip_address_id          = azurerm_public_ip.pubip.id
  }
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_security_group_association
resource "azurerm_network_interface_security_group_association" "nic_nsg_association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "vm_control_node" {
  name                = "terraform_ex_vm_control_node"
  computer_name       = "ubuntu"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_B1ls"
  admin_username      = var.vm_admin_username

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    name                 = "terraform_ex_vm_os_disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # https://documentation.ubuntu.com/azure/en/latest/azure-how-to/instances/find-ubuntu-images/
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

  connection {
    type        = "ssh"
    user        = self.admin_username
    host        = self.public_ip_address
    private_key = azapi_resource_action.pubkey_gen.output.privateKey
  }

  provisioner "file" {
    source      = "./ansible"
    destination = "/tmp/ansible"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/ansible/install_ansible.sh",
      "/tmp/ansible/install_ansible.sh",
    ]
  }
}

resource "azurerm_network_interface" "managed_node_nic" {
  count               = var.managed_node_count
  name                = "terraform_ex_nic_managed_node_${count.index + 1}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.2.10${count.index}"
  }
}

resource "azurerm_linux_virtual_machine" "vm_managed_node" {
  count               = var.managed_node_count
  name                = "terraform_ex_vm_managed_node_${count.index + 1}"
  computer_name       = "ubuntu"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_B1ls"
  admin_username      = var.vm_admin_username

  network_interface_ids = [
    azurerm_network_interface.managed_node_nic[count.index].id,
  ]

  os_disk {
    name                 = "terraform_ex_vm_os_disk_${count.index + 1}"
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
