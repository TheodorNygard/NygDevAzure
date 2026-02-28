terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-nygdev-data"
    storage_account_name = "nygdevtfstate"
    container_name       = "tfstate"
    key                  = "azure-infrastructure.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
}
