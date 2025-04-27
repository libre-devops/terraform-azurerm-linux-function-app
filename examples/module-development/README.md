```hcl
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
```
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 4.27.0 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.5.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_function_role_assignments"></a> [function\_role\_assignments](#module\_function\_role\_assignments) | github.com/libre-devops/terraform-azurerm-role-assignment | n/a |
| <a name="module_key_vault"></a> [key\_vault](#module\_key\_vault) | github.com/libre-devops/terraform-azurerm-keyvault | n/a |
| <a name="module_key_vault_secrets"></a> [key\_vault\_secrets](#module\_key\_vault\_secrets) | github.com/libre-devops/terraform-azurerm-key-vault-secrets | n/a |
| <a name="module_law"></a> [law](#module\_law) | libre-devops/log-analytics-workspace/azurerm | n/a |
| <a name="module_linux_function_app"></a> [linux\_function\_app](#module\_linux\_function\_app) | ../../ | n/a |
| <a name="module_network"></a> [network](#module\_network) | libre-devops/network/azurerm | n/a |
| <a name="module_nsg"></a> [nsg](#module\_nsg) | libre-devops/nsg/azurerm | n/a |
| <a name="module_rg"></a> [rg](#module\_rg) | libre-devops/rg/azurerm | n/a |
| <a name="module_role_assignments"></a> [role\_assignments](#module\_role\_assignments) | github.com/libre-devops/terraform-azurerm-role-assignment | n/a |
| <a name="module_sa"></a> [sa](#module\_sa) | registry.terraform.io/libre-devops/storage-account/azurerm | n/a |
| <a name="module_shared_vars"></a> [shared\_vars](#module\_shared\_vars) | libre-devops/shared-vars/azurerm | n/a |
| <a name="module_ssh_keys"></a> [ssh\_keys](#module\_ssh\_keys) | libre-devops/ssh-key/azurerm | n/a |
| <a name="module_subnet_calculator"></a> [subnet\_calculator](#module\_subnet\_calculator) | libre-devops/subnet-calculator/null | n/a |
| <a name="module_user_assigned_managed_identity"></a> [user\_assigned\_managed\_identity](#module\_user\_assigned\_managed\_identity) | libre-devops/user-assigned-managed-identity/azurerm | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_storage_account_network_rules.rules](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account_network_rules) | resource |
| [random_string.entropy](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_key_vault.mgmt_kv](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |
| [azurerm_resource_group.mgmt_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_ssh_public_key.mgmt_ssh_key](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/ssh_public_key) | data source |
| [azurerm_user_assigned_identity.mgmt_user_assigned_id](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/user_assigned_identity) | data source |
| [http_http.user_ip](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_Regions"></a> [Regions](#input\_Regions) | Converts shorthand name to longhand name via lookup on map list | `map(string)` | <pre>{<br/>  "eus": "East US",<br/>  "euw": "West Europe",<br/>  "uks": "UK South",<br/>  "ukw": "UK West"<br/>}</pre> | no |
| <a name="input_env"></a> [env](#input\_env) | This is passed as an environment variable, it is for the shorthand environment tag for resource.  For example, production = prod | `string` | `"dev"` | no |
| <a name="input_loc"></a> [loc](#input\_loc) | The shorthand name of the Azure location, for example, for UK South, use uks.  For UK West, use ukw. Normally passed as TF\_VAR in pipeline | `string` | `"uks"` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of this resource | `string` | `"tst"` | no |
| <a name="input_short"></a> [short](#input\_short) | This is passed as an environment variable, it is for a shorthand name for the environment, for example hello-world = hw | `string` | `"libd"` | no |
| <a name="input_static_tags"></a> [static\_tags](#input\_static\_tags) | The tags variable | `map(string)` | <pre>{<br/>  "Contact": "info@cyber.scot",<br/>  "CostCentre": "671888",<br/>  "ManagedBy": "Terraform"<br/>}</pre> | no |

## Outputs

No outputs.
