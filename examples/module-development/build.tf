locals {
  rg_name                         = "rg-${var.short}-${var.loc}-${var.env}-01"
  vnet_name                       = "vnet-${var.short}-${var.loc}-${var.env}-01"
  function_app_subnet_name        = "FunctionAppSubnet"
  function_app_integration_subnet = "FunctionAppIntegrationSubnet"
  key_vault_subnet_name           = "KeyVaultSubnet"
  storage_subnet_name             = "StorageSubnet"
  nsg_name                        = "nsg-${var.short}-${var.loc}-${var.env}-01"
  ssh_public_key_name             = "ssh-${var.short}-${var.loc}-${var.env}-01"
  admin_username                  = "Local${title(var.short)}${title(var.env)}Admin"
  user_assigned_identity_name     = "uid-${var.short}-${var.loc}-${var.env}-01"
  key_vault_name                  = "kv-${var.short}-${var.loc}-${var.env}-01"
  function_app_name               = "func-${var.short}-${var.loc}-${var.env}-01"
  log_analytics_name              = "law-${var.short}-${var.loc}-${var.env}-01"
  storage_account_name            = "sa${var.short}${var.loc}${var.env}01"

  function_app_outbound_ips = flatten([
    for ips in values(module.linux_function_app.function_apps_possible_outbound_ip_addresses) :
    split(",", ips)
  ])
}

module "rg" {
  source = "libre-devops/rg/azurerm"

  rg_name  = local.rg_name
  location = local.location
  tags     = local.tags
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

  base_cidr = local.lookup_cidr[var.short][var.env][0]
  subnets = {
    (local.function_app_subnet_name) = {
      mask_size = 26
      netnum    = 0
    }
    (local.function_app_integration_subnet) = {
      mask_size = 26
      netnum    = 1
    }
    (local.key_vault_subnet_name) = {
      mask_size = 26
      netnum    = 2
    },
    (local.storage_subnet_name) = {
      mask_size = 26
      netnum    = 3
    }
  }
}

module "network" {
  source = "libre-devops/network/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  vnet_name          = local.vnet_name
  vnet_location      = module.rg.rg_location
  vnet_address_space = [module.subnet_calculator.base_cidr]

  subnets = {
    for i, name in module.subnet_calculator.subnet_names :
    name => {
      address_prefixes  = toset([module.subnet_calculator.subnet_ranges[i]])
      service_endpoints = name == local.key_vault_subnet_name ? ["Microsoft.KeyVault"] : name == local.storage_subnet_name ? ["Microsoft.Storage"] : []

      # Only assign delegation to subnet3
      delegation = name == local.function_app_subnet_name ? [
        {
          type = "Microsoft.Web/serverFarms"
        }
      ] : []
    }
  }
}

module "nsg" {
  source = "libre-devops/nsg/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  nsg_name              = local.nsg_name
  associate_with_subnet = true
  subnet_ids            = { for k, v in module.network.subnets_ids : k => v if k != "AzureBastionSubnet" }
  custom_nsg_rules = {
    "AllowVnetInbound" = {
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
    }
    "AllowClientInbound" = {
      priority                   = 101
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = chomp(data.http.user_ip.response_body)
      destination_address_prefix = "VirtualNetwork"
    }
  }
}

module "user_assigned_managed_identity" {
  source = "libre-devops/user-assigned-managed-identity/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  user_assigned_managed_identities = [
    {
      name = local.user_assigned_identity_name
    }
  ]
}

module "key_vault" {
  source = "github.com/libre-devops/terraform-azurerm-keyvault"

  key_vaults = [
    {
      rg_name  = module.rg.rg_name
      location = module.rg.rg_location
      tags     = module.rg.rg_tags

      name                            = local.key_vault_name
      enabled_for_deployment          = true
      enabled_for_disk_encryption     = true
      enabled_for_template_deployment = true
      enable_rbac_authorization       = true
      purge_protection_enabled        = false
      public_network_access_enabled   = true
      network_acls = {
        default_action             = "Deny"
        bypass                     = "AzureServices"
        ip_rules                   = [chomp(data.http.user_ip.response_body)]
        virtual_network_subnet_ids = [module.network.subnets_ids[local.key_vault_subnet_name]]
      }
    }
  ]
}

module "role_assignments" {
  source = "github.com/libre-devops/terraform-azurerm-role-assignment"

