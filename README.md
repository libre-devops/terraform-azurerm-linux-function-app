```hcl
resource "azurerm_service_plan" "service_plan" {
  for_each            = { for app in var.linux_function_apps : app.name => app if app.create_new_app_service_plan == true }
  name                = each.value.app_service_plan_name != null ? each.value.app_service_plan_name : "asp-${each.value.name}"
  resource_group_name = each.value.rg_name
  location            = each.value.location
  os_type             = each.value.os_type != null ? each.value.os_type : "Linux"
  sku_name            = each.value.sku_name
}

resource "azurerm_linux_function_app" "function_app" {
  for_each                                       = { for app in var.linux_function_apps : app.name => app }
  name                                           = each.value.name
  service_plan_id                                = each.value.service_plan_id != null ? each.value.service_plan_id : lookup(azurerm_service_plan.service_plan, each.key, null).id
  location                                       = each.value.location
  resource_group_name                            = each.value.rg_name
  app_settings                                   = each.value.create_new_app_insights == true && lookup(local.app_insights_map, each.value.app_insights_name, null) != null ? merge(each.value.app_settings, local.app_insights_map[each.value.app_insights_name]) : each.value.app_settings
  https_only                                     = each.value.https_only
  tags                                           = each.value.tags
  builtin_logging_enabled                        = each.value.builtin_logging_enabled
  client_certificate_enabled                     = each.value.client_certificate_enabled
  client_certificate_mode                        = each.value.client_certificate_mode
  client_certificate_exclusion_paths             = each.value.client_certificate_exclusion_paths
  daily_memory_time_quota                        = each.value.daily_memory_time_quota
  enabled                                        = each.value.enabled
  functions_extension_version                    = each.value.functions_extension_version
  ftp_publish_basic_authentication_enabled       = each.value.ftp_publish_basic_authentication_enable
  public_network_access_enabled                  = each.value.public_network_access_enabled
  key_vault_reference_identity_id                = each.value.key_vault_reference_identity_id
  virtual_network_subnet_id                      = each.value.virtual_network_subnet_id
  webdeploy_publish_basic_authentication_enabled = each.value.webdeploy_publish_basic_authentication_enabled
  zip_deploy_file                                = each.value.zip_deploy_file

  storage_account_name       = each.value.storage_account_name != null ? each.value.storage_account_name : null
  storage_account_access_key = each.value.storage_account_access_key

  storage_key_vault_secret_id   = each.value.storage_account_name == null ? each.value.storage_key_vault_secret_id : null
  storage_uses_managed_identity = each.value.storage_account_access_key == null ? each.value.storage_uses_managed_identity : null


  dynamic "identity" {
    for_each = each.value.identity_type == "SystemAssigned" ? [each.value.identity_type] : []
    content {
      type = each.value.identity_type
    }
  }

  dynamic "identity" {
    for_each = each.value.identity_type == "SystemAssigned, UserAssigned" ? [each.value.identity_type] : []
    content {
      type         = each.value.identity_type
      identity_ids = try(each.value.identity_ids, [])
    }
  }


  dynamic "identity" {
    for_each = each.value.identity_type == "UserAssigned" ? [each.value.identity_type] : []
    content {
      type         = each.value.identity_type
      identity_ids = length(try(each.value.identity_ids, [])) > 0 ? each.value.identity_ids : []
    }
  }

  dynamic "storage_account" {
    for_each = each.value.storage_account != null ? [each.value.storage_account] : []

    content {
      access_key   = storage_account.value.access_key
      account_name = storage_account.value.account_name
      name         = storage_account.value.name
      share_name   = storage_account.value.share_name
      type         = storage_account.value.type
      mount_path   = storage_account.value.mount_path
    }
  }


  dynamic "sticky_settings" {
    for_each = each.value.sticky_settings != null ? [each.value.sticky_settings] : []
    content {
      app_setting_names       = sticky_settings.value.app_setting_names
      connection_string_names = sticky_settings.value.connection_string_names
    }
  }

  dynamic "connection_string" {
    for_each = each.value.connection_string != null ? [each.value.connection_string] : []
    content {
      name  = connection_string.value.name
      type  = connection_string.value.type
      value = connection_string.value.value
    }
  }

  dynamic "backup" {
    for_each = each.value.backup != null ? [each.value.backup] : []
    content {
      name                = backup.value.name
      enabled             = backup.value.enabled
      storage_account_url = try(backup.value.storage_account_url, var.backup_sas_url)

      dynamic "schedule" {
        for_each = backup.value.schedule != null ? [backup.value.schedule] : []
        content {
          frequency_interval       = schedule.value.frequency_interval
          frequency_unit           = schedule.value.frequency_unit
          keep_at_least_one_backup = schedule.value.keep_at_least_one_backup
          retention_period_days    = schedule.value.retention_period_days
          start_time               = schedule.value.start_time
        }
      }
    }
  }

  dynamic "auth_settings" {
    for_each = each.value.auth_settings != null ? [each.value.auth_settings] : []

    content {
      enabled                        = auth_settings.value.enabled
      additional_login_parameters    = auth_settings.value.additional_login_parameters
      allowed_external_redirect_urls = auth_settings.value.allowed_external_redirect_urls
      default_provider               = auth_settings.value.default_provider
      issuer                         = auth_settings.value.issuer
      runtime_version                = auth_settings.value.runtime_version
      token_refresh_extension_hours  = auth_settings.value.token_refresh_extension_hours
      token_store_enabled            = auth_settings.value.token_store_enabled
      unauthenticated_client_action  = auth_settings.value.unauthenticated_client_action

      dynamic "active_directory" {
        for_each = auth_settings.value.active_directory != null ? [auth_settings.value.active_directory] : []

        content {
          client_id         = active_directory.value.client_id
          client_secret     = active_directory.value.client_secret
          allowed_audiences = active_directory.value.allowed_audiences
        }
      }

      dynamic "facebook" {
        for_each = auth_settings.value.facebook != null ? [auth_settings.value.facebook] : []

        content {
          app_id       = facebook.value.app_id
          app_secret   = facebook.value.app_secret
          oauth_scopes = facebook.value.oauth_scopes
        }
      }

      dynamic "google" {
        for_each = auth_settings.value.google != null ? [auth_settings.value.google] : []

        content {
          client_id     = google.value.client_id
          client_secret = google.value.client_secret
          oauth_scopes  = google.value.oauth_scopes
        }
      }

      dynamic "microsoft" {
        for_each = auth_settings.value.microsoft != null ? [auth_settings.value.microsoft] : []

        content {
          client_id     = microsoft.value.client_id
          client_secret = microsoft.value.client_secret
          oauth_scopes  = microsoft.value.oauth_scopes
        }
      }

      dynamic "twitter" {
        for_each = auth_settings.value.twitter != null ? [auth_settings.value.twitter] : []

        content {
          consumer_key    = twitter.value.consumer_key
          consumer_secret = twitter.value.consumer_secret
        }
      }

      dynamic "github" {
        for_each = auth_settings.value.github != null ? [auth_settings.value.github] : []

        content {
          client_id                  = github.value.client_id
          client_secret              = github.value.client_secret
          client_secret_setting_name = github.value.client_secret_setting_name
          oauth_scopes               = github.value.oauth_scopes
        }
      }
    }
  }

  dynamic "auth_settings_v2" {
    for_each = each.value.auth_settings_v2 != null ? [each.value.auth_settings_v2] : []

    content {
      auth_enabled                            = auth_settings_v2.value.auth_enabled
      runtime_version                         = auth_settings_v2.value.runtime_version
      config_file_path                        = auth_settings_v2.value.config_file_path
      require_authentication                  = auth_settings_v2.value.require_authentication
      unauthenticated_action                  = auth_settings_v2.value.unauthenticated_action
      default_provider                        = auth_settings_v2.value.default_provider
      excluded_paths                          = toset(auth_settings_v2.value.excluded_paths)
      require_https                           = auth_settings_v2.value.require_https
      http_route_api_prefix                   = auth_settings_v2.value.http_route_api_prefix
      forward_proxy_convention                = auth_settings_v2.value.forward_proxy_convention
      forward_proxy_custom_host_header_name   = auth_settings_v2.value.forward_proxy_custom_host_header_name
      forward_proxy_custom_scheme_header_name = auth_settings_v2.value.forward_proxy_custom_scheme_header_name

      dynamic "apple_v2" {
        for_each = auth_settings_v2.value.apple_v2 != null ? [auth_settings_v2.value.apple_v2] : []

        content {
          client_id                  = apple_v2.value.client_id
          client_secret_setting_name = apple_v2.value.client_secret_setting_name
          login_scopes               = toset(apple_v2.value.login_scopes)
        }
      }

      dynamic "active_directory_v2" {
        for_each = auth_settings_v2.value.active_directory_v2 != null ? [auth_settings_v2.value.active_directory_v2] : []

        content {
          client_id                            = active_directory_v2.value.client_id
          tenant_auth_endpoint                 = active_directory_v2.value.tenant_auth_endpoint
          client_secret_setting_name           = active_directory_v2.value.client_secret_setting_name
          client_secret_certificate_thumbprint = active_directory_v2.value.client_secret_certificate_thumbprint
          jwt_allowed_groups                   = toset(active_directory_v2.value.jwt_allowed_groups)
          jwt_allowed_client_applications      = toset(active_directory_v2.value.jwt_allowed_client_applications)
          www_authentication_disabled          = active_directory_v2.value.www_authentication_disabled
          allowed_groups                       = toset(active_directory_v2.value.allowed_groups)
          allowed_identities                   = toset(active_directory_v2.value.allowed_identities)
          allowed_applications                 = toset(active_directory_v2.value.allowed_applications)
          login_parameters                     = active_directory_v2.value.login_parameters
          allowed_audiences                    = toset(active_directory_v2.value.allowed_audiences)
        }
      }

      dynamic "azure_static_web_app_v2" {
        for_each = auth_settings_v2.value.azure_static_web_app_v2 != null ? [auth_settings_v2.value.azure_static_web_app_v2] : []

        content {
          client_id = azure_static_web_app_v2.value.client_id
        }
      }

      dynamic "custom_oidc_v2" {
        for_each = auth_settings_v2.value.custom_oidc_v2 != null ? [auth_settings_v2.value.custom_oidc_v2] : []

        content {
          name                          = custom_oidc_v2.value.name
          client_id                     = custom_oidc_v2.value.client_id
          openid_configuration_endpoint = custom_oidc_v2.value.openid_configuration_endpoint
          name_claim_type               = custom_oidc_v2.value.name_claim_type
          scopes                        = toset(custom_oidc_v2.value.scopes)
          client_credential_method      = custom_oidc_v2.value.client_credential_method
          client_secret_setting_name    = custom_oidc_v2.value.client_secret_setting_name
          authorisation_endpoint        = custom_oidc_v2.value.authorisation_endpoint
          token_endpoint                = custom_oidc_v2.value.token_endpoint
          issuer_endpoint               = custom_oidc_v2.value.issuer_endpoint
          certification_uri             = custom_oidc_v2.value.certification_uri
        }
      }


      dynamic "facebook_v2" {
        for_each = auth_settings_v2.value.facebook_v2 != null ? [auth_settings_v2.value.facebook_v2] : []

        content {
          graph_api_version       = facebook_v2.value.graph_api_version
          login_scopes            = toset(facebook_v2.value.login_scopes)
          app_id                  = facebook_v2_value.app_id
          app_secret_setting_name = facebook_v2.value.app_secret_setting_name
        }
      }

      dynamic "github_v2" {
        for_each = auth_settings_v2.value.github_v2 != null ? [auth_settings_v2.value.github_v2] : []

        content {
          client_id                  = github_v2.value.client_id
          client_secret_setting_name = github_v2.value.client_secret_setting_name
          login_scopes               = toset(github_v2.value.login_scopes)
        }
      }

      dynamic "google_v2" {
        for_each = auth_settings_v2.value.google_v2 != null ? [auth_settings_v2.value.google_v2] : []

        content {
          client_id                  = google_v2.value.client_id
          client_secret_setting_name = google_v2.value.client_secret_setting_name
          allowed_audiences          = toset(google_v2.value.allowed_audiences)
          login_scopes               = toset(google_v2.value.login_scopes)
        }
      }

      dynamic "microsoft_v2" {
        for_each = auth_settings_v2.value.microsoft_v2 != null ? [auth_settings_v2.value.microsoft_v2] : []

        content {
          client_id                  = microsoft_v2.value.client_id
          client_secret_setting_name = microsoft_v2.value.client_secret_setting_name
          allowed_audiences          = toset(microsoft_v2.value.allowed_audiences)
          login_scopes               = toset(microsoft_v2.value.login_scopes)
        }
      }

      dynamic "twitter_v2" {
        for_each = auth_settings_v2.value.twitter_v2 != null ? [auth_settings_v2.value.twitter_v2] : []
        content {
          consumer_key                 = twitter_v2.value.consumer_key
          consumer_secret_setting_name = twitter_v2.value.consumer_secret_setting_name
        }
      }

      dynamic "login" {
        for_each = auth_settings_v2.value.login != null ? [auth_settings_v2.value.login] : []

        content {
          logout_endpoint                   = login.value.logout_endpoint
          token_store_enabled               = login.value.token_store_enabled
          token_refresh_extension_time      = login.value.token_refresh_extension_time
          token_store_path                  = login.value.token_store_path
          token_store_sas_setting_name      = login.value.token_store_sas_setting_name
          preserve_url_fragments_for_logins = login.value.preserve_url_fragments_for_logins
          allowed_external_redirect_urls    = toset(login.value.allowed_external_redirect_urls)
          cookie_expiration_convention      = login.value.cookie_expiration_convention
          cookie_expiration_time            = login.value.cookie_expiration_time
          validate_nonce                    = login.value.validate_nonce
          nonce_expiration_time             = login.value.nonce_expiration_time
        }
      }
    }
  }


  dynamic "site_config" {
    for_each = each.value.site_config != null ? [each.value.site_config] : []

    content {
      always_on                                     = site_config.value.always_on
      api_definition_url                            = site_config.value.api_definition_url
      api_management_api_id                         = site_config.value.api_management_api_id
      app_command_line                              = site_config.value.app_command_line
      application_insights_connection_string        = site_config.value.application_insights_connection_string
      application_insights_key                      = site_config.value.application_insights_key
      container_registry_managed_identity_client_id = site_config.value.container_registry_managed_identity_client_id
      container_registry_use_managed_identity       = site_config.value.container_registry_use_managed_identity
      elastic_instance_minimum                      = site_config.value.elastic_instance_minimum
      ftps_state                                    = site_config.value.ftps_state
      health_check_path                             = site_config.value.health_check_path
      health_check_eviction_time_in_min             = site_config.value.health_check_eviction_time_in_min
      http2_enabled                                 = site_config.value.http2_enabled
      load_balancing_mode                           = site_config.value.load_balancing_mode
      managed_pipeline_mode                         = site_config.value.managed_pipeline_mode
      minimum_tls_version                           = site_config.value.minimum_tls_version
      pre_warmed_instance_count                     = site_config.value.pre_warmed_instance_count
      remote_debugging_enabled                      = site_config.value.remote_debugging_enabled
      remote_debugging_version                      = site_config.value.remote_debugging_version
      runtime_scale_monitoring_enabled              = site_config.value.runtime_scale_monitoring_enabled
      scm_minimum_tls_version                       = site_config.value.scm_minimum_tls_version
      scm_use_main_ip_restriction                   = site_config.value.scm_use_main_ip_restriction
      use_32_bit_worker                             = site_config.value.use_32_bit_worker
      app_scale_limit                               = site_config.value.app_scale_limit
      websockets_enabled                            = site_config.value.websockets_enabled
      vnet_route_all_enabled                        = site_config.value.vnet_route_all_enabled
      worker_count                                  = site_config.value.worker_count
      default_documents                             = toset(site_config.value.default_documents)

      dynamic "application_stack" {
        for_each = site_config.value.application_stack != null ? [site_config.value.application_stack] : []
        content {
          java_version            = application_stack.value.java_version
          dotnet_version          = application_stack.value.dotnet_version
          node_version            = application_stack.value.node_version
          python_version          = application_stack.value.python_version
          powershell_core_version = application_stack.value.powershell_core_version
          use_custom_runtime      = application_stack.value.use_custom_runtime

          dynamic "docker" {
            for_each = application_stack.value.docker != null ? application_stack.value.docker : []
            content {
              registry_url      = docker.value.registry_url
              registry_username = docker.value.registry_username
              registry_password = docker.value.registry_password
              image_name        = docker.value.image_name
              image_tag         = docker.value.image_tag
            }
          }
        }
      }

      dynamic "app_service_logs" {
        for_each = site_config.value.app_service_logs != null ? [site_config.value.app_service_logs] : []
        content {
          disk_quota_mb         = app_service_logs.value.disk_quota_mb
          retention_period_days = app_service_logs.value.retention_period_days
        }
      }

      dynamic "cors" {
        for_each = site_config.value.cors != null ? [site_config.value.cors] : []
        content {
          allowed_origins     = cors.value.allowed_origins
          support_credentials = cors.value.support_credentials
        }
      }

      dynamic "ip_restriction" {
        for_each = site_config.value.ip_restriction != null ? [site_config.value.ip_restriction] : []

        content {
          ip_address                = ip_restriction.value.ip_address
          service_tag               = ip_restriction.value.service_tag
          virtual_network_subnet_id = ip_restriction.value.virtual_network_subnet_id
          name                      = ip_restriction.value.name
          priority                  = ip_restriction.value.priority
          action                    = ip_restriction.value.action

          dynamic "headers" {
            for_each = ip_restriction.value.headers != null ? [ip_restriction.value.headers] : []

            content {
              x_azure_fdid      = headers.value.x_azure_fdid
              x_fd_health_probe = headers.value.x_fd_health_prob
              x_forwarded_for   = headers.value.x_forwarded_for
              x_forwarded_host  = headers.value.x_forwarded_host
            }
          }
        }
      }

      dynamic "scm_ip_restriction" {
        for_each = site_config.value.scm_ip_restriction != null ? [site_config.value.scm_ip_restriction] : []

        content {
          ip_address                = scm_ip_restriction.value.ip_address
          service_tag               = scm_ip_restriction.value.service_tag
          virtual_network_subnet_id = scm_ip_restriction.value.virtual_network_subnet_id
          name                      = scm_ip_restriction.value.name
          priority                  = scm_ip_restriction.value.priority
          action                    = scm_ip_restriction.value.action

          dynamic "headers" {
            for_each = scm_ip_restriction.value.headers != null ? [scm_ip_restriction.value.headers] : []

            content {
              x_azure_fdid      = headers.value.x_azure_fdid
              x_fd_health_probe = headers.value.x_fd_health_prob
              x_forwarded_for   = headers.value.x_forwarded_for
              x_forwarded_host  = headers.value.x_forwarded_host
            }
          }
        }
      }
    }
  }
}
```
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_application_insights.app_insights_workspace](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights) | resource |
| [azurerm_linux_function_app.function_app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_function_app) | resource |
| [azurerm_service_plan.service_plan](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_linux_function_apps"></a> [linux\_function\_apps](#input\_linux\_function\_apps) | List of Azure Linux Function Apps configurations | <pre>list(object({<br>    name                                           = string<br>    rg_name                                        = string<br>    location                                       = string<br>    create_new_app_service_plan                    = optional(bool, true)<br>    app_service_plan_name                          = optional(string)<br>    service_plan_id                                = optional(string)<br>    os_type                                        = optional(string)<br>    sku_name                                       = string<br>    app_settings                                   = map(string)<br>    https_only                                     = optional(bool)<br>    tags                                           = optional(map(string))<br>    builtin_logging_enabled                        = optional(bool)<br>    client_certificate_enabled                     = optional(bool)<br>    client_certificate_exclusion_paths             = optional(string)<br>    client_certificate_mode                        = optional(string)<br>    daily_memory_time_quota                        = optional(number)<br>    enabled                                        = optional(bool, true)<br>    functions_extension_version                    = optional(string, "~4")<br>    content_share_force_disabled                   = optional(bool)<br>    identity_type                                  = optional(string)<br>    ftp_publish_basic_authentication_enable        = optional(bool, false)<br>    public_network_access_enabled                  = optional(bool, true)<br>    key_vault_reference_identity_id                = optional(string)<br>    virtual_network_subnet_id                      = optional(string)<br>    webdeploy_publish_basic_authentication_enabled = optional(bool, false)<br>    zip_deploy_file                                = optional(string)<br><br>    identity_ids                                       = optional(list(string))<br>    storage_account_name                               = optional(string)<br>    storage_account_access_key                         = optional(string)<br>    storage_key_vault_secret_id                        = optional(string)<br>    storage_uses_managed_identity                      = optional(bool)<br>    create_new_app_insights                            = optional(bool, false)<br>    workspace_id                                       = optional(string)<br>    app_insights_name                                  = optional(string)<br>    app_insights_type                                  = optional(string, "Web")<br>    app_insights_daily_cap_in_gb                       = optional(number)<br>    app_insights_daily_data_cap_notifications_disabled = optional(bool, false)<br>    app_insights_internet_ingestion_enabled            = optional(bool)<br>    app_insights_internet_query_enabled                = optional(bool)<br>    app_insights_local_authentication_disabled         = optional(bool, true)<br>    app_insights_force_customer_storage_for_profile    = optional(bool, false)<br>    app_insights_sampling_percentage                   = optional(number, 100)<br>    storage_account = optional(object({<br>      access_key   = string<br>      account_name = string<br>      name         = string<br>      share_name   = string<br>      type         = string<br>      mount_path   = optional(string)<br>    }))<br>    sticky_settings = optional(object({<br>      app_setting_names       = optional(list(string))<br>      connection_string_names = optional(list(string))<br>    }))<br>    connection_string = optional(object({<br>      name  = optional(string)<br>      type  = optional(string)<br>      value = optional(string)<br>    }))<br>    backup = optional(object({<br>      name                = optional(string)<br>      enabled             = optional(bool)<br>      storage_account_url = optional(string)<br>      schedule = optional(object({<br>        frequency_interval       = optional(string)<br>        frequency_unit           = optional(string)<br>        keep_at_least_one_backup = optional(bool)<br>        retention_period_days    = optional(number)<br>        start_time               = optional(string)<br>      }))<br>    }))<br>    auth_settings_v2 = optional(object({<br>      auth_enabled                            = optional(bool)<br>      runtime_version                         = optional(string)<br>      config_file_path                        = optional(string)<br>      require_authentication                  = optional(bool)<br>      unauthenticated_action                  = optional(string)<br>      default_provider                        = optional(string)<br>      excluded_paths                          = optional(list(string))<br>      require_https                           = optional(bool)<br>      http_route_api_prefix                   = optional(string)<br>      forward_proxy_convention                = optional(string)<br>      forward_proxy_custom_host_header_name   = optional(string)<br>      forward_proxy_custom_scheme_header_name = optional(string)<br>      apple_v2 = optional(object({<br>        client_id                  = string<br>        client_secret_setting_name = string<br>        login_scopes               = list(string)<br>      }))<br>      active_directory_v2 = optional(object({<br>        client_id                            = string<br>        tenant_auth_endpoint                 = string<br>        client_secret_setting_name           = optional(string)<br>        client_secret_certificate_thumbprint = optional(string)<br>        jwt_allowed_groups                   = optional(list(string))<br>        jwt_allowed_client_applications      = optional(list(string))<br>        www_authentication_disabled          = optional(bool)<br>        allowed_groups                       = optional(list(string))<br>        allowed_identities                   = optional(list(string))<br>        allowed_applications                 = optional(list(string))<br>        login_parameters                     = optional(map(string))<br>        allowed_audiences                    = optional(list(string))<br>      }))<br>      azure_static_web_app_v2 = optional(object({<br>        client_id = string<br>      }))<br>      custom_oidc_v2 = optional(list(object({<br>        name                          = string<br>        client_id                     = string<br>        openid_configuration_endpoint = string<br>        name_claim_type               = optional(string)<br>        scopes                        = optional(list(string))<br>        client_credential_method      = string<br>        client_secret_setting_name    = string<br>        authorisation_endpoint        = string<br>        token_endpoint                = string<br>        issuer_endpoint               = string<br>        certification_uri             = string<br>      })))<br>      facebook_v2 = optional(object({<br>        app_id                  = string<br>        app_secret_setting_name = string<br>        graph_api_version       = optional(string)<br>        login_scopes            = optional(list(string))<br>      }))<br>      github_v2 = optional(object({<br>        client_id                  = string<br>        client_secret_setting_name = string<br>        login_scopes               = optional(list(string))<br>      }))<br>      google_v2 = optional(object({<br>        client_id                  = string<br>        client_secret_setting_name = string<br>        allowed_audiences          = optional(list(string))<br>        login_scopes               = optional(list(string))<br>      }))<br>      microsoft_v2 = optional(object({<br>        client_id                  = string<br>        client_secret_setting_name = string<br>        allowed_audiences          = optional(list(string))<br>        login_scopes               = optional(list(string))<br>      }))<br>      twitter_v2 = optional(object({<br>        consumer_key                 = string<br>        consumer_secret_setting_name = string<br>      }))<br>      login = optional(object({<br>        logout_endpoint                   = optional(string)<br>        token_store_enabled               = optional(bool)<br>        token_refresh_extension_time      = optional(number)<br>        token_store_path                  = optional(string)<br>        token_store_sas_setting_name      = optional(string)<br>        preserve_url_fragments_for_logins = optional(bool)<br>        allowed_external_redirect_urls    = optional(list(string))<br>        cookie_expiration_convention      = optional(string)<br>        cookie_expiration_time            = optional(string)<br>        validate_nonce                    = optional(bool)<br>        nonce_expiration_time             = optional(string)<br>      }))<br>    }))<br>    auth_settings = optional(object({<br>      enabled                        = optional(bool)<br>      additional_login_parameters    = optional(map(string))<br>      allowed_external_redirect_urls = optional(list(string))<br>      default_provider               = optional(string)<br>      issuer                         = optional(string)<br>      runtime_version                = optional(string)<br>      token_refresh_extension_hours  = optional(number)<br>      token_store_enabled            = optional(bool)<br>      unauthenticated_client_action  = optional(string)<br>      active_directory = optional(object({<br>        client_id         = optional(string)<br>        client_secret     = optional(string)<br>        allowed_audiences = optional(list(string))<br>      }))<br>      facebook = optional(object({<br>        app_id       = optional(string)<br>        app_secret   = optional(string)<br>        oauth_scopes = optional(list(string))<br>      }))<br>      google = optional(object({<br>        client_id     = optional(string)<br>        client_secret = optional(string)<br>        oauth_scopes  = optional(list(string))<br>      }))<br>      microsoft = optional(object({<br>        client_id     = optional(string)<br>        client_secret = optional(string)<br>        oauth_scopes  = optional(list(string))<br>      }))<br>      twitter = optional(object({<br>        consumer_key    = optional(string)<br>        consumer_secret = optional(string)<br>      }))<br>      github = optional(object({<br>        client_id                  = optional(string)<br>        client_secret              = optional(string)<br>        client_secret_setting_name = optional(string)<br>        oauth_scopes               = optional(list(string))<br>      }))<br>    }))<br>    site_config = optional(object({<br>      always_on                                     = optional(bool)<br>      api_definition_url                            = optional(string)<br>      api_management_api_id                         = optional(string)<br>      app_command_line                              = optional(string)<br>      application_insights_connection_string        = optional(string)<br>      application_insights_key                      = optional(string)<br>      container_registry_managed_identity_client_id = optional(string)<br>      container_registry_use_managed_identity       = optional(bool)<br>      elastic_instance_minimum                      = optional(number)<br>      ftps_state                                    = optional(string)<br>      health_check_path                             = optional(string)<br>      health_check_eviction_time_in_min             = optional(number)<br>      http2_enabled                                 = optional(bool)<br>      load_balancing_mode                           = optional(string)<br>      managed_pipeline_mode                         = optional(string)<br>      minimum_tls_version                           = optional(string)<br>      pre_warmed_instance_count                     = optional(number)<br>      remote_debugging_enabled                      = optional(bool)<br>      remote_debugging_version                      = optional(string)<br>      runtime_scale_monitoring_enabled              = optional(bool)<br>      scm_minimum_tls_version                       = optional(string)<br>      scm_use_main_ip_restriction                   = optional(bool)<br>      use_32_bit_worker                             = optional(bool)<br>      app_scale_limit                               = optional(number)<br>      websockets_enabled                            = optional(bool)<br>      vnet_route_all_enabled                        = optional(bool)<br>      worker_count                                  = optional(number)<br>      default_documents                             = optional(list(string))<br>      application_stack = optional(object({<br>        java_version                = optional(string)<br>        dotnet_version              = optional(string)<br>        use_dotnet_isolated_runtime = optional(bool)<br>        node_version                = optional(string)<br>        python_version              = optional(string)<br>        powershell_core_version     = optional(string)<br>        use_custom_runtime          = optional(bool)<br>        docker = optional(list(object({<br>          registry_url      = optional(string)<br>          registry_username = optional(string)<br>          registry_password = optional(string)<br>          image_name        = optional(string)<br>          image_tag         = optional(string)<br>        })))<br>      }))<br>      app_service_logs = optional(object({<br>        disk_quota_mb         = optional(number)<br>        retention_period_days = optional(number)<br>      }))<br>      cors = optional(object({<br>        allowed_origins     = optional(list(string))<br>        support_credentials = optional(bool)<br>      }))<br>      ip_restriction = optional(list(object({<br>        ip_address                = optional(string)<br>        service_tag               = optional(string)<br>        virtual_network_subnet_id = optional(string)<br>        name                      = optional(string)<br>        priority                  = optional(number)<br>        action                    = optional(string)<br>        headers = optional(object({<br>          x_azure_fdid      = optional(string)<br>          x_fd_health_probe = optional(string)<br>          x_forwarded_for   = optional(string)<br>          x_forwarded_host  = optional(string)<br>        }))<br>      })))<br>      scm_ip_restriction = optional(list(object({<br>        ip_address                = optional(string)<br>        service_tag               = optional(string)<br>        virtual_network_subnet_id = optional(string)<br>        name                      = optional(string)<br>        priority                  = optional(number)<br>        action                    = optional(string)<br>        headers = optional(object({<br>          x_azure_fdid      = optional(string)<br>          x_fd_health_probe = optional(string)<br>          x_forwarded_for   = optional(string)<br>          x_forwarded_host  = optional(string)<br>        }))<br>      })))<br>    }))<br>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_function_app_identities"></a> [function\_app\_identities](#output\_function\_app\_identities) | The identities of the Storage Accounts. |
| <a name="output_function_app_names"></a> [function\_app\_names](#output\_function\_app\_names) | The default name of the Linux Function Apps. |
| <a name="output_function_apps_custom_domain_verification_id"></a> [function\_apps\_custom\_domain\_verification\_id](#output\_function\_apps\_custom\_domain\_verification\_id) | The custom domain verification IDs of the Linux Function Apps. |
| <a name="output_function_apps_default_hostnames"></a> [function\_apps\_default\_hostnames](#output\_function\_apps\_default\_hostnames) | The default hostnames of the Linux Function Apps. |
| <a name="output_function_apps_outbound_ip_addresses"></a> [function\_apps\_outbound\_ip\_addresses](#output\_function\_apps\_outbound\_ip\_addresses) | The outbound IP addresses of the Linux Function Apps. |
| <a name="output_function_apps_possible_outbound_ip_addresses"></a> [function\_apps\_possible\_outbound\_ip\_addresses](#output\_function\_apps\_possible\_outbound\_ip\_addresses) | The possible outbound IP addresses of the Linux Function Apps. |
| <a name="output_function_apps_site_credentials"></a> [function\_apps\_site\_credentials](#output\_function\_apps\_site\_credentials) | The site credentials for the Linux Function Apps. |
| <a name="output_linux_function_apps_ids"></a> [linux\_function\_apps\_ids](#output\_linux\_function\_apps\_ids) | The IDs of the Linux Function Apps. |
| <a name="output_service_plans_ids"></a> [service\_plans\_ids](#output\_service\_plans\_ids) | The IDs of the Service Plans. |
