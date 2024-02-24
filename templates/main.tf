provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "aviatrix" {
  controller_ip = "controller-prd.ananableu.fr"
  username      = "admin"
  password      = var.controller_password
}

terraform {
  required_providers {
    aviatrix = {
      source = "AviatrixSystems/aviatrix"
    }
  }
}

#########################################################
# Resource Group for all resources used in the MicroHack
#########################################################
resource "azurerm_resource_group" "onpremise-rg" {
  name     = "onpremise-rg"
  location = var.onpremise_location

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack   = "dns-private-resolver"
  }
}

resource "azurerm_resource_group" "hub-rg" {
  name     = "hub-rg"
  location = var.azure_location

  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "dns-private-resolver"
  }
}

resource "azurerm_resource_group" "spoke01-rg" {
  name     = "spoke01-rg"
  location = var.azure_location

  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "dns-private-resolver"
  }
}
