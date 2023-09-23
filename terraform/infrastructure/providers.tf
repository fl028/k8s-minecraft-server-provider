terraform {
  required_providers {
    azapi = {
      source = "Azure/azapi"
      version = "1.7.0"
    }
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.71.0"
    }
    random = {
      source = "hashicorp/random"
      version = "3.5.1"
    }
    local = {
      source = "hashicorp/local"
      version = "2.4.0"
    }
  }
}

provider "azapi" {
  subscription_id = var.AZURE_SUBSCRIPTION_ID
  tenant_id       = var.AZURE_TENANT_ID
  client_id       = var.AZURE_CLIENT_ID
  client_secret   = var.AZURE_CLIENT_SECRET
}

provider "azurerm" {
  features {}

  subscription_id = var.AZURE_SUBSCRIPTION_ID
  tenant_id       = var.AZURE_TENANT_ID
  client_id       = var.AZURE_CLIENT_ID
  client_secret   = var.AZURE_CLIENT_SECRET
}

provider "random" {
  # Configuration options
}

provider "local" {
  # Configuration options
}