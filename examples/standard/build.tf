module "rg" {
  source = "registry.terraform.io/libre-devops/rg/azurerm"

  rg_name  = "rg-${var.short}-${var.loc}-${terraform.workspace}-build" // rg-ldo-euw-dev-build
  location = local.location                                            // compares var.loc with the var.regions var to match a long-hand name, in this case, "euw", so "westeurope"
  tags     = local.tags

  #  lock_level = "CanNotDelete" // Do not set this value to skip lock
}

module "law" {
  source = "registry.terraform.io/libre-devops/log-analytics-workspace/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  create_new_workspace       = true
  law_name                   = "law-${var.short}-${var.loc}-${terraform.workspace}-01"
  law_sku                    = "PerGB2018"
  retention_in_days          = "30"
  daily_quota_gb             = "0.5"
  internet_ingestion_enabled = true
  internet_query_enabled     = true
}

// This module does not consider for CMKs and allows the users to manually set bypasses
#checkov:skip=CKV2_AZURE_1:CMKs are not considered in this module
#checkov:skip=CKV2_AZURE_18:CMKs are not considered in this module
#checkov:skip=CKV_AZURE_33:Storage logging is not configured by default in this module
#tfsec:ignore:azure-storage-queue-services-logging-enabled tfsec:ignore:azure-storage-allow-microsoft-service-bypass #tfsec:ignore:azure-storage-default-action-deny
module "sa" {
  source = "registry.terraform.io/libre-devops/storage-account/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  storage_account_name            = "st${var.short}${var.loc}${terraform.workspace}01"
  access_tier                     = "Hot"
  identity_type                   = "SystemAssigned"
  allow_nested_items_to_be_public = true

  storage_account_properties = {

    // Set this block to enable network rules
    network_rules = {
      default_action = "Allow"
    }

    blob_properties = {
      versioning_enabled       = false
      change_feed_enabled      = false
      default_service_version  = "2020-06-12"
      last_access_time_enabled = false

      deletion_retention_policies = {
        days = 10
      }

      container_delete_retention_policy = {
        days = 10
      }
    }

    routing = {
      publish_internet_endpoints  = false
      publish_microsoft_endpoints = true
      choice                      = "MicrosoftRouting"
    }
  }
}

resource "azurerm_storage_container" "storage_container_function" {
  name                 = "blob-releases"
  storage_account_name = module.sa.sa_name
}

module "plan" {
  source = "registry.terraform.io/libre-devops/service-plan/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  app_service_plan_name          = "asp-${var.short}-${var.loc}-${terraform.workspace}-01"
  add_to_app_service_environment = false

  os_type  = "Linux"
  sku_name = "Y1"
}

#checkov:skip=CKV2_AZURE_145:TLS 1.2 is allegedly the latest supported as per hashicorp docs
module "fnc_app" {
  source = "libre-devops/linux-function-app/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  app_name        = "fnc-${var.short}-${var.loc}-${terraform.workspace}-01"
  service_plan_id = module.plan.service_plan_id

  connect_app_insights_to_law_workspace = true
  enable_app_insights                   = true
  workspace_id                          = module.law.law_id
  app_insights_name                     = "appi-${var.short}-${var.loc}-${terraform.workspace}-01"
  app_insights_type                     = "web"

  app_settings = {
    ARM_SUBSCRIPTION_ID = data.azurerm_client_config.current_creds.subscription_id
    ARM_TENANT_ID       = data.azurerm_client_config.current_creds.tenant_id
    FUNCTION_APP_NAME   = "fnc-${var.short}-${var.loc}-${terraform.workspace}-01"
    RESOURCE_GROUP_NAME = module.rg.rg_name
  }

  storage_account_name          = module.sa.sa_name
  storage_account_access_key    = module.sa.sa_primary_access_key
  storage_uses_managed_identity = true

  identity_type = "SystemAssigned"

  functions_extension_version = "~4"

  settings = {
    site_config = {
      minimum_tls_version = "1.2"
      http2_enabled       = true

      application_stack = {
        python_version = 3.9
      }
    }

    auth_settings = {
      enabled                       = false
      runtime_version               = "~1"
      unauthenticated_client_action = "AllowAnonymous"
    }
  }
}
