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
    environment = "test"
    region      = var.location
  }
  network_address = ["10.0.0.0/16"]
}


# --- Variables --- #

variable "env" {
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
      replace(lower(var.location), " ", "")
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
  address_space       = ["10.0.0.0/16"]
  tags                = local.common_tags
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "nic" {
  name                = "nic-${var.env}-ci-tf"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.common_tags
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                = "example-machine"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2as_v4"
  admin_username      = "adminuser"
  admin_password      = data.azurerm_key_vault_secret.secret.value
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}


# --- Data Sources --- #

data "azurerm_key_vault" "kv" {
  name                = "kv-test-ci-tf"
  resource_group_name = azurerm_resource_group.rg.name
}

data "azurerm_key_vault_secret" "secret" {
  name         = "vm-login-admin-pass"
  key_vault_id = data.azurerm_key_vault.kv.id
}


# --- Outputs --- #
output "firstAddressSpace" {
  value = tolist(azurerm_virtual_network.vnet.address_space)[0]
}

output "vm_info" {
  value = {
    id                  = azurerm_windows_virtual_machine.vm.id
    name                = azurerm_windows_virtual_machine.vm.name
    location            = azurerm_windows_virtual_machine.vm.location
    resource_group_name = azurerm_windows_virtual_machine.vm.resource_group_name
    ip                  = azurerm_network_interface.nic.private_ip_address
  }
}

output "vm_password" {
  value     = azurerm_windows_virtual_machine.vm.admin_password
  sensitive = true
}