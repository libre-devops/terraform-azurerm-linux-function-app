module "rg" {
  source = "libre-devops/rg/azurerm"

  rg_name  = "rg-${var.short}-${var.loc}-${var.env}-01"
  location = local.location
  tags     = local.tags
}

resource "azurerm_user_assigned_identity" "uid" {
  name                = "uid-${var.short}-${var.loc}-${var.env}-01"
  resource_group_name = module.rg.rg_name
  location            = module.rg.rg_location
  tags                = module.rg.rg_tags
}

module "shared_vars" {
  source = "libre-devops/shared-vars/azurerm"
}

locals {
  lookup_cidr = {
    for landing_zone, envs in module.shared_vars.cidrs : landing_zone => {
      for env, cidr in envs : env => cidr
    }
  }
}

module "subnet_calculator" {
  source = "libre-devops/subnet-calculator/null"

  base_cidr    = local.lookup_cidr[var.short][var.env][0]
  subnet_sizes = [26, 26, 26]
}

module "network" {
  source = "libre-devops/network/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  vnet_name          = "vnet-${var.short}-${var.loc}-${var.env}-01"
  vnet_location      = module.rg.rg_location
  vnet_address_space = [module.subnet_calculator.base_cidr]

  subnets = {
    for i, name in module.subnet_calculator.subnet_names :
    name => {
      address_prefixes  = toset([module.subnet_calculator.subnet_ranges[i]])
      service_endpoints = ["Microsoft.KeyVault", "Microsoft.Storage"]

      # Only assign delegation to subnet3
      delegation = name == "subnet3" ? [
        {
          type = "Microsoft.Web/serverFarms" # Delegation type for subnet3
        },
      ] : []
    }
  }
}


data "http" "user_ip" {
  url = "https://checkip.amazonaws.com"
}

module "role_assignments" {
  source = "github.com/libre-devops/terraform-azurerm-role-assignment"

  role_assignments = [
    {
      principal_ids = [azurerm_user_assigned_identity.uid.principal_id]
      role_names    = ["Key Vault Administrator", "Storage Blob Data Owner", "Storage Blob Data Reader"]
      scope         = module.rg.rg_id
    },
    {
      principal_ids = [module.linux_function_app.function_app_identities["fnc-${var.short}-${var.loc}-${var.env}-01"].principal_id]
      role_names    = ["Key Vault Administrator", "Storage Blob Data Owner", "Storage Blob Data Reader", "Key Vault Secrets Officer", "Storage Account Contributor"]
      scope         = module.rg.rg_id
    },
  ]
}
module "law" {
  source = "libre-devops/log-analytics-workspace/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  law_name                   = "law-${var.short}-${var.loc}-${var.env}-01"
  law_sku                    = "PerGB2018"
  retention_in_days          = "30"
  daily_quota_gb             = "0.5"
  internet_ingestion_enabled = false
  internet_query_enabled     = false
}

module "key_vault" {
  source = "libre-devops/keyvault/azurerm"

  key_vaults = [
    {
      name     = "kv-${var.short}-${var.loc}-${var.env}-tst-01"
      rg_name  = module.rg.rg_name
      location = module.rg.rg_location
      tags     = module.rg.rg_tags

      create_diagnostic_settings                      = true
      diagnostic_settings_enable_all_logs_and_metrics = true
      diagnostic_settings = {
        law_id = module.law.law_id
      }

      enabled_for_deployment          = true
      enabled_for_disk_encryption     = true
      enabled_for_template_deployment = true
      enable_rbac_authorization       = true
      purge_protection_enabled        = false
      public_network_access_enabled   = true
      network_acls = {
        default_action = "Deny"
        bypass         = "AzureServices"
        ip_rules       = concat([chomp(data.http.user_ip.response_body)], local.function_app_outbound_ips)
        virtual_network_subnet_ids = [
          module.network.subnets_ids["subnet1"],
          module.network.subnets_ids["subnet2"],
          module.network.subnets_ids["subnet3"]
        ]
      }
    },
  ]
}

