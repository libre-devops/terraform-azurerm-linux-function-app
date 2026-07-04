# Tests for the module. azurerm is mocked (no credentials, no cloud):
#   terraform init -backend=false && terraform test

mock_provider "azurerm" {
  # Downstream resources parse these ids and compose these endpoints, so they need real shapes.
  mock_resource "azurerm_storage_account" {
    defaults = {
      id                 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.Storage/storageAccounts/stmock"
      primary_access_key = "bW9ja2tleQ=="
    }
  }

  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-mock"
      principal_id = "00000000-0000-0000-0000-00000000aaaa"
      client_id    = "00000000-0000-0000-0000-00000000bbbb"
    }
  }

  mock_resource "azurerm_service_plan" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.Web/serverFarms/asp-mock"
    }
  }
}

variables {
  resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001"
  location          = "uksouth"
  tags              = { Environment = "tst" }
}

# One app, nothing but the runtime: dedicated Y1 plan, keyless storage, a UAI granted the full
# documented role set before the app, identity-based host storage, and the secure defaults that
# override the provider's (https_only, basic auth off, builtin logging off).
run "fast_to_get_going" {
  command = apply

  variables {
    function_apps = {
      "func-app-ldo-uks-tst-01" = {
        site_config = { application_stack = { python_version = "3.12" } }
      }
    }
  }

  assert {
    condition     = azurerm_service_plan.auto["func-app-ldo-uks-tst-01"].sku_name == "Y1"
    error_message = "An app with no plan reference should get a dedicated Y1 plan."
  }

  assert {
    condition     = azurerm_storage_account.this["func-app-ldo-uks-tst-01"].shared_access_key_enabled == false
    error_message = "The created storage account should be keyless by default."
  }

  assert {
    condition     = azurerm_storage_account.this["func-app-ldo-uks-tst-01"].infrastructure_encryption_enabled == true
    error_message = "Infrastructure encryption should default on."
  }

  assert {
    condition     = azurerm_linux_function_app.this["func-app-ldo-uks-tst-01"].storage_uses_managed_identity == true
    error_message = "Keyless apps should authenticate host storage with the managed identity."
  }

  assert {
    condition     = azurerm_linux_function_app.this["func-app-ldo-uks-tst-01"].storage_account_access_key == null
    error_message = "No access key should be passed keyless."
  }

  assert {
    condition     = azurerm_linux_function_app.this["func-app-ldo-uks-tst-01"].app_settings["AzureWebJobsStorage__clientId"] == "00000000-0000-0000-0000-00000000bbbb"
    error_message = "The UAI client id hint should be wired so the host picks the module identity."
  }

  assert {
    condition     = length([for k, v in azurerm_role_assignment.storage : k if startswith(k, "func-app-ldo-uks-tst-01|")]) == 4
    error_message = "The full documented role set (Owner, Blob, Queue, Table) should be granted."
  }

  assert {
    condition     = azurerm_linux_function_app.this["func-app-ldo-uks-tst-01"].identity[0].type == "SystemAssigned, UserAssigned"
    error_message = "The module identity default should attach both kinds."
  }

  assert {
    condition     = azurerm_linux_function_app.this["func-app-ldo-uks-tst-01"].https_only == true
    error_message = "https_only should default true (the provider default is false)."
  }

  assert {
    condition     = azurerm_linux_function_app.this["func-app-ldo-uks-tst-01"].ftp_publish_basic_authentication_enabled == false && azurerm_linux_function_app.this["func-app-ldo-uks-tst-01"].webdeploy_publish_basic_authentication_enabled == false
    error_message = "Basic-auth publishing should default off (the provider default is on)."
  }

  assert {
    condition     = azurerm_linux_function_app.this["func-app-ldo-uks-tst-01"].builtin_logging_enabled == false
    error_message = "Builtin logging should default off (App Insights supersedes the dashboard)."
  }

  assert {
    condition     = azurerm_linux_function_app.this["func-app-ldo-uks-tst-01"].functions_extension_version == "~4"
    error_message = "The functions extension version should default to ~4."
  }
}

