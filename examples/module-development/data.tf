data "azurerm_client_config" "current" {}

data "http" "user_ip" {
  url = "https://checkip.amazonaws.com"
}