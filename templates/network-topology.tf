#########################################################
# On-Prem VNet
#########################################################
resource "azurerm_virtual_network" "onpremise-vnet" {
  name                = "onpremise-vnet"
  location            = azurerm_resource_group.onpremise-rg.location
  resource_group_name = azurerm_resource_group.onpremise-rg.name
  address_space       = ["10.233.0.0/21"]
  dns_servers         = ["10.233.2.4"]

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack   = "dns-private-resolver"
  }
}

resource "azurerm_subnet" "onpremise-gateway-subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.onpremise-rg.name
  virtual_network_name = azurerm_virtual_network.onpremise-vnet.name
  address_prefixes     = ["10.233.0.0/26"]
}

resource "azurerm_subnet" "onpremise-default-subnet" {
  name                 = "snet-default"
  resource_group_name  = azurerm_resource_group.onpremise-rg.name
  virtual_network_name = azurerm_virtual_network.onpremise-vnet.name
  address_prefixes     = ["10.233.1.0/24"]
}

## Add gw subnet
resource "azurerm_subnet" "onpremise-gw-subnet" {
  name                 = "snet-gw"
  resource_group_name  = azurerm_resource_group.onpremise-rg.name
  virtual_network_name = azurerm_virtual_network.onpremise-vnet.name
  address_prefixes     = ["10.233.2.32/28"]
}
##

## Onprem Gateway
module "azr_r1_onprem_app1" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "1.6.3"

  cloud            = "Azure"
  name             = "azr-onprem-dns"
  vpc_id           = "${azurerm_virtual_network.onpremise-vnet.name}:${azurerm_resource_group.onpremise-rg.name}:${azurerm_virtual_network.onpremise-vnet.guid}"
  gw_subnet        = azurerm_subnet.onpremise-gw-subnet.address_prefixes[0]
  use_existing_vpc = true
  region           = var.onpremise_location
  account          = var.azure_account
  transit_gw       = module.azure_transit.transit_gateway.gw_name
  attached         = true
  ha_gw            = false
  single_ip_snat   = false
  single_az_ha     = false
  resource_group   = azurerm_resource_group.onpremise-rg.name
}

resource "azurerm_subnet" "onpremise-dns-inbound-subnet" {
  name                 = "snet-dns-inbound"
  resource_group_name  = azurerm_resource_group.onpremise-rg.name
  virtual_network_name = azurerm_virtual_network.onpremise-vnet.name
  address_prefixes     = ["10.233.2.0/28"]
  delegation {
    name = "Microsoft.Network.dnsResolvers"
    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      name    = "Microsoft.Network/dnsResolvers"
    }
  }
}

resource "azurerm_subnet" "onpremise-dns-outbound-subnet" {
  name                 = "snet-dns-outbound"
  resource_group_name  = azurerm_resource_group.onpremise-rg.name
  virtual_network_name = azurerm_virtual_network.onpremise-vnet.name
  address_prefixes     = ["10.233.2.16/28"]
  delegation {
    name = "Microsoft.Network.dnsResolvers"
    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      name    = "Microsoft.Network/dnsResolvers"
    }
  }
}

#########################################################
# Azure hub VNet
#########################################################

resource "azurerm_virtual_network" "hub-vnet" {
  name                = "hub-vnet"
  location            = azurerm_resource_group.hub-rg.location
  resource_group_name = azurerm_resource_group.hub-rg.name
  address_space       = ["10.221.0.0/21"]
  dns_servers         = ["10.221.2.4"]

  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "dns-private-resolver"
  }
}

resource "azurerm_subnet" "hub-gateway-subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefixes     = ["10.221.0.0/26"]
}

resource "azurerm_subnet" "hub-default-subnet" {
  name                 = "snet-default"
  resource_group_name  = azurerm_resource_group.hub-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefixes     = ["10.221.1.0/24"]
}

## Add gw subnet
resource "azurerm_subnet" "hub-gw-subnet" {
  name                 = "snet-gw"
  resource_group_name  = azurerm_resource_group.hub-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefixes     = ["10.221.2.32/28"]
}
##

## Aviatrix transit
module "azure_transit" {
  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "2.5.3"

  cloud                         = "azure"
  region                        = var.azure_location
  cidr                          = "10.221.2.32/28"
  account                       = var.azure_account
  enable_transit_firenet        = false
  enable_advertise_transit_cidr = true
  name                          = "azr-transit-dns"
  local_as_number               = 65100
  single_az_ha                  = false
  resource_group                = azurerm_resource_group.hub-rg.name
  vpc_id                        = "${azurerm_virtual_network.hub-vnet.name}:${azurerm_resource_group.hub-rg.name}:${azurerm_virtual_network.hub-vnet.guid}"
  gw_subnet                     = azurerm_subnet.hub-gw-subnet.address_prefixes[0]
  use_existing_vpc              = true
  ha_gw                         = false
}
##

