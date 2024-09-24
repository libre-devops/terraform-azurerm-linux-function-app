resource "azurerm_application_insights" "app_insights_workspace" {
  for_each = {
    for app in var.linux_function_apps : app.name => app
  }

  name                                  = each.value.create_new_app_insights == true ? each.value.app_insights_name : "appi=${each.value.name}"
  location                              = each.value.location
  resource_group_name                   = each.value.rg_name
  workspace_id                          = each.value.create_new_app_insights == true ? each.value.workspace_id : null
  application_type                      = each.value.create_new_app_insights == true ? each.value.app_insights_type : null
  daily_data_cap_in_gb                  = try(each.value.app_insights_daily_cap_in_gb, null)
  daily_data_cap_notifications_disabled = try(each.value.app_insights_daily_data_cap_notifications_disabled, false)
  internet_ingestion_enabled            = try(each.value.app_insights_internet_ingestion_enabled, null)
  internet_query_enabled                = try(each.value.app_insights_internet_query_enabled, null)
  local_authentication_disabled         = try(each.value.app_insights_local_authentication_disabled, true)
  force_customer_storage_for_profiler   = try(each.value.app_insights_force_customer_storage_for_profile, false)
  sampling_percentage                   = try(each.value.app_insights_sampling_percentage, 100)
  tags                                  = try(each.value.tags, {})

  lifecycle {
    ignore_changes = [
      name,
      workspace_id,
      application_type
    ]
  }
}

locals {
  app_insights_map = {
    for app_insights in azurerm_application_insights.app_insights_workspace : app_insights.name => {
      APPINSIGHTS_INSTRUMENTATIONKEY        = app_insights.instrumentation_key,
      APPLICATIONINSIGHTS_CONNECTION_STRING = app_insights.connection_string
    }
  }
}