# Plans as a map: two apps share one plan; a third brings its own plan id.
run "plan_shapes" {
  command = apply

  variables {
    service_plans = {
      "asp-shared-ldo-uks-tst-01" = { sku_name = "EP1" }
    }
    function_apps = {
      "func-a-ldo-uks-tst-01" = {
        service_plan_key             = "asp-shared-ldo-uks-tst-01"
        content_share_force_disabled = true
        site_config                  = { application_stack = { python_version = "3.12" } }
      }
      "func-b-ldo-uks-tst-01" = {
        service_plan_key             = "asp-shared-ldo-uks-tst-01"
        content_share_force_disabled = true
        site_config                  = { application_stack = { node_version = "20" } }
      }
      "func-c-ldo-uks-tst-01" = {
        service_plan_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-x/providers/Microsoft.Web/serverFarms/asp-byo"
        site_config     = { application_stack = { python_version = "3.12" } }
      }
    }
  }

  assert {
    condition     = azurerm_service_plan.this["asp-shared-ldo-uks-tst-01"].sku_name == "EP1"
    error_message = "The shared plan should carry its configured sku."
  }

  assert {
    condition     = length(azurerm_service_plan.auto) == 0
    error_message = "No auto plans should be created when every app references a plan."
  }

  assert {
    condition     = azurerm_linux_function_app.this["func-c-ldo-uks-tst-01"].service_plan_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-x/providers/Microsoft.Web/serverFarms/asp-byo"
    error_message = "A brought plan id should be used verbatim."
  }
}

