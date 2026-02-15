# Resource group for network resources
resource "azurerm_resource_group" "network" {
  name     = var.network_resource_group
  location = var.location
}

# Public IP
resource "azurerm_public_ip" "foundry" {
  name                    = "rpg-ip"
  location                = var.location
  resource_group_name     = azurerm_resource_group.network.name
  allocation_method       = "Static"
  sku                     = "Standard"
  domain_name_label       = "rpg"
  idle_timeout_in_minutes = 4
}

# Network Security Group
resource "azurerm_network_security_group" "nygdev" {
  name                = "NygDev-NSG"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name

  security_rule {
    name                       = "WebHosting"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "L69"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "30000", "30001"]
    source_address_prefix      = var.home_ip
    destination_address_prefix = "*"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "nygdev" {
  name                = "NygDev-vNet"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name
  address_space       = ["10.0.0.0/24"]
}

# Subnet
resource "azurerm_subnet" "rpg" {
  name                 = "RPG"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.nygdev.name
  address_prefixes     = ["10.0.0.0/29"]
}

# Associate NSG with Subnet
resource "azurerm_subnet_network_security_group_association" "rpg" {
  subnet_id                 = azurerm_subnet.rpg.id
  network_security_group_id = azurerm_network_security_group.nygdev.id
}