  role_assignments = [
    {
      principal_ids = [data.azurerm_client_config.current.object_id]
      role_names    = ["Key Vault Administrator"]
      scope         = module.rg.rg_id
    },
    {
      principal_ids = [module.user_assigned_managed_identity.managed_identity_principal_ids[local.user_assigned_identity_name]]
      role_names    = ["Key Vault Administrator"]
      scope         = module.rg.rg_id
    }
  ]
}

module "ssh_keys" {
  source = "libre-devops/ssh-key/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  ssh_keys = [
    {
      name = local.ssh_public_key_name
    }
  ]
}

module "key_vault_secrets" {
  source = "github.com/libre-devops/terraform-azurerm-key-vault-secrets"

  key_vault_id = module.key_vault.key_vault_ids[0]

  key_vault_secrets = [
    {
      secret_name              = "${local.admin_username}-password"
      generate_random_password = true
      content_type             = "text/plain"
      tags                     = module.rg.rg_tags
    },
    {
      secret_name              = "${local.admin_username}-ssh-private-key"
      generate_random_password = false
      secret_value             = module.ssh_keys.private_keys_openssh[local.ssh_public_key_name]
      content_type             = "text/plain"
      tags                     = module.rg.rg_tags
    },
  ]
}


module "sa" {
  source = "registry.terraform.io/libre-devops/storage-account/azurerm"
  storage_accounts = [
    {
      rg_name  = module.rg.rg_name
      location = module.rg.rg_location
      tags     = module.rg.rg_tags

      name          = local.storage_account_name
      identity_type = "SystemAssigned"

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
  storage_account_id = module.sa.storage_account_ids[local.storage_account_name]
  ip_rules           = concat([chomp(data.http.user_ip.response_body)], local.function_app_outbound_ips)
  virtual_network_subnet_ids = [
    module.network.subnets_ids[local.storage_subnet_name],
  ]
}

module "law" {
  source = "libre-devops/log-analytics-workspace/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  law_name                   = local.log_analytics_name
  law_sku                    = "PerGB2018"
  retention_in_days          = "30"
  daily_quota_gb             = "0.5"
  internet_ingestion_enabled = false
  internet_query_enabled     = false
}

module "linux_function_app" {
  source = "../../"

  depends_on = [module.law]

  # Application Insights Configuration
  linux_function_apps = [
    {
      rg_name  = module.rg.rg_name
      location = module.rg.rg_location
      tags     = module.rg.rg_tags

      name     = local.function_app_name
      os_type  = "Linux"
      sku_name = "EP1"

      app_settings = {
        "FUNCTIONS_WORKER_RUNTIME"               = "dotnet-isolated"
        "DOTNET_ENVIRONMENT"                     = "Production"
        "AzureWebJobsStorage__accountName"       = module.sa.storage_account_names[local.storage_account_name]
        "WEBSITE_USE_PLACEHOLDER_DOTNETISOLATED" = "1"
        "AzureSubscriptionId"                    = data.azurerm_client_config.current.subscription_id          # Replace with actual value
        "StorageAccountResourceGroup"            = module.rg.rg_name                                           # Replace with actual value
        "StorageAccountName"                     = module.sa.storage_account_names[local.storage_account_name] # Replace with actual value
        "KeyVaultUri"                            = module.key_vault.key_vault_uris[0]
      }
      builtin_logging_enabled       = true
      public_network_access_enabled = true
      virtual_network_subnet_id     = module.network.subnets_ids[local.function_app_subnet_name]
      identity_type                 = "SystemAssigned"
      storage_account_name          = module.sa.storage_account_names[local.storage_account_name]
      storage_uses_managed_identity = true


      create_new_app_insights                            = true
      workspace_id                                       = module.law.law_id
      app_insights_name                                  = "appi-${local.function_app_name}"
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
        ip_restriction = [
          {
            name       = "Allow-Client-IP"
            priority   = 100
            action     = "Allow"
            ip_address = "${chomp(data.http.user_ip.response_body)}/32"
          }
        ]
      }
    }
  ]
}

module "function_role_assignments" {
  source = "github.com/libre-devops/terraform-azurerm-role-assignment"

  role_assignments = [
    {
      principal_ids = [module.linux_function_app.function_app_identities[local.function_app_name].principal_id]
      role_names    = ["Key Vault Administrator", "Storage Blob Data Owner", "Storage Blob Data Reader", "Key Vault Secrets Officer", "Storage Account Contributor"]
      scope         = module.rg.rg_id
    },
  ]
}