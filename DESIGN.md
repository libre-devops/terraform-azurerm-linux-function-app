# terraform-azurerm-linux-function-app v-next design (delete before release)

Full rebuild of the legacy 2.x list-of-objects module onto the v-next scaffold, mirroring the
flex-consumption module's shape (the objects are extremely similar by design). Schema ground
truth extracted from azurerm 4.80 provider schema JSON; semantics verified against the provider
docs. Sibling module terraform-azurerm-linux-web-app follows the same design (new repo).

## Shape (mirrors flex)

- Header: `resource_group_id`, `location`, `tags` (parse rg name from the id).
- `service_plans` map: os_type "Linux" default, sku_name default "Y1" (cheapest to E2E),
  app_service_environment_id for ASE placement, zone_balancing_enabled, worker_count,
  maximum_elastic_worker_count, per_site_scaling_enabled. Multiple apps per plan.
- `function_apps` map: service_plan_key XOR service_plan_id XOR neither (auto Y1 plan
  "asp-<key>"). Runtime via site_config.application_stack (python/node/java/dotnet/
  powershell_core/custom + docker sub-block), NOT flex-style runtime_name/version.
- Full trees: site_config (app_service_logs, application_stack+docker, cors, ip_restriction,
  scm_ip_restriction), auth_settings, auth_settings_v2, backup, connection_string,
  sticky_settings, storage_account mounts, timeouts passthrough not needed.
- Identity: same as flex AFTER the dynamic fix: UAI created by default (attached
  "SystemAssigned, UserAssigned"), BYO any type, none at all expressible (dynamic block).

## Storage (provider modes differ from flex)

Provider XOR set: storage_account_name + access_key | storage_account_name +
storage_uses_managed_identity | storage_key_vault_secret_id. Module shapes:

- create_storage_account default true, keyless: storage_uses_managed_identity = true plus
  AzureWebJobsStorage__clientId app setting for the module UAI (same recipe as flex; Blob Data
  Owner + Blob/Queue/Table Contributor granted BEFORE the app). Pin AzureWebJobsStorage "" NOT
  needed here (provider wires MI settings properly for normal apps), VERIFY on live probe.
- BYO by id (parse name, grants intact), keys-on opt-out (storage_shared_access_key_enabled +
  access key), storage_key_vault_secret_id escape hatch (caller-owned).
- CONTENT SHARE TRAP (Y1/Elastic Premium): the platform needs a Files content share wired by
  WEBSITE_CONTENTAZUREFILECONNECTIONSTRING (keys only, Azure Files has no AAD data plane for
  this) . Keyless on Y1/EP therefore needs content_share_force_disabled = true plus
  WEBSITE_RUN_FROM_PACKAGE, or keys-on. Dedicated (B/S/P) plans have no content share need.
  PROBE LIVE, document the verdict table like flex. content_share_force_disabled exposed.

## Secure defaults (override provider defaults)

- https_only true (provider false), minimum_tls_version floor from provider default 1.2.
- ftp_publish_basic_authentication_enabled false (provider TRUE).
- webdeploy_publish_basic_authentication_enabled false (provider TRUE). NOTE: zip_deploy_file
  requires basic auth publishing profile, so in-module zip deploy conflicts with secure default;
  az CLI config-zip uses AAD and works with basic auth off (flex CI pattern carries over).
  zip_deploy_file stays a passthrough with a validation nudging WEBSITE_RUN_FROM_PACKAGE or
  SCM_DO_BUILD_DURING_DEPLOYMENT and basic auth on.
- functions_extension_version "~4" default kept explicit.

## App Insights

Same wiring as flex: app_insights_connection_string setting,
APPLICATIONINSIGHTS_AUTHENTICATION_STRING when module UAI, grant flag (plan-known)
for Monitoring Metrics Publisher.

## Deploy story and CI

zip_deploy_file WORKS on normal plans (unlike flex) but needs basic auth; the honest default
path is az functionapp deployment source config-zip (AAD) post-apply. CI: staged like flex
(apply stacks, deploy with fresh login, curl verify, destroy). Y1 cold starts need a generous
curl budget. Examples: minimal + complete (flex-style app/ payload with logging middleware).

## Slots

azurerm_linux_function_app_slot is a separate resource: consider-later enhancement, not day one.

## Web app module differences (terraform-azurerm-linux-web-app, new repo)

No storage attrs at all, no functions_extension_version/daily quota/builtin_logging;
adds client_affinity_enabled, logs block (application_logs/http_logs), site_config
auto_heal_setting, local_mysql_enabled, docker-rich application_stack (php/ruby/go/java_server).
Same plans/identity/AI/secure defaults/CI shape. No content share trap. Backup block needs a
SAS URL: expose but example-gate it off.
