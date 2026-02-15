# Resource group for VM
resource "azurerm_resource_group" "rpg" {
  name     = var.vm_resource_group
  location = var.location
}

# Network Interface
resource "azurerm_network_interface" "vm" {
  name                = "${var.vm_name}-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rpg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.rpg.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.foundry.id
  }
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "rpg" {
  name                            = var.vm_name
  location                        = var.location
  resource_group_name             = azurerm_resource_group.rpg.name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  provision_vm_agent              = false
  allow_extension_operations      = false

  network_interface_ids = [
    azurerm_network_interface.vm.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = "${var.vm_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = var.ubuntu_offer
    sku       = "minimal"
    version   = "latest"
  }

  custom_data = base64encode(file("${path.module}/cloud-init.yml"))
}

# Reference the existing persistent data disk
data "azurerm_managed_disk" "foundry" {
  name                = "foundrydata"
  resource_group_name = "FOUNDRY"
}

# Attach it to the VM
resource "azurerm_virtual_machine_data_disk_attachment" "foundry" {
  managed_disk_id    = data.azurerm_managed_disk.foundry.id
  virtual_machine_id = azurerm_linux_virtual_machine.rpg.id
  lun                = 0
  caching            = "ReadWrite"
}

# Auto-shutdown schedule at 11 PM Oslo time
resource "azurerm_dev_test_global_vm_shutdown_schedule" "rpg" {
  virtual_machine_id = azurerm_linux_virtual_machine.rpg.id
  location           = var.location
  enabled            = true

  daily_recurrence_time = "2300"
  timezone              = "W. Europe Standard Time"

  notification_settings {
    enabled = false
  }
}