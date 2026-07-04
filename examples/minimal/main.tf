# Minimal call, and the module's whole point: one entry with nothing but a runtime gets a
# dedicated Y1 consumption plan, keyless storage, a user-assigned identity granted the
# documented role set, and identity-based host storage wired. Applied then destroyed in one
# CI run; the app/ package is pushed by the CI deploy stage.
locals {
  location  = lookup(var.regions, var.loc, "uksouth")
  rg_name   = "rg-${var.short}-${var.loc}-${terraform.workspace}-001"
  func_name = "func-lfa-${var.short}-${var.loc}-${terraform.workspace}-001"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

module "linux_function_app" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  function_apps = {
    (local.func_name) = {
      site_config = { application_stack = { python_version = "3.12" } }
    }
  }
}

output "default_hostname" {
  value = module.linux_function_app.default_hostnames[local.func_name]
}

output "function_app_name" {
  value = local.func_name
}

output "resource_group_name" {
  value = local.rg_name
}
