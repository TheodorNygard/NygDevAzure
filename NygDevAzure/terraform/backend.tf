terraform {
  backend "azurerm" {
    resource_group_name  = "Automation"
    storage_account_name = "nygdevtfstate"
    container_name       = "tfstate"
    key                  = "azure-infrastructure.tfstate"
    use_azuread_auth     = true
  }
}