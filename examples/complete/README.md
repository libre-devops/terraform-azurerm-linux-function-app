<!--
  Header for the complete example README. Edit this file, then run `just docs`
  (or ./Sort-LdoTerraform.ps1 -IncludeExamples) to regenerate the section between the markers.
  The example's main.tf is embedded into the README automatically (see .terraform-docs.yml).
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="200">
    </picture>
  </a>
</div>

# Complete example

A shared plan hosting a keyless FastAPI API (Application Insights with AAD ingestion, scale tuning, CORS) next to a keys-on connection-string worker on a different runtime.

[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)

<!-- BEGIN_TF_DOCS -->
## Example configuration

```hcl
# Every feature of the module's infrastructure surface on one shared dedicated plan: keyless
# identity auth and the keys-on opt-out side by side, Application Insights with AAD ingestion,
# always_on (a dedicated-plan luxury Y1 does not allow), health checks, CORS, and TLS floors.
# Backup and storage mounts are exposed by the module but not exercised here (both need
# caller-owned secrets: a SAS URL and a share key). Code deployment happens in the CI deploy
# stage, not this apply. Applied then destroyed in one CI run.
locals {
  location  = lookup(var.regions, var.loc, "uksouth")
  rg_name   = "rg-${var.short}-${var.loc}-${terraform.workspace}-002"
  law_name  = "log-${var.short}-${var.loc}-${terraform.workspace}-002"
  appi_name = "appi-${var.short}-${var.loc}-${terraform.workspace}-002"
  api_name  = "func-lapi-${var.short}-${var.loc}-${terraform.workspace}-002"
  wkr_name  = "func-lwkr-${var.short}-${var.loc}-${terraform.workspace}-002"
  plan_name = "asp-shared-${var.short}-${var.loc}-${terraform.workspace}-002"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
  additional_tags = { Application = "terraform-azurerm-linux-function-app" }
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

module "log_analytics" {
  source  = "libre-devops/log-analytics-workspace/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  log_analytics_workspaces = { (local.law_name) = {} }
}

module "application_insights" {
  source  = "libre-devops/application-insights/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  application_insights = {
    (local.appi_name) = {
      workspace_id = module.log_analytics.workspace_ids[local.law_name]
    }
  }
}

module "linux_function_app" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  # One dedicated B1 plan shared by both apps: dedicated plans have no content share need, so
  # keyless works without any run-from-package caveat, and always_on becomes available.
  service_plans = {
    (local.plan_name) = {
      sku_name = "B1"
    }
  }

  function_apps = {
    # The API: keyless identity-authenticated storage (the secure default), Application
    # Insights with AAD ingestion, and the site_config surface exercised.
    (local.api_name) = {
      service_plan_key = local.plan_name

      app_insights_connection_string       = module.application_insights.connection_strings[local.appi_name]
      app_insights_id                      = module.application_insights.ids[local.appi_name]
      grant_app_insights_metrics_publisher = true

      site_config = {
        always_on                         = true
        health_check_path                 = "/api/health"
        health_check_eviction_time_in_min = 5
        http2_enabled                     = true
        minimum_tls_version               = "1.3"

        application_stack = { python_version = "3.12" }

        cors = {
          allowed_origins = ["https://portal.azure.com"]
        }
      }

      tags = { Component = "api" }
    }

    # The worker: same shared plan, the keys-on opt-out with a system-assigned identity only,
    # a deliberately different runtime, and an always-off basic-auth surface all the same.
    (local.wkr_name) = {
      service_plan_key = local.plan_name

      storage_shared_access_key_enabled = true
      create_user_assigned_identity     = false
      identity                          = { type = "SystemAssigned" }

      site_config = {
        always_on         = true
        application_stack = { node_version = "20" }
      }

      tags = { Component = "worker" }
    }
  }
}

output "api_default_hostname" {
  value = module.linux_function_app.default_hostnames[local.api_name]
}

output "api_function_app_name" {
  value = local.api_name
}

output "resource_group_name" {
  value = local.rg_name
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_application_insights"></a> [application\_insights](#module\_application\_insights) | libre-devops/application-insights/azurerm | ~> 4.0 |
| <a name="module_linux_function_app"></a> [linux\_function\_app](#module\_linux\_function\_app) | ../../ | n/a |
| <a name="module_log_analytics"></a> [log\_analytics](#module\_log\_analytics) | libre-devops/log-analytics-workspace/azurerm | ~> 4.0 |
| <a name="module_rg"></a> [rg](#module\_rg) | libre-devops/rg/azurerm | ~> 4.0 |
| <a name="module_tags"></a> [tags](#module\_tags) | libre-devops/tags/azurerm | ~> 4.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployed_branch"></a> [deployed\_branch](#input\_deployed\_branch) | Git branch the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_branch. | `string` | `""` | no |
| <a name="input_deployed_repo"></a> [deployed\_repo](#input\_deployed\_repo) | Repository URL the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_repo. | `string` | `""` | no |
| <a name="input_loc"></a> [loc](#input\_loc) | Outfix: short Azure region code used in resource names (for example uks). | `string` | `"uks"` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | Map of short region codes to Azure region slugs. | `map(string)` | <pre>{<br/>  "eus": "eastus",<br/>  "euw": "westeurope",<br/>  "uks": "uksouth",<br/>  "ukw": "ukwest"<br/>}</pre> | no |
| <a name="input_short"></a> [short](#input\_short) | Infix: short product code used in resource names. | `string` | `"ldo"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_default_hostname"></a> [api\_default\_hostname](#output\_api\_default\_hostname) | n/a |
| <a name="output_api_function_app_name"></a> [api\_function\_app\_name](#output\_api\_function\_app\_name) | n/a |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | n/a |
<!-- END_TF_DOCS -->
