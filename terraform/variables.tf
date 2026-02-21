variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "norwayeast"
}

variable "home_ip" {
  description = "Home IP address for NSG rules"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  sensitive   = true
}

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  default     = "rpg-vm"
}

variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  sensitive   = true
}

variable "network_resource_group" {
  description = "Resource group containing network resources"
  type        = string
  default     = "rg-nygdev-network"
}

variable "vm_resource_group" {
  description = "Resource group for VM resources"
  type        = string
  default     = "rg-rpg"
}

variable "ubuntu_offer" {
  description = "Ubuntu image offer name (resolved by pipeline)"
  type        = string
  default     = "ubuntu-25_10-daily"
}