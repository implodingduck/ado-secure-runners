terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.1.0"
    }
  }
  backend "azurerm" {

  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}

locals {
  func_name = "func${random_string.unique.result}"
  loc_for_naming = lower(replace(var.location, " ", ""))
  gh_repo = replace(var.gh_repo, "implodingduck/", "")
  tags = {
    "managed_by" = "terraform"
    "repo"       = local.gh_repo
  }
}

resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}


data "azurerm_client_config" "current" {}

data "azurerm_log_analytics_workspace" "default" {
  name                = "DefaultWorkspace-${data.azurerm_client_config.current.subscription_id}-EUS"
  resource_group_name = "DefaultResourceGroup-EUS"
} 

data "azurerm_network_security_group" "basic" {
    name                = "basic"
    resource_group_name = "rg-network-eastus"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.gh_repo}-${random_string.unique.result}-${local.loc_for_naming}"
  location = var.location
  tags = local.tags
}


resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${local.gh_repo}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.7.0.0/16"]
}

resource "azurerm_subnet" "fw" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.7.0.0/24"]
}

resource "azurerm_subnet" "default" {
  name                 = "snet-${local.gh_repo}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.7.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${local.gh_repo}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "https"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  # security_rule {
  #   name                       = "AllowVnetInBound"
  #   priority                   = 65000
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "*"
  #   source_address_prefix      = "VirtualNetwork"
  #   destination_address_prefix = "VirtualNetwork"
  # }

  # security_rule {
  #   name                       = "AllowAzureLoadBalancerInBound"
  #   priority                   = 65001
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "*"
  #   source_address_prefix      = "AzureLoadBalancer"
  #   destination_address_prefix = "VirtualNetwork"
  # }

  # security_rule {
  #   name                       = "DenyAllInBound"
  #   priority                   = 65500
  #   direction                  = "Inbound"
  #   access                     = "Deny"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "*"
  #   source_address_prefix      = "*"
  #   destination_address_prefix = "*"
  # }

  security_rule {
    name                       = "httpsoutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  # security_rule {
  #   name                       = "AllowVnetOutBound"
  #   priority                   = 65000
  #   direction                  = "Outbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "*"
  #   source_address_prefix      = "VirtualNetwork"
  #   destination_address_prefix = "VirtualNetwork"
  # }

  # security_rule {
  #   name                       = "AllowAzureLoadBalancerOutBound"
  #   priority                   = 65001
  #   direction                  = "Outbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "*"
  #   source_address_prefix      = "AzureLoadBalancer"
  #   destination_address_prefix = "VirtualNetwork"
  # }

  # security_rule {
  #   name                       = "DenyAllOutBound"
  #   priority                   = 65500
  #   direction                  = "Outbound"
  #   access                     = "Deny"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "*"
  #   source_address_prefix      = "*"
  #   destination_address_prefix = "*"
  # }

 
  

  tags = local.tags
}

resource "azurerm_subnet_network_security_group_association" "default" {
  subnet_id                 = azurerm_subnet.default.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}


resource "azurerm_public_ip" "fw" {
  name                = "pip-fw-${local.gh_repo}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "fw" {
  name                = "fw-${local.gh_repo}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_tier            = "Standard"
  sku_name            =  "AZFW_VNet"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.fw.id
    public_ip_address_id = azurerm_public_ip.fw.id
  }
}

resource "azurerm_firewall_network_rule_collection" "https" {
  name                = "networkrulecollection"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = azurerm_resource_group.rg.name
  priority            = 100
  action              = "Allow"

  rule {
    name = "https"

    source_addresses = [
      "10.7.0.0/16",
    ]

    destination_ports = [
      "443",
    ]

    destination_addresses = [
      "*"
    ]

    protocols = [
      "TCP"
    ]
  }
}


resource "azurerm_monitor_diagnostic_setting" "fw" {
  name               = "allTheLogs"
  target_resource_id = azurerm_firewall.fw.id
  log_analytics_workspace_id  = data.azurerm_log_analytics_workspace.default.id

  log {
    category = "AzureFirewallApplicationRule"
  }

  log {
    category = "AzureFirewallNetworkRule"
  }

  log {
    category = "AzureFirewallDnsProxy"
  }

}

resource "azurerm_route_table" "default" {
  name                          = "rt-${local.gh_repo}"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  disable_bgp_route_propagation = false

  route {
    name           = "vnethop"
    address_prefix = "10.7.0.0/16"
    next_hop_type  = "VnetLocal"
  }
  route {
    name                   = "fwhop"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.fw.ip_configuration[0].private_ip_address
  }

}

resource "azurerm_linux_virtual_machine_scale_set" "runners" {
  depends_on = [
    azurerm_firewall_network_rule_collection.https,
    azurerm_route_table.default
  ]
  name                            = "vmss-${local.gh_repo}"
  resource_group_name = azurerm_resource_group.rg.name
  location           = azurerm_resource_group.rg.location
  sku                = "Standard_D2s_v3"
  instances          = 1
  overprovision      = false
  upgrade_mode       = "Manual"
  admin_username     = "azureuser"
  admin_ssh_key      {
    username = "azureuser"
    public_key = file("./id_rsa.pub")
  } 
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "nic-vmss-${local.gh_repo}"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.default.id
    }
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.uai.id
    ]
  }

  extension {
    name                 = "CustomScript"
    publisher            = "Microsoft.Azure.Extensions"

    settings = <<SETTINGS
    {
      "fileUris": [
        "https://raw.githubusercontent.com/implodingduck/ado-secure-runners/main/custom_install.sh"
      ],
      "commandToExecute" : "bash ./custom_install.sh"
    }
SETTINGS
  }
}

resource "azurerm_user_assigned_identity" "uai" {
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  name = "uai-${local.gh_repo}"
}

resource "azurerm_role_assignment" "example" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.uai.principal_id
}