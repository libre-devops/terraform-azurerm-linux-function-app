output "function_app_identities" {
  description = "The identities of the Storage Accounts."
  value = {
    for key, value in azurerm_linux_function_app.function_app : key =>
    length(value.identity) > 0 ? {
      type         = try(value.identity[0].type, null)
      principal_id = try(value.identity[0].principal_id, null)
      tenant_id    = try(value.identity[0].tenant_id, null)
      } : {
      type         = null
      principal_id = null
      tenant_id    = null
    }
  }
}

output "function_app_names" {
  description = "The default name of the Linux Function Apps."
  value       = { for app in azurerm_linux_function_app.function_app : app.name => app.name }
}

output "function_apps_custom_domain_verification_id" {
  description = "The custom domain verification IDs of the Linux Function Apps."
  value       = { for app in azurerm_linux_function_app.function_app : app.name => app.custom_domain_verification_id }
}

output "function_apps_default_hostnames" {
  description = "The default hostnames of the Linux Function Apps."
  value       = { for app in azurerm_linux_function_app.function_app : app.name => app.default_hostname }
}

output "function_apps_outbound_ip_addresses" {
  description = "The outbound IP addresses of the Linux Function Apps."
  value       = { for app in azurerm_linux_function_app.function_app : app.name => app.outbound_ip_addresses }
}

output "function_apps_possible_outbound_ip_addresses" {
  description = "The possible outbound IP addresses of the Linux Function Apps."
  value       = { for app in azurerm_linux_function_app.function_app : app.name => app.possible_outbound_ip_addresses }
}

output "function_apps_site_credentials" {
  description = "The site credentials for the Linux Function Apps."
  value       = { for app in azurerm_linux_function_app.function_app : app.name => app.site_credential }
}

output "linux_function_apps_ids" {
  description = "The IDs of the Linux Function Apps."
  value       = { for app in azurerm_linux_function_app.function_app : app.name => app.id }
}

output "service_plans_ids" {
  description = "The IDs of the Service Plans."
  value       = { for plan in azurerm_service_plan.service_plan : plan.name => plan.id }
}
