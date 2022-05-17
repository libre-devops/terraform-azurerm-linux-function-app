resource "azurerm_linux_function_app" "function_app" {
  name                = var.app_name
  service_plan_id     = var.service_plan_id
  location            = var.location
  resource_group_name = var.rg_name
  app_settings        = var.app_settings

  https_only                  = var.https_only
  builtin_logging_enabled     = var.builtin_logging_enabled
  client_certificate_enabled  = var.client_certificate_enabled
  client_certificate_mode     = var.client_certificate_mode
  daily_memory_time_quota     = var.daily_memory_time_quota
  enabled                     = var.enabled
  functions_extension_version = var.functions_extension_version

  storage_account_name       = var.storage_account_name != null ? var.storage_account_name : null
  storage_account_access_key = var.storage_account_access_key

  storage_key_vault_secret_id   = var.storage_account_name == null ? var.storage_key_vault_secret_id : null
  storage_uses_managed_identity = var.storage_account_access_key == null ? var.storage_uses_managed_identity : null

  dynamic "site_config" {
    for_each = lookup(var.settings, "site_config", {}) != {} ? [1] : []

    content {
      always_on                                     = lookup(var.settings.site_config, "always_on", false)
      api_definition_url                            = lookup(var.settings.site_config, "api_definition_url", null)
      api_management_api_id                         = lookup(var.settings.site_config, "api_management_api_id", null)
      app_command_line                              = lookup(var.settings.site_config, "app_command_line", null)
      application_insights_connection_string        = lookup(var.settings.site_config, "application_insights_connection_string", null)
      application_insights_key                      = lookup(var.settings.site_config, "application_insights_key", null)
      container_registry_managed_identity_client_id = lookup(var.settings.site_config, "container_registry_managed_identity_client_id", null)
      container_registry_use_managed_identity       = lookup(var.settings.site_config, "container_registry_use_managed_identity", false)
      elastic_instance_minimum                      = lookup(var.settings.site_config, "elastic_instance_minimum", null)
      ftps_state                                    = lookup(var.settings.site_config, "ftps_state", null)
      health_check_path                             = lookup(var.settings.site_config, "health_check_path", null)
      health_check_eviction_time_in_min             = lookup(var.settings.site_config, "health_check_eviction_time_in_min", null)
      http2_enabled                                 = lookup(var.settings.site_config, "http2_enabled", null)
      load_balancing_mode                           = lookup(var.settings.site_config, "load_balancing_mode", null)
      managed_pipeline_mode                         = lookup(var.settings.site_config, "managed_pipeline_mode", null)
      minimum_tls_version                           = lookup(var.settings.site_config, "minimum_tls_version", null)
      pre_warmed_instance_count                     = lookup(var.settings.site_config, "pre_warmed_instance_count", null)
      remote_debugging_enabled                      = lookup(var.settings.site_config, "remote_debugging_enabled", null)
      remote_debugging_version                      = lookup(var.settings.site_config, "remote_debugging_version", null)
      runtime_scale_monitoring_enabled              = lookup(var.settings.site_config, "runtime_scale_monitoring_enabled", null)
      scm_minimum_tls_version                       = lookup(var.settings.site_config, "scm_minimum_tls_version", null)
      scm_use_main_ip_restriction                   = lookup(var.settings.site_config, "scm_use_main_ip_restriction", null)
      use_32_bit_worker                             = lookup(var.settings.site_config, "use_32_bit_worker", null)
      app_scale_limit                               = lookup(var.settings.site_config, "app_scale_limit", null)
      websockets_enabled                            = lookup(var.settings.site_config, "websockets_enabled", null)
      vnet_route_all_enabled                        = lookup(var.settings.site_config, "vnet_route_all_enabled", null)
      worker_count                                  = lookup(var.settings.site_config, "worker_count", null)
      default_documents                             = [lookup(var.settings.site_config, "default_documents", false)]

      dynamic "application_stack" {
        for_each = lookup(var.settings.site_config, "application_stack", {}) != {} ? [1] : []
        content {
          java_version            = lookup(var.settings.site_config.application_stack, "java_version", null)
          dotnet_version          = lookup(var.settings.site_config.application_stack, "dotnet_version", null)
          node_version            = lookup(var.settings.site_config.application_stack, "node_version", null)
          python_version          = lookup(var.settings.site_config.application_stack, "python_version", null)
          powershell_core_version = lookup(var.settings.site_config.application_stack, "powershell_core_version", null)
          use_custom_runtime      = lookup(var.settings.site_config.application_stack, "use_custom_runtime", null)

          dynamic "docker" {
            for_each = lookup(var.settings.site_config.application_stack, "docker", {}) != {} ? [1] : []
            content {
              registry_url      = lookup(var.settings.site_config.application_stack.docker, "registry_url", null)
              registry_username = lookup(var.settings.site_config.application_stack.docker, "registry_url", null)
              registry_password = lookup(var.settings.site_config.application_stack.docker, "registry_password", null)
              image_name        = lookup(var.settings.site_config.application_stack.docker, "image_name", null)
              image_tag         = lookup(var.settings.site_config.application_stack.docker, "image_tag", null)
            }
          }
        }
      }

      dynamic "app_service_logs" {
        for_each = lookup(var.settings.site_config, "app_service_logs", {}) != {} ? [1] : []
        content {
          disk_quota_mb         = lookup(var.settings.app_service_logs, "disk_quota_mb", false)
          retention_period_days = lookup(var.settings.retention_period_days, "retention_period_days", false)
        }
      }

      dynamic "cors" {
        for_each = try(var.settings.site_config.cors, {})

        content {
          allowed_origins     = lookup(cors, "allowed_origins", null)
          support_credentials = lookup(cors, "support_credentials", null)
        }
      }

      dynamic "ip_restriction" {
        for_each = lookup(var.settings.site_config, "ip_restriction", {}) != {} ? [1] : []

        content {
          ip_address                = lookup(var.settings.site_config.ip_restriction, "ip_address", null)
          service_tag               = lookup(var.settings.site_config.ip_restriction, "service_tag", null)
          virtual_network_subnet_id = lookup(var.settings.site_config.ip_restriction, "virtual_network_subnet_id", null)
          name                      = lookup(var.settings.site_config.ip_restriction, "name", null)
          priority                  = lookup(var.settings.site_config.ip_restriction, "priority", null)
          action                    = lookup(var.settings.site_config.ip_restriction, "actuib", null)


          dynamic "headers" {
            for_each = lookup(var.settings.site_config.ip_restriction, "headers", {}) != {} ? [1] : []

            content {
              x_azure_fdid      = lookup(var.settings.site_config.ip_restriction.headers, "x_azure_fdid", null)
              x_fd_health_probe = lookup(var.settings.site_config.ip_restriction.headers, "x_fd_health_prob", null)
              x_forwarded_for   = lookup(var.settings.site_config.ip_restriction.headers, "x_forwarded_for", null)
              x_forwarded_host  = lookup(var.settings.site_config.ip_restriction.headers, "x_forwarded_host", null)
            }
          }
        }
      }

      dynamic "scm_ip_restriction" {
        for_each = lookup(var.settings.site_config, "scm_ip_restriction", {}) != {} ? [1] : []

        content {
          ip_address                = lookup(var.settings.site_config.scm_ip_restriction, "ip_address", null)
          service_tag               = lookup(var.settings.site_config.scm_ip_restriction, "service_tag", null)
          virtual_network_subnet_id = lookup(var.settings.site_config.scm_ip_restriction, "virtual_network_subnet_id", null)
          name                      = lookup(var.settings.site_config.scm_ip_restriction, "name", null)
          priority                  = lookup(var.settings.site_config.scm_ip_restriction, "priority", null)
          action                    = lookup(var.settings.site_config.scm_ip_restriction, "actuib", null)


          dynamic "headers" {
            for_each = lookup(var.settings.site_config.scm_ip_restriction, "headers", {}) != {} ? [1] : []

            content {
              x_azure_fdid      = lookup(var.settings.site_config.scm_ip_restriction.headers, "x_azure_fdid", null)
              x_fd_health_probe = lookup(var.settings.site_config.scm_ip_restriction.headers, "x_fd_health_prob", null)
              x_forwarded_for   = lookup(var.settings.site_config.scm_ip_restriction.headers, "x_forwarded_for", null)
              x_forwarded_host  = lookup(var.settings.site_config.scm_ip_restriction.headers, "x_forwarded_host", null)
            }
          }
        }
      }
    }
  }

  dynamic "auth_settings" {
    for_each = lookup(var.settings, "auth_settings", {}) != {} ? [1] : []

    content {
      enabled                        = lookup(var.settings.auth_settings, "enabled", false)
      additional_login_parameters    = lookup(var.settings.auth_settings, "additional_login_parameters", null)
      allowed_external_redirect_urls = lookup(var.settings.auth_settings, "allowed_external_redirect_urls", null)
      default_provider               = lookup(var.settings.auth_settings, "default_provider", null)
      issuer                         = lookup(var.settings.auth_settings, "issuer", null)
      runtime_version                = lookup(var.settings.auth_settings, "runtime_version", null)
      token_refresh_extension_hours  = lookup(var.settings.auth_settings, "token_refresh_extension_hours", null)
      token_store_enabled            = lookup(var.settings.auth_settings, "token_store_enabled", null)
      unauthenticated_client_action  = lookup(var.settings.auth_settings, "unauthenticated_client_action", null)

      dynamic "active_directory" {
        for_each = lookup(var.settings.auth_settings, "active_directory", {}) != {} ? [1] : []

        content {
          client_id         = var.settings.auth_settings.active_directory.client_id
          client_secret     = lookup(var.settings.auth_settings.active_directory, "client_secret", null)
          allowed_audiences = lookup(var.settings.auth_settings.active_directory, "allowed_audiences", null)
        }
      }

      dynamic "facebook" {
        for_each = lookup(var.settings.auth_settings, "facebook", {}) != {} ? [1] : []

        content {
          app_id       = var.settings.auth_settings.facebook.app_id
          app_secret   = var.settings.auth_settings.facebook.app_secret
          oauth_scopes = lookup(var.settings.auth_settings.facebook, "oauth_scopes", null)
        }
      }

      dynamic "google" {
        for_each = lookup(var.settings.auth_settings, "google", {}) != {} ? [1] : []

        content {
          client_id     = var.settings.auth_settings.google.client_id
          client_secret = var.settings.auth_settings.google.client_secret
          oauth_scopes  = lookup(var.settings.auth_settings.google, "oauth_scopes", null)
        }
      }

      dynamic "microsoft" {
        for_each = lookup(var.settings.auth_settings, "microsoft", {}) != {} ? [1] : []

        content {
          client_id     = var.settings.auth_settings.microsoft.client_id
          client_secret = var.settings.auth_settings.microsoft.client_secret
          oauth_scopes  = lookup(var.settings.auth_settings.microsoft, "oauth_scopes", null)
        }
      }

      dynamic "twitter" {
        for_each = lookup(var.settings.auth_settings, "twitter", {}) != {} ? [1] : []

        content {
          consumer_key    = var.settings.auth_settings.twitter.consumer_key
          consumer_secret = var.settings.auth_settings.twitter.consumer_secret
        }
      }

      dynamic "github" {
        for_each = lookup(var.settings.auth_settings, "github", {}) != {} ? [1] : []

        content {
          client_id                  = var.settings.auth_settings.github.client_id
          client_secret              = var.settings.auth_settings.github.client_secret
          client_secret_setting_name = var.settings.auth_settings.github.client_secret_setting_name
          oauth_scopes               = lookup(var.settings.auth_settings.github, "oauth_scopes", null)
        }
      }
    }
  }

  dynamic "connection_string" {
    for_each = var.connection_strings
    content {
      name  = lookup(connection_string.value, "name", null)
      type  = lookup(connection_string.value, "type", null)
      value = lookup(connection_string.value, "value", null)
    }
  }

  dynamic "sticky_settings" {
    for_each = lookup(var.settings, "sticky_settings", {}) != {} ? [1] : []
    content {
      app_setting_names       = lookup(var.settings.sticky_settings, "app_setting_names", false)
      connection_string_names = lookup(var.settings.sticky_settings, "connection_string_name", false)
    }
  }

  lifecycle {
    ignore_changes = [
      app_settings.WEBSITE_RUN_FROM_ZIP,
      app_settings.WEBSITE_RUN_FROM_PACKAGE,
      app_settings.MACHINEKEY_DecryptionKey,
      app_settings.WEBSITE_CONTENTAZUREFILECONNECTIONSTRING,
      app_settings.WEBSITE_CONTENTSHARE
    ]
  }

  dynamic "backup" {
    for_each = lookup(var.settings, "backup", {}) != {} ? [1] : []

    content {
      name                = var.settings.backup.name
      enabled             = var.settings.backup.enabled
      storage_account_url = try(var.settings.backup.storage_account_url, var.backup_sas_url)

      dynamic "schedule" {
        for_each = lookup(var.settings.backup, "schedule", {}) != {} ? [1] : []

        content {
          frequency_interval       = var.settings.backup.schedule.frequency_interval
          frequency_unit           = lookup(var.settings.backup.schedule, "frequency_unit", null)
          keep_at_least_one_backup = lookup(var.settings.backup.schedule, "keep_at_least_one_backup", null)
          retention_period_days    = lookup(var.settings.backup.schedule, "retention_period_days", null)
          start_time               = lookup(var.settings.backup.schedule, "start_time", null)
        }
      }
    }
  }

  dynamic "identity" {
    for_each = length(var.identity_ids) == 0 && var.identity_type == "SystemAssigned" ? [var.identity_type] : []
    content {
      type = var.identity_type
    }
  }

  dynamic "identity" {
    for_each = length(var.identity_ids) > 0 || var.identity_type == "UserAssigned" ? [var.identity_type] : []
    content {
      type         = var.identity_type
      identity_ids = length(var.identity_ids) > 0 ? var.identity_ids : []
    }
  }

  tags = var.tags
}

resource "azurerm_app_service_virtual_network_swift_connection" "function_vnet_integration" {
  count = var.function_app_vnet_integration_enabled ? 1 : 0

  app_service_id = azurerm_linux_function_app.function_app.id
  subnet_id      = var.function_app_vnet_integration_subnet_id
}