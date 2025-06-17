# Generate SSH key pair
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key to file
resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/${var.ssh_key_filename}"
  file_permission = "0600"
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-kubeflow"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.kubeflow.location
  resource_group_name = azurerm_resource_group.kubeflow.name
}

# Create a subnet
resource "azurerm_subnet" "subnet" {
  name                 = "subnet-kubeflow"
  resource_group_name  = azurerm_resource_group.kubeflow.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create a public IP address
resource "azurerm_public_ip" "public_ip" {
  name                = "pip-kubeflow"
  location            = azurerm_resource_group.kubeflow.location
  resource_group_name = azurerm_resource_group.kubeflow.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create a Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-kubeflow"
  location            = azurerm_resource_group.kubeflow.location
  resource_group_name = azurerm_resource_group.kubeflow.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create a network interface
resource "azurerm_network_interface" "nic" {
  name                = "nic-kubeflow"
  location            = azurerm_resource_group.kubeflow.location
  resource_group_name = azurerm_resource_group.kubeflow.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# Associate NSG with the subnet
resource "azurerm_subnet_network_security_group_association" "subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Create a Linux virtual machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "vm-kubeflow"
  location              = azurerm_resource_group.kubeflow.location
  resource_group_name   = azurerm_resource_group.kubeflow.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  size                  = var.vm_size

  os_disk {
    name                 = "osdisk-kubeflow"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = 100  # Increase OS disk size for Kubeflow requirements
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name  = "vm-kubeflow"
  admin_username = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh_key.public_key_openssh
  }

  # Copy setup script to VM
  provisioner "file" {
    source      = "setup-kubeflow.sh"
    destination = "/home/${var.admin_username}/setup-kubeflow.sh"
    
    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = tls_private_key.ssh_key.private_key_pem
      host        = azurerm_public_ip.public_ip.ip_address
    }
  }

  # Make script executable
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/${var.admin_username}/setup-kubeflow.sh",
      "echo 'Setup script is ready to run. Execute ./setup-kubeflow.sh to begin installation.'"
    ]
    
    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = tls_private_key.ssh_key.private_key_pem
      host        = azurerm_public_ip.public_ip.ip_address
    }
  }

  # Wait for cloud-init to complete
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait || echo 'Cloud-init failed but continuing anyway'"
    ]
    
    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = tls_private_key.ssh_key.private_key_pem
      host        = azurerm_public_ip.public_ip.ip_address
    }
  }

  depends_on = [azurerm_network_interface.nic]
} 