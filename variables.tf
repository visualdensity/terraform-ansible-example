variable "env" {
  type = string
  nullable = false
}

variable "project_name" {
  type = string
  nullable = false
}

variable "location" {
  type = string
  default = "Australia Southeast"
}

variable "system_user" {
  type     = string
  nullable = false
  default  = "terrauser"
}

variable "system_user_password" {
  type      = string
  sensitive = true
  nullable  = false
}

variable "vnet_address_space" {
  type = list(any)
  default = ["10.15.0.0/16"]
}

variable "subnets" {
  type = map(any)
  default = {
    dmz_subnet = {
      name = "DmzSubnet"
      address_prefixes = ["10.15.1.0/24"]
    }

    # AzureBastionSubnet name must be used for it to work
    bastion_subnet = {
      name = "AzureBastionSubnet"
      address_prefixes = ["10.15.250.0/26"]
    }
  } #default
} ##subnets

variable "ssh_key_path_pub" {
  type = string
  default = "~/.ssh/id_rsa.pub"
}

variable "ssh_key_path_priv" {
  type = string
  default = "~/.ssh/id_rsa"
}
