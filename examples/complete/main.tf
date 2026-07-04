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
        always_on           = true
        health_check_path   = "/api/health"
        http2_enabled       = true
        minimum_tls_version = "1.3"

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
