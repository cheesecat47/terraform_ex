terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116.0"
    }

    azapi = {
      source  = "azure/azapi"
      version = "~>1.15"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}
