terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116.0"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "terraform_ex_resource_group"
  location = "koreacentral"
}

resource "azurerm_virtual_network" "vnet" {
  name = "terraform_ex_vnet"
  address_space = [ "10.0.0.0/16" ]
  location = "koreacentral"
  resource_group_name = azurerm_resource_group.rg.name
}