output "default_hostnames" {
  description = "Map of app name to default hostname."
  value       = { for k, a in azurerm_linux_function_app.this : k => a.default_hostname }
}

output "function_app_ids" {
  description = "Map of app name to app id."
  value       = { for k, a in azurerm_linux_function_app.this : k => a.id }
}

output "function_app_ids_zipmap" {
  description = "Map of app name to { name, id } for easy composition."
  value       = { for k, a in azurerm_linux_function_app.this : k => { name = a.name, id = a.id } }
}

output "function_apps" {
  description = "Map of app name to the full linux function app object. Sensitive as a whole because the object carries storage_account_access_key and the site credentials; the ids, hostnames, and identity maps alongside stay plain for composition."
  value       = azurerm_linux_function_app.this
  sensitive   = true
}

output "identity_principal_ids" {
  description = "Map of app name to { system_assigned, user_assigned } principal ids (nulls where an identity kind is absent)."
  value = {
    for k, a in azurerm_linux_function_app.this : k => {
      system_assigned = try(a.identity[0].principal_id, null)
      user_assigned   = try(azurerm_user_assigned_identity.this[k].principal_id, null)
    }
  }
}

output "possible_outbound_ip_address_lists" {
  description = "Map of app name to the possible outbound IP address list."
  value       = { for k, a in azurerm_linux_function_app.this : k => a.possible_outbound_ip_address_list }
}

output "service_plan_ids" {
  description = "Map of plan name (or app name for auto-created plans) to plan id."
  value = merge(
    { for k, p in azurerm_service_plan.this : k => p.id },
    { for k, p in azurerm_service_plan.auto : "asp-${k}" => p.id },
  )
}

output "storage_account_ids" {
  description = "Map of app name to the module-created storage account id (only apps with create_storage_account)."
  value       = { for k, s in azurerm_storage_account.this : k => s.id }
}

output "storage_account_names" {
  description = "Map of app name to the module-created storage account name (only apps with create_storage_account)."
  value       = { for k, s in azurerm_storage_account.this : k => s.name }
}

output "user_assigned_identity_ids" {
  description = "Map of app name to the module-created user assigned identity id (only apps with create_user_assigned_identity)."
  value       = { for k, i in azurerm_user_assigned_identity.this : k => i.id }
}
