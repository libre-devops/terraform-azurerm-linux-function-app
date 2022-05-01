variable "active_directory_auth_setttings" {
  description = "Acitve directory authentication provider settings for app service"
  type        = any
  default     = {}
}

variable "app_name" {
  description = "The name of the function app"
  type        = string
}

variable "app_service_plan_id" {
  description = "Id of the App Service Plan for Function App hosting"
  type        = string
}

variable "connection_strings" {
  description = "Connection strings for App Service"
  type        = list(map(string))
  default     = []
}

variable "function_app_application_settings" {
  description = "Function App application settings"
  type        = map(string)
  default     = {}
}

variable "function_app_version" {
  description = "Version of the function app runtime to use (Allowed values 2 or 3)"
  type        = string
  default     = "~3"
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

variable "os_type" {
  description = "A string indicating the Operating System type for this function app."
  type        = string
}

variable "rg_name" {
  description = "Resource group name"
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

variable "tags" {
  type        = map(string)
  description = "A map of the tags to use on the resources that are deployed with this module."
  default = {
    source = "terraform"
  }
}