

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "react-app-rg" {
  name     = "react-app-rg"
  location = "South Africa North"
}

variable "admin_ip" {
  description = "Your public IP address"
  type        = string
}

variable "admin_password" {
  description = "The password for the admin user"
  type        = string
  sensitive   = true
}

resource "azurerm_virtual_network" "react-app-vnet" {
  name                = "react-app-vnet"
  location            = azurerm_resource_group.react-app-rg.location
  resource_group_name = azurerm_resource_group.react-app-rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "react-app-subnet" {
  name                 = "react-app-subnet"
  resource_group_name  = azurerm_resource_group.react-app-rg.name
  virtual_network_name = azurerm_virtual_network.react-app-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "react-app-nsg" {
  name                = "react-app-nsg"
  location            = azurerm_resource_group.react-app-rg.location
  resource_group_name = azurerm_resource_group.react-app-rg.name
  
  security_rule {
    name                       = "allow-ssh-from-my-ip"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_ip
    destination_address_prefix = "*"
  }

   security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.react-app-subnet.id
  network_security_group_id = azurerm_network_security_group.react-app-nsg.id
}

resource "azurerm_public_ip" "react-app-public-ip" {
  name                = "react-app-public-ip"
  resource_group_name = azurerm_resource_group.react-app-rg.name
  location            = azurerm_resource_group.react-app-rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "react-app-nic" {
  name                = "react-app-nic"
  location            = azurerm_resource_group.react-app-rg.location
  resource_group_name = azurerm_resource_group.react-app-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.react-app-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.react-app-public-ip.id
  }
}

resource "azurerm_linux_virtual_machine" "react-app-vm" {
  name                = "react-app-vm"
  resource_group_name = azurerm_resource_group.react-app-rg.name
  location            = azurerm_resource_group.react-app-rg.location
  size                = "Standard_B2ats_v2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.react-app-nic.id,
  ]
  disable_password_authentication = false
  admin_password                   = var.admin_password

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(file("${path.module}/cloud-init.sh"))
}

output "public_ip_address" {
  value = azurerm_public_ip.react-app-public-ip.ip_address
}