module "sa" {
  source = "registry.terraform.io/libre-devops/storage-account/azurerm"
  storage_accounts = [
    {
      name     = "sa${var.short}${var.loc}${var.env}01"
      rg_name  = module.rg.rg_name
      location = module.rg.rg_location
      tags     = module.rg.rg_tags

      identity_type = "UserAssigned"
      identity_ids  = [azurerm_user_assigned_identity.uid.id]

      shared_access_keys_enabled                      = true
      create_diagnostic_settings                      = true
      diagnostic_settings_enable_all_logs_and_metrics = false
      diagnostic_settings = {
        law_id = module.law.law_id
        metric = [
          {
            category = "Transaction"
          }
        ]
      }
    },
  ]
}

resource "azurerm_storage_account_network_rules" "rules" {
  default_action     = "Deny"
  storage_account_id = module.sa.storage_account_ids["sa${var.short}${var.loc}${var.env}01"]
  ip_rules           = concat([chomp(data.http.user_ip.response_body)], local.function_app_outbound_ips)
  virtual_network_subnet_ids = [
    module.network.subnets_ids["subnet1"],
    module.network.subnets_ids["subnet2"],
    module.network.subnets_ids["subnet3"]
  ]
}


module "linux_function_app" {
  source = "../../"

  depends_on = [module.law]

  # Application Insights Configuration
  linux_function_apps = [
    {
      name     = "fnc-${var.short}-${var.loc}-${var.env}-01"
      rg_name  = module.rg.rg_name
      location = module.rg.rg_location
      tags     = module.rg.rg_tags

      os_type  = "Linux"
      sku_name = "FC1"
      app_settings = {
        "FUNCTIONS_WORKER_RUNTIME"               = "dotnet-isolated"
        "DOTNET_ENVIRONMENT"                     = "Production"
        "AzureWebJobsStorage__accountName"       = module.sa.storage_account_names["sa${var.short}${var.loc}${var.env}01"]
        "WEBSITE_USE_PLACEHOLDER_DOTNETISOLATED" = "1"
        "AzureSubscriptionId"                    = data.azurerm_client_config.current_creds.subscription_id                     # Replace with actual value
        "StorageAccountResourceGroup"            = module.rg.rg_name                                                            # Replace with actual value
        "StorageAccountName"                     = "${module.sa.storage_account_names["sa${var.short}${var.loc}${var.env}01"]}" # Replace with actual value
        "KeyVaultUri"                            = "kv-${var.short}-${var.loc}-${var.env}-tst-01"                               # Replace with actual value
      }
      builtin_logging_enabled       = true
      public_network_access_enabled = true
      virtual_network_subnet_id     = module.network.subnets_ids["subnet3"]
      identity_type                 = "SystemAssigned"
      storage_account_name          = module.sa.storage_account_names["sa${var.short}${var.loc}${var.env}01"]
      storage_uses_managed_identity = true


      create_new_app_insights                            = true
      workspace_id                                       = module.law.law_id
      app_insights_name                                  = "appi-fnc-${var.short}-${var.loc}-${var.env}-01"
      app_insights_type                                  = "web"
      app_insights_daily_cap_in_gb                       = 0.5
      app_insights_daily_data_cap_notifications_disabled = false
      app_insights_internet_ingestion_enabled            = true
      app_insights_internet_query_enabled                = true
      app_insights_local_authentication_disabled         = true
      app_insights_sampling_percentage                   = 100

      # Site Configuration
      site_config = {
        always_on              = true
        minimum_tls_version    = "1.3"
        vnet_route_all_enabled = true
        use_32_bit_worker      = false
        worker_count           = 1
        cors = {
          allowed_origins = ["https://portal.azure.com"]
        }
        application_stack = {
          dotnet_version              = "8.0"
          use_dotnet_isolated_runtime = true
        }
      }
    }
  ]
}

locals {
  function_app_outbound_ips = flatten([
    for ips in values(module.linux_function_app.function_apps_possible_outbound_ip_addresses) :
    split(",", ips)
  ])
}