resource "azurerm_subnet" "hub-dns-inbound-subnet" {
  name                 = "snet-dns-inbound"
  resource_group_name  = azurerm_resource_group.hub-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefixes     = ["10.221.2.0/28"]
  delegation {
    name = "Microsoft.Network.dnsResolvers"
    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      name    = "Microsoft.Network/dnsResolvers"
    }
  }
}

resource "azurerm_subnet" "hub-dns-outbound-subnet" {
  name                 = "snet-dns-outbound"
  resource_group_name  = azurerm_resource_group.hub-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefixes     = ["10.221.2.16/28"]
  delegation {
    name = "Microsoft.Network.dnsResolvers"
    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      name    = "Microsoft.Network/dnsResolvers"
    }
  }
}

resource "azurerm_subnet" "hub-firewall-subnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefixes     = ["10.221.3.0/26"]
}

#########################################################
# Azure spoke01 VNet
#########################################################

resource "azurerm_virtual_network" "spoke01-vnet" {
  name                = "spoke01-vnet"
  location            = azurerm_resource_group.spoke01-rg.location
  resource_group_name = azurerm_resource_group.spoke01-rg.name
  address_space       = ["10.221.8.0/24", "10.221.9.0/24"]
  dns_servers         = ["10.221.2.4"]

  tags = {
    environment = "cloud"
    deployment  = "terraform"
    microhack   = "dns-private-resolver"
  }
}

resource "azurerm_subnet" "spoke01-default-subnet" {
  name                                      = "snet-default"
  resource_group_name                       = azurerm_resource_group.spoke01-rg.name
  virtual_network_name                      = azurerm_virtual_network.spoke01-vnet.name
  address_prefixes                          = ["10.221.8.0/24"]
  private_endpoint_network_policies_enabled = true
}

## Add gw subnet
resource "azurerm_subnet" "spoke01-gw-subnet" {
  name                 = "snet-gw"
  resource_group_name  = azurerm_resource_group.spoke01-rg.name
  virtual_network_name = azurerm_virtual_network.spoke01-vnet.name
  address_prefixes     = ["10.221.9.0/28"]
}
##

## Spoke Gateway
module "azr_r1_spoke_app1" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "1.6.3"

  cloud            = "Azure"
  name             = "azr-spoke-dns"
  vpc_id           = "${azurerm_virtual_network.spoke01-vnet.name}:${azurerm_resource_group.spoke01-rg.name}:${azurerm_virtual_network.spoke01-vnet.guid}"
  gw_subnet        = azurerm_subnet.spoke01-gw-subnet.address_prefixes[0]
  use_existing_vpc = true
  region           = var.azure_location
  account          = var.azure_account
  transit_gw       = module.azure_transit.transit_gateway.gw_name
  attached         = true
  ha_gw            = false
  single_ip_snat   = false
  single_az_ha     = false
  resource_group   = azurerm_resource_group.hub-rg.name
}
##
#########################################################
# Peering hub <--> spoke01
#########################################################  

# resource "azurerm_virtual_network_peering" "spoke01-hub" {
#   name                         = "PEERING_SPOKE01_TO_HUB"
#   resource_group_name          = azurerm_resource_group.spoke01-rg.name
#   virtual_network_name         = azurerm_virtual_network.spoke01-vnet.name
#   remote_virtual_network_id    = azurerm_virtual_network.hub-vnet.id
#   allow_virtual_network_access = true
#   allow_forwarded_traffic      = true
#   allow_gateway_transit        = false
#   use_remote_gateways          = true

#   depends_on = [azurerm_virtual_network_gateway.hub-vpngw]
# }

# resource "azurerm_virtual_network_peering" "hub-spoke01" {
#   name                         = "PEERING_HUB_TO_SPOKE01"
#   resource_group_name          = azurerm_resource_group.hub-rg.name
#   virtual_network_name         = azurerm_virtual_network.hub-vnet.name
#   remote_virtual_network_id    = azurerm_virtual_network.spoke01-vnet.id
#   allow_virtual_network_access = true
#   allow_forwarded_traffic      = false
#   allow_gateway_transit        = true
#   use_remote_gateways          = false

#   depends_on = [azurerm_virtual_network_gateway.hub-vpngw]
# }
