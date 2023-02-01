output "app_id" {
  description = "The app id of the application insights"
  value       = azurerm_application_insights.app_insights_workspace.*.app_id
}

output "app_insights_connection_string" {
  description = "The connection string for the application insights"
  value       = azurerm_application_insights.app_insights_workspace.*.connection_string
}

output "custom_domain_vertification_id" {
  value       = azurerm_linux_function_app.function_app.custom_domain_verification_id
  description = "The identifier for DNS txt ownership"
}

output "default_hostname" {
  value       = azurerm_linux_function_app.function_app.default_hostname
  description = "The default hostname for the function app"
}

output "fnc_app_id" {
  value       = azurerm_linux_function_app.function_app.id
  description = "The ID of the App Service."
}

output "fnc_app_name" {
  value       = azurerm_linux_function_app.function_app.name
  description = "The name of the App Service."
}

output "fnc_identity" {
  description = "The managed identity block from the Function app"
  value       = azurerm_linux_function_app.function_app.identity
}

output "fnc_site_credential" {
  value       = azurerm_linux_function_app.function_app.site_credential
  description = "The site credential block"
}

output "instrumentation_key" {
  description = "The instrumentation key of app insights"
  value       = azurerm_application_insights.app_insights_workspace.*.instrumentation_key
}

output "kind" {
  value       = azurerm_linux_function_app.function_app.kind
  description = "The kind of the functionapp"
}

output "outbound_ip_addresses" {
  value       = azurerm_linux_function_app.function_app.outbound_ip_addresses
  description = "A comma separated list of outbound IP addresses"
}

output "possible_outbound_ip_addresses" {
  value       = azurerm_linux_function_app.function_app.possible_outbound_ip_addresses
  description = "A comma separated list of outbound IP addresses. not all of which are necessarily in use"
}

output "site_credential" {
  value       = azurerm_linux_function_app.function_app.site_credential
  description = "The output of any site credentials"
}