# BYO storage account by id: no account created, grants still land on the brought scope, and
# the provider gets the parsed account name.
run "byo_storage_by_id" {
  command = apply

  variables {
    function_apps = {
      "func-byo-ldo-uks-tst-01" = {
        create_storage_account = false
        storage_account_id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shared/providers/Microsoft.Storage/storageAccounts/stshared"
        site_config            = { application_stack = { python_version = "3.12" } }
      }
    }
  }

  assert {
    condition     = length(azurerm_storage_account.this) == 0
    error_message = "No storage account should be created."
  }

  assert {
    condition     = azurerm_linux_function_app.this["func-byo-ldo-uks-tst-01"].storage_account_name == "stshared"
    error_message = "The account name should be parsed from the brought id."
  }

  assert {
    condition     = alltrue([for k, v in azurerm_role_assignment.storage : v.scope == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shared/providers/Microsoft.Storage/storageAccounts/stshared" if startswith(k, "func-byo-ldo-uks-tst-01|")])
    error_message = "Role grants should land on the brought account."
  }
}

# The Key Vault escape hatch: the caller owns everything.
run "key_vault_secret_shape" {
  command = apply

  variables {
    function_apps = {
      "func-kv-ldo-uks-tst-01" = {
        create_storage_account        = false
        storage_key_vault_secret_id   = "https://kv-mock.vault.azure.net/secrets/func-storage/0000"
        wire_host_storage_settings    = false
        create_user_assigned_identity = false
        identity                      = { type = "SystemAssigned" }
        site_config                   = { application_stack = { python_version = "3.12" } }
      }
    }
  }

  assert {
    condition     = azurerm_linux_function_app.this["func-kv-ldo-uks-tst-01"].storage_key_vault_secret_id == "https://kv-mock.vault.azure.net/secrets/func-storage/0000"
    error_message = "The Key Vault secret id should pass through."
  }

  assert {
    condition     = azurerm_linux_function_app.this["func-kv-ldo-uks-tst-01"].storage_account_name == null && azurerm_linux_function_app.this["func-kv-ldo-uks-tst-01"].storage_uses_managed_identity == null
    error_message = "The Key Vault shape should carry no account name or managed identity flag."
  }

  assert {
    condition     = length(azurerm_role_assignment.storage) == 0
    error_message = "The Key Vault shape grants nothing."
  }
}

# The keys-on opt-out: connection-key auth from the created account.
run "keys_on_opt_out" {
  command = apply

  variables {
    function_apps = {
      "func-keys-ldo-uks-tst-01" = {
        storage_shared_access_key_enabled = true
        create_user_assigned_identity     = false
        identity                          = { type = "SystemAssigned" }
        site_config                       = { application_stack = { python_version = "3.12" } }
      }
    }
  }

  assert {
    condition     = azurerm_storage_account.this["func-keys-ldo-uks-tst-01"].shared_access_key_enabled == true
    error_message = "Keys should be enabled on request."
  }

  assert {
    condition     = azurerm_linux_function_app.this["func-keys-ldo-uks-tst-01"].storage_account_access_key != null && azurerm_linux_function_app.this["func-keys-ldo-uks-tst-01"].storage_uses_managed_identity == null
    error_message = "The created account's key should feed the app, with no managed identity flag."
  }
}

# An identity-less app: keys-on with no identity block at all.
run "no_identity_at_all" {
  command = apply

  variables {
    function_apps = {
      "func-noid-ldo-uks-tst-01" = {
        storage_shared_access_key_enabled = true
        create_user_assigned_identity     = false
        site_config                       = { application_stack = { python_version = "3.12" } }
      }
    }
  }

  assert {
    condition     = length(azurerm_linux_function_app.this["func-noid-ldo-uks-tst-01"].identity) == 0
    error_message = "No identity block should be present when none is created or brought."
  }

  assert {
    condition     = length(azurerm_user_assigned_identity.this) == 0 && length(azurerm_role_assignment.storage) == 0
    error_message = "No identity or grants should be created."
  }
}

# App Insights wiring: the connection string setting plus the AAD ingestion auth string and grant.
run "app_insights_wiring" {
  command = apply

  variables {
    function_apps = {
      "func-ai-ldo-uks-tst-01" = {
        app_insights_connection_string       = "InstrumentationKey=00000000-0000-0000-0000-000000000000;IngestionEndpoint=https://uksouth-1.in.applicationinsights.azure.com/"
        app_insights_id                      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.Insights/components/appi-mock"
        grant_app_insights_metrics_publisher = true
        site_config                          = { application_stack = { python_version = "3.12" } }
      }
    }
  }

  assert {
    condition     = azurerm_linux_function_app.this["func-ai-ldo-uks-tst-01"].app_settings["APPLICATIONINSIGHTS_CONNECTION_STRING"] != ""
    error_message = "The AI connection string setting should be wired."
  }

  assert {
    condition     = azurerm_linux_function_app.this["func-ai-ldo-uks-tst-01"].app_settings["APPLICATIONINSIGHTS_AUTHENTICATION_STRING"] == "ClientId=00000000-0000-0000-0000-00000000bbbb;Authorization=AAD"
    error_message = "The AAD ingestion auth string should be wired for the module identity."
  }

  assert {
    condition     = azurerm_role_assignment.app_insights["func-ai-ldo-uks-tst-01"].role_definition_name == "Monitoring Metrics Publisher"
    error_message = "The Monitoring Metrics Publisher grant should be created."
  }
}

# The zip_deploy_file pairing validation: basic auth plus a run-from-package marker.
run "zip_deploy_pairing_accepted" {
  command = plan

  variables {
    function_apps = {
      "func-zip-ldo-uks-tst-01" = {
        zip_deploy_file                                = "app.zip"
        webdeploy_publish_basic_authentication_enabled = true
        app_settings                                   = { WEBSITE_RUN_FROM_PACKAGE = "1" }
        site_config                                    = { application_stack = { python_version = "3.12" } }
      }
    }
  }

  assert {
    condition     = azurerm_linux_function_app.this["func-zip-ldo-uks-tst-01"].zip_deploy_file == "app.zip"
    error_message = "zip_deploy_file should pass through when correctly paired."
  }
}

run "rejects_zip_deploy_without_pairing" {
  command = plan

  variables {
    function_apps = {
      "func-badzip-ldo-uks-tst-01" = {
        zip_deploy_file = "app.zip"
        site_config     = { application_stack = { python_version = "3.12" } }
      }
    }
  }

  expect_failures = [var.function_apps]
}

run "rejects_two_plan_references" {
  command = plan

  variables {
    service_plans = { "asp-x-ldo-uks-tst-01" = {} }
    function_apps = {
      "func-bad-ldo-uks-tst-01" = {
        service_plan_key = "asp-x-ldo-uks-tst-01"
        service_plan_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-x/providers/Microsoft.Web/serverFarms/asp-y"
        site_config      = { application_stack = { python_version = "3.12" } }
      }
    }
  }

  expect_failures = [var.function_apps]
}

run "rejects_two_storage_shapes" {
  command = plan

  variables {
    function_apps = {
      "func-bad-ldo-uks-tst-01" = {
        storage_account_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-x/providers/Microsoft.Storage/storageAccounts/stx"
        storage_key_vault_secret_id = "https://kv-mock.vault.azure.net/secrets/x/0000"
        create_storage_account      = false
        site_config                 = { application_stack = { python_version = "3.12" } }
      }
    }
  }

  expect_failures = [var.function_apps]
}

run "rejects_identity_with_create_uai" {
  command = plan

  variables {
    function_apps = {
      "func-bad-ldo-uks-tst-01" = {
        identity    = { type = "SystemAssigned" }
        site_config = { application_stack = { python_version = "3.12" } }
      }
    }
  }

  expect_failures = [var.function_apps]
}

run "rejects_keyless_ep_with_content_share" {
  command = plan

  variables {
    service_plans = { "asp-ep-ldo-uks-tst-01" = { sku_name = "EP1" } }
    function_apps = {
      "func-ep-ldo-uks-tst-01" = {
        service_plan_key = "asp-ep-ldo-uks-tst-01"
        site_config      = { application_stack = { python_version = "3.12" } }
      }
    }
  }

  expect_failures = [check.keyless_elastic_premium_needs_no_content_share]
}

run "rejects_cors_wildcard_with_credentials" {
  command = plan

  variables {
    function_apps = {
      "func-bad-ldo-uks-tst-01" = {
        site_config = {
          application_stack = { python_version = "3.12" }
          cors = {
            allowed_origins     = ["*"]
            support_credentials = true
          }
        }
      }
    }
  }

  expect_failures = [var.function_apps]
}
