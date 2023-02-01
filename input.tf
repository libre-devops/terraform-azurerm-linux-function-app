variable "active_directory_auth_setttings" {
  description = "Active directory authentication provider settings for app service"
  type        = any
  default     = {}
}

variable "app_insights_daily_cap_in_gb" {
  type        = string
  description = "The daily cap for app insights"
  default     = null
}

variable "app_insights_daily_data_cap_notifications_disabled" {
  type        = bool
  description = "Whether notifications are enabled or not, defaults to false"
  default     = null
}

variable "app_insights_force_customer_storage_for_profile" {
  type        = bool
  description = "Whether the force profile is being enabled"
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

variable "app_insights_local_authentication_disabled" {
  type        = bool
  description = "Whether local authentication is disabled"
  default     = null
}

variable "app_insights_sampling_percentage" {
  type        = string
  description = "The app insights sampling percentage"
  default     = null
}

variable "app_insights_type" {
  type        = string
  description = "What the type of app insights to be made is"
  default     = null
}

variable "app_name" {
  description = "The name of the function app"
  type        = string
}

variable "app_settings" {
  description = "Function App application settings"
  type        = map(any)
  default     = {}
}

variable "backup_sas_url" {
  description = "URL SAS to backup"
  type        = string
  default     = ""
}

variable "builtin_logging_enabled" {
  type        = bool
  description = "Whether AzureWebJobsDashboards should be enabled, default is true"
  default     = true
}

variable "client_certificate_enabled" {
  type        = bool
  description = "Whether client certificate auth is enabled, default is false"
  default     = false
}

variable "client_certificate_mode" {
  type        = string
  description = "The option for client certificates"
  default     = "Optional"
}

variable "connect_app_insights_to_law_workspace" {
  type        = bool
  description = "Whether the app insights being made should be connected to a workspace id"
  default     = null
}

variable "connection_strings" {
  description = "Connection strings for App Service"
  type        = list(map(string))
  default     = []
}

variable "daily_memory_time_quota" {
  type        = number
  description = "The amount of memory in gigabyte-seconds that your app can consume per day, defaults to 0"
  default     = 0
}

variable "enable_app_insights" {
  type        = bool
  description = "Whether app insights should be made"
  default     = false
}

variable "enabled" {
  type        = bool
  description = "Is the function app enabled? Default is true"
  default     = true
}

variable "force_disabled_content_share" {
  type        = bool
  description = "Should content share be disabled in storage account? Default is false"
  default     = false
}

variable "function_app_vnet_integration_enabled" {
  description = "Enable VNET integration with the Function App. `function_app_vnet_integration_subnet_id` is mandatory if enabled"
  type        = bool
  default     = false
}

variable "function_app_vnet_integration_subnet_id" {
  description = "ID of the subnet to associate with the Function App (VNet integration)"
  type        = string
  default     = null
}

variable "functions_extension_version" {
  type        = string
  description = "The function extension version"
}

variable "https_only" {
  description = "Disable http procotol and keep only https"
  type        = bool
  default     = true
}

variable "identity_ids" {
  description = "Specifies a list of user managed identity ids to be assigned to the VM."
  type        = list(string)
  default     = []
}

variable "identity_type" {
  description = "The Managed Service Identity Type of this Virtual Machine."
  type        = string
  default     = ""
}

variable "location" {
  description = "Azure location."
  type        = string
}

variable "rg_name" {
  description = "Resource group name"
  type        = string
}

variable "service_plan_id" {
  description = "Id of the App Service Plan for Function App hosting"
  type        = string
}

variable "settings" {
  description = "Specifies the Authentication enabled or not"
  default     = false
}

variable "site_config" {
  description = "Site config for App Service. See documentation https://www.terraform.io/docs/providers/azurerm/r/app_service.html#site_config. IP restriction attribute is not managed in this block."
  type        = any
  default     = {}
}

variable "storage_account_access_key" {
  description = "Access key the storage account to use. If null a new storage account is created"
  type        = string
  default     = null
}

variable "storage_account_name" {
  description = "Name of storage account"
  type        = string
}

variable "storage_container_name" {
  description = "The name of the storage container to keep backups"
  default     = null
}

variable "storage_key_vault_secret_id" {
  type        = string
  description = "The secret ID for the connection string of the storage account used by the function app"
  default     = ""
}

variable "storage_uses_managed_identity" {
  type        = bool
  description = "If you want the storage account to use a managed identity instead of a access key"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "A map of the tags to use on the resources that are deployed with this module."
  default = {
    source = "terraform"
  }
}

variable "workspace_id" {
  type        = string
  description = "if app insights count is set to true. the workspace id"
  default     = null
}
