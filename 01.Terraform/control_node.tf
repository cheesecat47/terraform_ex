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
