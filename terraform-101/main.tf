terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.13.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "08245eb1-d21e-44e6-9ca6-022635183725"
  tenant_id       = "373ba10b-d68e-4633-92ed-19e4417c590e"
}

# --- Locals --- #
locals {
  common_tags = {
    environment = "Development"
    region = var.location
  }
  network_address = ["10.0.0.0/16"]
}

# --- Variables --- #
variable "env"{
  description = "Set Environment"
}

variable "location" {
  description = "Set Location"
  validation {
    condition = contains(
    [
    "centralindia",
    "southindia",
    "westindia"
    ],
    replace(lower(var.location), " ","")
    )
    error_message = "Location must be one of: centralindia, southindia, westindia"
  }
}

# --- Resources --- #
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.env}-ci-tf"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.env}-ci-tf"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space = ["10.0.0.0/16"]
  tags = local.common_tags
}