output "gateway_ip" {
  value = azurerm_public_ip.gateway_pub_ip.ip_address
  description = "Public IP of the gateway"
}
