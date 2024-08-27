resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_prefix}resource_group"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.resource_prefix}vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet_pub_1" {
  name                 = "${var.resource_prefix}subnet_pub_1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "subnet_pub_10" {
  name                 = "${var.resource_prefix}subnet_pub_10"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.10.0/24"]
}

resource "azurerm_subnet" "subnet_prv_20" {
  name                 = "${var.resource_prefix}subnet_prv_20"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.20.0/24"]
}

resource "azurerm_network_security_group" "nsg_ssh_http" {
  name                = "${var.resource_prefix}nsg_ssh_http"
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

resource "azurerm_network_security_group" "nsg_ssh" {
  name                = "${var.resource_prefix}nsg_ssh"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

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

resource "azurerm_public_ip" "control_node_pubip" {
  name                = "${var.resource_prefix}control_node_pubip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "control_node_nic" {
  name                = "${var.resource_prefix}control_node_nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_pub_1.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.10"
    public_ip_address_id          = azurerm_public_ip.control_node_pubip.id
  }
}

resource "azurerm_network_interface_security_group_association" "control_node_nic_nsg_association" {
  network_interface_id      = azurerm_network_interface.control_node_nic.id
  network_security_group_id = azurerm_network_security_group.nsg_ssh.id
}

resource "azurerm_linux_virtual_machine" "vm_control_node" {
  name                = "${var.resource_prefix}vm_control_node"
  computer_name       = "ubuntu"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_B1ls"
  admin_username      = var.vm_admin_username

  network_interface_ids = [
    azurerm_network_interface.control_node_nic.id
  ]

  os_disk {
    name                 = "${var.resource_prefix}control_node_os_disk"
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

  depends_on = [
    azurerm_linux_virtual_machine.vm_managed_node,
  ]

  connection {
    type        = "ssh"
    user        = self.admin_username
    host        = self.public_ip_address
    private_key = azapi_resource_action.pubkey_gen.output.privateKey
  }

  provisioner "file" {
    source      = "../02.Ansible"
    destination = "/tmp/ansible"
  }

  provisioner "file" {
    source      = "./private.key"
    destination = "/home/${var.vm_admin_username}/.ssh/id_rsa"
  }

  provisioner "file" {
    source      = "./public.key"
    destination = "/home/${var.vm_admin_username}/.ssh/id_rsa.pub"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/ansible/install_ansible.sh",
      "/tmp/ansible/install_ansible.sh",
      "chmod 0400 /home/${var.vm_admin_username}/.ssh/id_rsa*",
      "ANSIBLE_HOST_KEY_CHECKING=False /home/${var.vm_admin_username}/.local/bin/ansible-playbook -i /tmp/ansible/inventory.yml /tmp/ansible/test.yml",
    ]
  }
}

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
