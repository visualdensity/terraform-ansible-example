terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.13.0"
    }
    local = {
      source = "hashicorp/local"
      version = "2.2.3"
    }
  }
}

provider "azurerm" {
  # Configuration options
  features {}
  subscription_id = "" #put your Azure subscription ID here
}

provider "local" {
  # Configuration options
}



#########################
# Local variables
#########################
locals {
  tags = {
    "Owner"       = var.system_user
    "Project"     = var.project_name
    "Environment" = var.env
  }
}

#########################
# Resource groups
#########################

resource "azurerm_resource_group" "rg" {
  name     = "${var.project_name}Rg"
  tags     = merge(local.tags, { "Type" = "rg" }) #example of adding to the map
  location = var.location
}

#########################
# Networks
#########################

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.project_name}Vnet"
  tags                = local.tags
  location            = var.location
  address_space       = var.vnet_address_space
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnets" {
  for_each = var.subnets
    name                 = each.value["name"]
    address_prefixes     = each.value["address_prefixes"]
    resource_group_name  = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
}

#########################
# Gateway VM Setup
#########################

resource "azurerm_public_ip" "gateway_pub_ip" {
  name                = "${var.project_name}PubIP"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  allocation_method   = "Static"
  tags                = local.tags
}

resource "azurerm_network_interface" "gateway_nic_pub" {
  name                = "${var.project_name}NicPub"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  tags                = local.tags

  ip_configuration {
    name                          = "${var.project_name}IpConfig"
    subnet_id                     = azurerm_subnet.subnets["dmz_subnet"].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.gateway_pub_ip.id
  }
}

resource "azurerm_network_interface" "gateway_nic_internal" {
  name                = "${var.project_name}NicInternal"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnets["dmz_subnet"].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_security_group" "gateway_nsg" {
  name                = "${var.project_name}GatewayNsg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  tags                = local.tags
}

resource "azurerm_network_security_rule" "gateway_nsg_ssh" {
  name                        = "${var.project_name}GatewayNsg-Ssh"
  network_security_group_name = azurerm_network_security_group.gateway_nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
  access                      = "Allow"
  direction                   = "Inbound"
  priority                    = 100
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_port_range      = "22"
  destination_address_prefix  = azurerm_network_interface.gateway_nic_pub.private_ip_address
}

resource "azurerm_network_security_rule" "gateway_nsg_http" {
  name                        = "${var.project_name}GatewayNsg-Http"
  network_security_group_name = azurerm_network_security_group.gateway_nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
  access                      = "Allow"
  direction                   = "Inbound"
  priority                    = 101
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_port_range      = "80"
  destination_address_prefix  = azurerm_network_interface.gateway_nic_pub.private_ip_address
}

resource "azurerm_network_security_rule" "gateway_nsg_tls" {
  name                        = "${var.project_name}GatewayNsg-Tls"
  network_security_group_name = azurerm_network_security_group.gateway_nsg.name
  resource_group_name         = azurerm_resource_group.rg.name
  access                      = "Allow"
  direction                   = "Inbound"
  priority                    = 102
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_port_range      = "443"
  destination_address_prefix  = azurerm_network_interface.gateway_nic_pub.private_ip_address
}

resource "azurerm_network_interface_security_group_association" "gateway_sec_group_assoc" {
  network_interface_id      = azurerm_network_interface.gateway_nic_pub.id
  network_security_group_id = azurerm_network_security_group.gateway_nsg.id
}

resource "azurerm_linux_virtual_machine" "gateway_vm" {
  name                            = "${var.project_name}GatewayVm"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = var.location
  size                            = "Standard_B1ls"
  admin_username                  = var.system_user # cannot be "admin" it'll fail
  admin_password                  = var.system_user_password
  disable_password_authentication = true
  tags                            = local.tags

  admin_ssh_key {
    username = var.system_user
    public_key = file(var.ssh_key_path_pub)
  }

  network_interface_ids = [
    azurerm_network_interface.gateway_nic_pub.id,
    azurerm_network_interface.gateway_nic_internal.id,
  ]

  source_image_reference {
    publisher = var.linux_image_publisher
    offer     = var.linux_image_offer
    sku       = var.linux_image_sku
    version   = var.linux_image_version
  }

  os_disk {
    caching              = var.disk_caching
    storage_account_type = var.disk_storage_account_type
  }

  connection {
    type        = "ssh"
    user        = self.admin_username
    host        = azurerm_public_ip.gateway_pub_ip.ip_address
    private_key = file(var.ssh_key_path_priv)
  }

  provisioner "remote-exec" {
    inline = ["echo 'hello' > hello"]
  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ${var.system_user} -i '${azurerm_public_ip.gateway_pub_ip.ip_address},' --private-key ${var.ssh_key_path_priv} --extra-vars 'user=${var.system_user}' ../ansible/play.focal.yml" 
  }
}
