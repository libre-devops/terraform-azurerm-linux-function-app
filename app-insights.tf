resource "azurerm_application_insights" "app_insights_non_workspace" {
  count               = var.enable_app_insights == true && var.connect_app_insights_to_law_workspace == false ? 1 : 0
  name                = var.app_name
  location            = var.location
  resource_group_name = var.rg_name
  workspace_id        = var.workspace_id
  application_type    = var.app_insights_type
}

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

variable "app_insights_sampling_percentage" {
  type        = string
  description = "The app insights sampling percentage"
  default     = null
}

variable "app_insights_force_customer_storage_for_profile" {
  type        = bool
  description = "Whether the force profile is being enabled"
  default     = null
}

variable "app_insights_local_authentication_disabled" {
  type        = bool
  description = "Whether local authentication is disabled"
  default     = null
}

variable "app_insights_internet_ingestion_enabled" {
  type        = bool
  description = "Whether internet ingestion is enabled"
  default     = null
}

variable "app_insights_internet_query_enabled" {
  type        = bool
  description = "Whether or not your workspace can be queried from the internet"
  default     = null
}

variable "app_insights_daily_data_cap_notifications_disabled" {
  type        = bool
  description = "Whether notifications are enabled or not, defaults to false"
  default     = null
}

variable "app_insights_daily_cap_in_gb" {
  type        = string
  description = "The daily cap for app insights"
  default     = null
}

variable "enable_app_insights" {
  type        = bool
  description = "Whether app insights should be made"
  default     = false
}

variable "connect_app_insights_to_law_workspace" {
  type        = bool
  description = "Whether the app insights being made should be connected to a workspace id"
  default     = null
}

variable "workspace_id" {
  type        = string
  description = "if app insights count is set to true. the workspace id"
  default     = null
}

variable "app_insights_type" {
  type        = string
  description = "What the type of app insights to be made is"
  default     = null
}

