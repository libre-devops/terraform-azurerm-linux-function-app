resource "azurerm_application_insights" "app_insights_workspace" {
  count                                 = var.enable_app_insights == true && var.connect_app_insights_to_law_workspace == true ? 1 : 0
  name                                  = var.app_name
  location                              = var.location
  resource_group_name                   = var.rg_name
  workspace_id                          = var.workspace_id
  application_type                      = var.app_insights_type
  daily_data_cap_in_gb                  = var.app_insights_daily_cap_in_gb
  daily_data_cap_notifications_disabled = var.app_insights_daily_data_cap_notifications_disabled
  internet_ingestion_enabled            = try(var.app_insights_internet_ingestion_enabled, null)
  internet_query_enabled                = try(var.app_insights_internet_query_enabled, null)
  local_authentication_disabled         = try(var.app_insights_local_authentication_disabled, true)
  force_customer_storage_for_profiler   = try(var.app_insights_force_customer_storage_for_profile, false)
  sampling_percentage                   = try(var.app_insights_sampling_percentage, 100)
}

locals {
  app_insights_settings = {
    APPINSIGHTS_INSTRUMENTATIONKEY        = azurerm_application_insights.app_insights_workspace.*.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.app_insights_workspace.*.connection_string
  }

  app_insights_settings_map = {
    for pair in local.app_insights_settings : pair.key => pair.value if var.enable_app_insights == true
  }
}
