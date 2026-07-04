# Linux Function App

Terraform module for Azure Linux function apps on normal App Service plans (Consumption Y1,
Elastic Premium, dedicated B/S/P, and App Service Environments), in the Libre DevOps style:
fast to get going, secure by default, flexible when it matters.

```hcl
module "linux_function_app" {
  source  = "libre-devops/linux-function-app/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids["rg-ldo-uks-dev-001"]
  location          = "uksouth"
  tags              = module.tags.tags

  function_apps = {
    "func-app-ldo-uks-dev-001" = {
      site_config = { application_stack = { python_version = "3.12" } }
    }
  }
}
```

That single entry gets a dedicated Y1 consumption plan, a keyless storage account (shared keys
disabled, TLS 1.2 floor, infrastructure encryption), a user-assigned identity granted the
documented role set BEFORE the app exists, identity-based host storage
(`storage_uses_managed_identity` plus the `AzureWebJobsStorage__clientId` hint), and secure
defaults the provider does not give you: `https_only`, FTP and WebDeploy basic auth OFF, and
the legacy builtin logging off. Every default has an explicit override.

- **Plans as a map.** Multiple apps share a plan via `service_plan_key`, `service_plan_id`
  brings your own, `app_service_environment_id` places a plan on an ASE, and an app that
  references no plan gets its own Y1 automatically.
- **Storage in three shapes.** Created (default), bring-your-own by id (grants intact, name
  parsed from the id), or `storage_key_vault_secret_id` where Key Vault holds the connection
  string and the caller owns everything. Keys-on is a first-class opt-out
  (`storage_shared_access_key_enabled = true`).
- **The content share trap, guarded.** Elastic Premium plans want an Azure Files content share
  and Files has no AAD data plane for it, so keyless apps on EP plans must set
  `content_share_force_disabled = true` (and deploy run-from-package) or flip keys on; a check
  enforces this for module-managed plans. Dedicated plans have no content share need.
- **Identity in every shape.** The default attaches both kinds with a module-created UAI
  (system-assigned plus deploy-during-create is a bootstrap deadlock); bring your own of any
  type; or none at all (keys-on apps).
- **A deploy story with its eyes open.** `zip_deploy_file` works on normal plans but relies on
  the basic-auth publishing profile this module disables by default (a validation enforces the
  pairing with `WEBSITE_RUN_FROM_PACKAGE` or `SCM_DO_BUILD_DURING_DEPLOYMENT` if you opt in).
  The honest default is the AAD push after apply: `az functionapp deployment source config-zip`
  with vendored dependencies, which is exactly what this repo's staged CI does (apply, deploy
  with a fresh login, curl the endpoints as the real gate, destroy).
- **Application Insights, AAD-ingestion ready.** Pass the connection string and the AI id and
  the module wires the app setting, the AAD ingestion auth string, and the Monitoring Metrics
  Publisher grant (gated on a plan-known flag).
- **The full provider surface.** site_config including application_stack (all runtimes plus
  docker), auth_settings and auth_settings_v2 in full, backup, connection strings, sticky
  settings, storage mounts, IP restrictions with headers, and VNet integration
  (`virtual_network_subnet_id`, `vnet_route_all_enabled`, storage network rules).

## Examples

- [`examples/minimal`](./examples/minimal) - the one-entry call above, applied and verified in CI.
- [`examples/complete`](./examples/complete) - a shared B1 plan hosting a keyless FastAPI API
  (App Insights with AAD ingestion, always_on, health checks, CORS, TLS 1.3) next to a keys-on
  node worker with a system-assigned identity.

Slots are a deliberate non-goal for now (`azurerm_linux_function_app_slot` is its own resource
and can compose with this module's outputs).
