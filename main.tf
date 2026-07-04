locals {
  rg = provider::azurerm::parse_resource_id(var.resource_group_id)

  # Apps that reference no plan get their own dedicated Y1 consumption plan.
  auto_plan_apps = { for k, a in var.function_apps : k => a if a.service_plan_key == null && a.service_plan_id == null }

  # One user-assigned identity per app unless the caller opts out or brings their own
  # (system-assigned plus deploy-during-create is a bootstrap deadlock), or caller-supplied.
  uai_apps = { for k, a in var.function_apps : k => a if a.create_user_assigned_identity }

  storage_create_apps = { for k, a in var.function_apps : k => a if a.create_storage_account }

  # st<flattened app key>, trimmed to the 24-char storage limit.
  storage_account_names = {
    for k, a in local.storage_create_apps : k => coalesce(
      a.storage_account_name,
      substr("st${replace(replace(lower(k), "-", ""), "_", "")}", 0, 24),
    )
  }

  # Null means no identity at all (keys-on or Key Vault shape apps that want none:
  # create_user_assigned_identity false with no identity block); the resource's identity block
  # is dynamic on this.
  identity_blocks = {
    for k, a in var.function_apps : k => (
      a.identity != null ? a.identity :
      a.create_user_assigned_identity ? {
        type         = "SystemAssigned, UserAssigned"
        identity_ids = [azurerm_user_assigned_identity.this[k].id]
      } : null
    )
  }

  # The account name fed to the provider: created account's, or parsed from a brought id.
  # Null for the Key Vault shape (storage_key_vault_secret_id carries everything).
  host_storage_account_names = {
    for k, a in var.function_apps : k => (
      a.create_storage_account ? azurerm_storage_account.this[k].name :
      a.storage_account_id != null ? provider::azurerm::parse_resource_id(a.storage_account_id).resource_name : null
    )
  }

  # Keyless is the default: the host authenticates with the managed identity
  # (storage_uses_managed_identity); keys-on is the opt-out and feeds the access key instead.
  storage_uses_mi = {
    for k, a in var.function_apps : k => (
      local.host_storage_account_names[k] != null && !a.storage_shared_access_key_enabled ? true : null
    )
  }

  storage_access_keys = {
    for k, a in var.function_apps : k => (
      local.host_storage_account_names[k] != null && a.storage_shared_access_key_enabled ?
      coalesce(a.storage_account_access_key, try(azurerm_storage_account.this[k].primary_access_key, null)) : null
    )
  }

  # The documented role set, granted to the module-created identity BEFORE the app exists so the
  # host works first try. Scope is the created account or the brought one (the module has the id
  # either way); the Key Vault shape grants nothing.
  storage_grant_scopes = {
    for k, a in var.function_apps : k => (
      a.create_storage_account ? azurerm_storage_account.this[k].id : a.storage_account_id
    ) if a.create_user_assigned_identity && (a.create_storage_account || a.storage_account_id != null)
  }

  storage_grants = merge([
    for k, scope in local.storage_grant_scopes : {
      for role in var.function_apps[k].storage_role_names : "${k}|${role}" => {
        app   = k
        scope = scope
        role  = role
      }
    }
  ]...)

  # Keyless with the module UAI needs the client id hint so the host picks the right identity
  # (the provider's storage_uses_managed_identity alone defaults to the system identity). With a
  # brought identity the caller owns this setting, same as they own the role grants.
  host_storage_settings = {
    for k, a in var.function_apps : k => (
      a.wire_host_storage_settings && local.storage_uses_mi[k] == true && a.create_user_assigned_identity ? {
        AzureWebJobsStorage__clientId = azurerm_user_assigned_identity.this[k].client_id
      } : {}
    )
  }

  app_insights_settings = {
    for k, a in var.function_apps : k => merge(
      a.app_insights_connection_string != null ? { APPLICATIONINSIGHTS_CONNECTION_STRING = a.app_insights_connection_string } : {},
      a.app_insights_connection_string != null && a.create_user_assigned_identity ? {
        APPLICATIONINSIGHTS_AUTHENTICATION_STRING = "ClientId=${azurerm_user_assigned_identity.this[k].client_id};Authorization=AAD"
      } : {},
    )
  }

  effective_app_settings = {
    for k, a in var.function_apps : k => merge(
      local.host_storage_settings[k],
      local.app_insights_settings[k],
      a.app_settings,
    )
  }

}

resource "azurerm_service_plan" "this" {
  for_each = var.service_plans

  resource_group_name = local.rg.resource_group_name
  location            = var.location
  tags                = merge(var.tags, coalesce(each.value.tags, {}))

  name                         = each.key
  os_type                      = each.value.os_type
  sku_name                     = each.value.sku_name
  app_service_environment_id   = each.value.app_service_environment_id
  maximum_elastic_worker_count = each.value.maximum_elastic_worker_count
  per_site_scaling_enabled     = each.value.per_site_scaling_enabled
  worker_count                 = each.value.worker_count
  zone_balancing_enabled       = each.value.zone_balancing_enabled
}

# Dedicated Y1 consumption plans for apps that reference no plan: one call, one running app.
resource "azurerm_service_plan" "auto" {
  for_each = local.auto_plan_apps

  resource_group_name = local.rg.resource_group_name
  location            = var.location
  tags                = merge(var.tags, coalesce(each.value.tags, {}))

  name     = "asp-${each.key}"
  os_type  = "Linux"
  sku_name = "Y1"
}

resource "azurerm_user_assigned_identity" "this" {
  for_each = local.uai_apps

  resource_group_name = local.rg.resource_group_name
  location            = var.location
  tags                = merge(var.tags, coalesce(each.value.tags, {}))

  name = "id-${each.key}"
}

# The backing storage: keyless by default (identity auth end to end).
resource "azurerm_storage_account" "this" {
  for_each = local.storage_create_apps

  resource_group_name = local.rg.resource_group_name
  location            = var.location
  tags                = merge(var.tags, coalesce(each.value.tags, {}))

  name                              = local.storage_account_names[each.key]
  account_tier                      = "Standard"
  account_replication_type          = each.value.storage_account_replication_type
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = each.value.storage_infrastructure_encryption_enabled
  shared_access_key_enabled         = each.value.storage_shared_access_key_enabled

  # No network rules by default, deliberately: the working lockdown for app storage is VNet
  # integration plus service or private endpoints, which is caller topology; express it here
  # when you have it.
  dynamic "network_rules" {
    for_each = each.value.storage_network_rules != null ? [each.value.storage_network_rules] : []

    content {
      default_action             = network_rules.value.default_action
      bypass                     = network_rules.value.bypass
      ip_rules                   = network_rules.value.ip_rules
      virtual_network_subnet_ids = network_rules.value.virtual_network_subnet_ids
    }
  }
}

# The documented identity role set, granted BEFORE the app exists so the host works first try.
resource "azurerm_role_assignment" "storage" {
  for_each = local.storage_grants

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.this[each.value.app].principal_id
}

# AAD ingestion for Application Insights when the module owns the identity and knows the AI scope.
resource "azurerm_role_assignment" "app_insights" {
  # Gated on the plan-known flag, never on the id itself: the id is usually a same-plan module
  # output, and unknown values in for_each keys fail the plan.
  for_each = { for k, a in var.function_apps : k => a if a.grant_app_insights_metrics_publisher && a.create_user_assigned_identity }

  scope                = each.value.app_insights_id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_user_assigned_identity.this[each.key].principal_id
}

resource "azurerm_linux_function_app" "this" {
  for_each = var.function_apps

  resource_group_name = local.rg.resource_group_name
  location            = var.location
  tags                = merge(var.tags, coalesce(each.value.tags, {}))

  name = each.key
  service_plan_id = coalesce(
    each.value.service_plan_id,
    each.value.service_plan_key != null ? azurerm_service_plan.this[coalesce(each.value.service_plan_key, "-")].id : null,
    try(azurerm_service_plan.auto[each.key].id, null),
  )

  storage_account_name          = local.host_storage_account_names[each.key]
  storage_uses_managed_identity = local.storage_uses_mi[each.key]
  storage_account_access_key    = local.storage_access_keys[each.key]
  storage_key_vault_secret_id   = each.value.storage_key_vault_secret_id
  content_share_force_disabled  = each.value.content_share_force_disabled

  functions_extension_version = each.value.functions_extension_version
  builtin_logging_enabled     = each.value.builtin_logging_enabled
  daily_memory_time_quota     = each.value.daily_memory_time_quota

  https_only                                     = each.value.https_only
  public_network_access_enabled                  = each.value.public_network_access_enabled
  virtual_network_subnet_id                      = each.value.virtual_network_subnet_id
  virtual_network_backup_restore_enabled         = each.value.virtual_network_backup_restore_enabled
  vnet_image_pull_enabled                        = each.value.vnet_image_pull_enabled
  client_certificate_enabled                     = each.value.client_certificate_enabled
  client_certificate_mode                        = each.value.client_certificate_mode
  client_certificate_exclusion_paths             = each.value.client_certificate_exclusion_paths
  ftp_publish_basic_authentication_enabled       = each.value.ftp_publish_basic_authentication_enabled
  webdeploy_publish_basic_authentication_enabled = each.value.webdeploy_publish_basic_authentication_enabled
  key_vault_reference_identity_id                = each.value.key_vault_reference_identity_id
  enabled                                        = each.value.enabled

  app_settings = local.effective_app_settings[each.key]

  # Works on normal plans (unlike flex) but relies on the basic-auth publishing profile plus
  # WEBSITE_RUN_FROM_PACKAGE or SCM_DO_BUILD_DURING_DEPLOYMENT (a validation enforces the
  # pairing); the AAD push after apply needs none of that and is the documented default path.
  zip_deploy_file = each.value.zip_deploy_file

  dynamic "identity" {
    for_each = local.identity_blocks[each.key] != null ? [local.identity_blocks[each.key]] : []

    content {
      type         = identity.value.type
      identity_ids = try(identity.value.identity_ids, null)
    }
  }

  dynamic "connection_string" {
    for_each = each.value.connection_strings

    content {
      name  = connection_string.value.name
      type  = connection_string.value.type
      value = connection_string.value.value
    }
  }

  dynamic "sticky_settings" {
    for_each = each.value.sticky_settings != null ? [each.value.sticky_settings] : []

    content {
      app_setting_names       = sticky_settings.value.app_setting_names
      connection_string_names = sticky_settings.value.connection_string_names
    }
  }

  dynamic "storage_account" {
    for_each = each.value.storage_account_mounts

    content {
      name         = storage_account.value.name
      account_name = storage_account.value.account_name
      access_key   = storage_account.value.access_key
      share_name   = storage_account.value.share_name
      type         = storage_account.value.type
      mount_path   = storage_account.value.mount_path
    }
  }

  dynamic "backup" {
    for_each = each.value.backup != null ? [each.value.backup] : []

    content {
      name                = backup.value.name
      storage_account_url = backup.value.storage_account_url
      enabled             = backup.value.enabled

      schedule {
        frequency_interval       = backup.value.schedule.frequency_interval
        frequency_unit           = backup.value.schedule.frequency_unit
        keep_at_least_one_backup = backup.value.schedule.keep_at_least_one_backup
        retention_period_days    = backup.value.schedule.retention_period_days
        start_time               = backup.value.schedule.start_time
      }
    }
  }

  site_config {
    always_on                                     = each.value.site_config.always_on
    api_definition_url                            = each.value.site_config.api_definition_url
    api_management_api_id                         = each.value.site_config.api_management_api_id
    app_command_line                              = each.value.site_config.app_command_line
    app_scale_limit                               = each.value.site_config.app_scale_limit
    application_insights_connection_string        = each.value.site_config.application_insights_connection_string
    application_insights_key                      = each.value.site_config.application_insights_key
    container_registry_managed_identity_client_id = each.value.site_config.container_registry_managed_identity_client_id
    container_registry_use_managed_identity       = each.value.site_config.container_registry_use_managed_identity
    default_documents                             = each.value.site_config.default_documents
    elastic_instance_minimum                      = each.value.site_config.elastic_instance_minimum
    ftps_state                                    = each.value.site_config.ftps_state
    health_check_eviction_time_in_min             = each.value.site_config.health_check_eviction_time_in_min
    health_check_path                             = each.value.site_config.health_check_path
    http2_enabled                                 = each.value.site_config.http2_enabled
    ip_restriction_default_action                 = each.value.site_config.ip_restriction_default_action
    load_balancing_mode                           = each.value.site_config.load_balancing_mode
    managed_pipeline_mode                         = each.value.site_config.managed_pipeline_mode
    minimum_tls_cipher_suite                      = each.value.site_config.minimum_tls_cipher_suite
    minimum_tls_version                           = each.value.site_config.minimum_tls_version
    pre_warmed_instance_count                     = each.value.site_config.pre_warmed_instance_count
    remote_debugging_enabled                      = each.value.site_config.remote_debugging_enabled
    remote_debugging_version                      = each.value.site_config.remote_debugging_version
    runtime_scale_monitoring_enabled              = each.value.site_config.runtime_scale_monitoring_enabled
    scm_ip_restriction_default_action             = each.value.site_config.scm_ip_restriction_default_action
    scm_minimum_tls_version                       = each.value.site_config.scm_minimum_tls_version
    scm_use_main_ip_restriction                   = each.value.site_config.scm_use_main_ip_restriction
    use_32_bit_worker                             = each.value.site_config.use_32_bit_worker
    vnet_route_all_enabled                        = each.value.site_config.vnet_route_all_enabled
    websockets_enabled                            = each.value.site_config.websockets_enabled
    worker_count                                  = each.value.site_config.worker_count

    dynamic "application_stack" {
      for_each = each.value.site_config.application_stack != null ? [each.value.site_config.application_stack] : []

      content {
        dotnet_version              = application_stack.value.dotnet_version
        use_dotnet_isolated_runtime = application_stack.value.use_dotnet_isolated_runtime
        java_version                = application_stack.value.java_version
        node_version                = application_stack.value.node_version
        powershell_core_version     = application_stack.value.powershell_core_version
        python_version              = application_stack.value.python_version
        use_custom_runtime          = application_stack.value.use_custom_runtime

        dynamic "docker" {
          for_each = application_stack.value.docker

          content {
            image_name        = docker.value.image_name
            image_tag         = docker.value.image_tag
            registry_url      = docker.value.registry_url
            registry_username = docker.value.registry_username
            registry_password = docker.value.registry_password
          }
        }
      }
    }

    dynamic "app_service_logs" {
      for_each = each.value.site_config.app_service_logs != null ? [each.value.site_config.app_service_logs] : []

      content {
        disk_quota_mb         = app_service_logs.value.disk_quota_mb
        retention_period_days = app_service_logs.value.retention_period_days
      }
    }

    dynamic "cors" {
      for_each = each.value.site_config.cors != null ? [each.value.site_config.cors] : []

      content {
        allowed_origins     = cors.value.allowed_origins
        support_credentials = cors.value.support_credentials
      }
    }

    dynamic "ip_restriction" {
      for_each = each.value.site_config.ip_restrictions

      content {
        action                    = ip_restriction.value.action
        description               = ip_restriction.value.description
        ip_address                = ip_restriction.value.ip_address
        name                      = ip_restriction.value.name
        priority                  = ip_restriction.value.priority
        service_tag               = ip_restriction.value.service_tag
        virtual_network_subnet_id = ip_restriction.value.virtual_network_subnet_id

        dynamic "headers" {
          for_each = coalesce(ip_restriction.value.headers, [])

          content {
            x_azure_fdid      = headers.value.x_azure_fdid
            x_fd_health_probe = headers.value.x_fd_health_probe
            x_forwarded_for   = headers.value.x_forwarded_for
            x_forwarded_host  = headers.value.x_forwarded_host
          }
        }
      }
    }

    dynamic "scm_ip_restriction" {
      for_each = each.value.site_config.scm_ip_restrictions

      content {
        action                    = scm_ip_restriction.value.action
        description               = scm_ip_restriction.value.description
        ip_address                = scm_ip_restriction.value.ip_address
        name                      = scm_ip_restriction.value.name
        priority                  = scm_ip_restriction.value.priority
        service_tag               = scm_ip_restriction.value.service_tag
        virtual_network_subnet_id = scm_ip_restriction.value.virtual_network_subnet_id

        dynamic "headers" {
          for_each = coalesce(scm_ip_restriction.value.headers, [])

          content {
            x_azure_fdid      = headers.value.x_azure_fdid
            x_fd_health_probe = headers.value.x_fd_health_probe
            x_forwarded_for   = headers.value.x_forwarded_for
            x_forwarded_host  = headers.value.x_forwarded_host
          }
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
          client_id                  = active_directory.value.client_id
          allowed_audiences          = active_directory.value.allowed_audiences
          client_secret              = active_directory.value.client_secret
          client_secret_setting_name = active_directory.value.client_secret_setting_name
        }
      }

      dynamic "facebook" {
        for_each = auth_settings.value.facebook != null ? [auth_settings.value.facebook] : []

        content {
          app_id                  = facebook.value.app_id
          app_secret              = facebook.value.app_secret
          app_secret_setting_name = facebook.value.app_secret_setting_name
          oauth_scopes            = facebook.value.oauth_scopes
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

      dynamic "google" {
        for_each = auth_settings.value.google != null ? [auth_settings.value.google] : []

        content {
          client_id                  = google.value.client_id
          client_secret              = google.value.client_secret
          client_secret_setting_name = google.value.client_secret_setting_name
          oauth_scopes               = google.value.oauth_scopes
        }
      }

      dynamic "microsoft" {
        for_each = auth_settings.value.microsoft != null ? [auth_settings.value.microsoft] : []

        content {
          client_id                  = microsoft.value.client_id
          client_secret              = microsoft.value.client_secret
          client_secret_setting_name = microsoft.value.client_secret_setting_name
          oauth_scopes               = microsoft.value.oauth_scopes
        }
      }

      dynamic "twitter" {
        for_each = auth_settings.value.twitter != null ? [auth_settings.value.twitter] : []

        content {
          consumer_key                 = twitter.value.consumer_key
          consumer_secret              = twitter.value.consumer_secret
          consumer_secret_setting_name = twitter.value.consumer_secret_setting_name
        }
      }
    }
  }

  dynamic "auth_settings_v2" {
    for_each = each.value.auth_settings_v2 != null ? [each.value.auth_settings_v2] : []

    content {
      auth_enabled                            = auth_settings_v2.value.auth_enabled
      config_file_path                        = auth_settings_v2.value.config_file_path
      default_provider                        = auth_settings_v2.value.default_provider
      excluded_paths                          = auth_settings_v2.value.excluded_paths
      forward_proxy_convention                = auth_settings_v2.value.forward_proxy_convention
      forward_proxy_custom_host_header_name   = auth_settings_v2.value.forward_proxy_custom_host_header_name
      forward_proxy_custom_scheme_header_name = auth_settings_v2.value.forward_proxy_custom_scheme_header_name
      http_route_api_prefix                   = auth_settings_v2.value.http_route_api_prefix
      require_authentication                  = auth_settings_v2.value.require_authentication
      require_https                           = auth_settings_v2.value.require_https
      runtime_version                         = auth_settings_v2.value.runtime_version
      unauthenticated_action                  = auth_settings_v2.value.unauthenticated_action

      dynamic "active_directory_v2" {
        for_each = auth_settings_v2.value.active_directory_v2 != null ? [auth_settings_v2.value.active_directory_v2] : []

        content {
          client_id                            = active_directory_v2.value.client_id
          tenant_auth_endpoint                 = active_directory_v2.value.tenant_auth_endpoint
          allowed_applications                 = active_directory_v2.value.allowed_applications
          allowed_audiences                    = active_directory_v2.value.allowed_audiences
          allowed_groups                       = active_directory_v2.value.allowed_groups
          allowed_identities                   = active_directory_v2.value.allowed_identities
          client_secret_certificate_thumbprint = active_directory_v2.value.client_secret_certificate_thumbprint
          client_secret_setting_name           = active_directory_v2.value.client_secret_setting_name
          jwt_allowed_client_applications      = active_directory_v2.value.jwt_allowed_client_applications
          jwt_allowed_groups                   = active_directory_v2.value.jwt_allowed_groups
          login_parameters                     = active_directory_v2.value.login_parameters
          www_authentication_disabled          = active_directory_v2.value.www_authentication_disabled
        }
      }

      dynamic "apple_v2" {
        for_each = auth_settings_v2.value.apple_v2 != null ? [auth_settings_v2.value.apple_v2] : []

        content {
          client_id                  = apple_v2.value.client_id
          client_secret_setting_name = apple_v2.value.client_secret_setting_name
        }
      }

      dynamic "azure_static_web_app_v2" {
        for_each = auth_settings_v2.value.azure_static_web_app_v2 != null ? [auth_settings_v2.value.azure_static_web_app_v2] : []

        content {
          client_id = azure_static_web_app_v2.value.client_id
        }
      }

      dynamic "custom_oidc_v2" {
        for_each = auth_settings_v2.value.custom_oidc_v2

        content {
          client_id                     = custom_oidc_v2.value.client_id
          name                          = custom_oidc_v2.value.name
          openid_configuration_endpoint = custom_oidc_v2.value.openid_configuration_endpoint
          name_claim_type               = custom_oidc_v2.value.name_claim_type
          scopes                        = custom_oidc_v2.value.scopes
        }
      }

      dynamic "facebook_v2" {
        for_each = auth_settings_v2.value.facebook_v2 != null ? [auth_settings_v2.value.facebook_v2] : []

        content {
          app_id                  = facebook_v2.value.app_id
          app_secret_setting_name = facebook_v2.value.app_secret_setting_name
          graph_api_version       = facebook_v2.value.graph_api_version
          login_scopes            = facebook_v2.value.login_scopes
        }
      }

      dynamic "github_v2" {
        for_each = auth_settings_v2.value.github_v2 != null ? [auth_settings_v2.value.github_v2] : []

        content {
          client_id                  = github_v2.value.client_id
          client_secret_setting_name = github_v2.value.client_secret_setting_name
          login_scopes               = github_v2.value.login_scopes
        }
      }

      dynamic "google_v2" {
        for_each = auth_settings_v2.value.google_v2 != null ? [auth_settings_v2.value.google_v2] : []

        content {
          client_id                  = google_v2.value.client_id
          client_secret_setting_name = google_v2.value.client_secret_setting_name
          allowed_audiences          = google_v2.value.allowed_audiences
          login_scopes               = google_v2.value.login_scopes
        }
      }

      dynamic "microsoft_v2" {
        for_each = auth_settings_v2.value.microsoft_v2 != null ? [auth_settings_v2.value.microsoft_v2] : []

        content {
          client_id                  = microsoft_v2.value.client_id
          client_secret_setting_name = microsoft_v2.value.client_secret_setting_name
          allowed_audiences          = microsoft_v2.value.allowed_audiences
          login_scopes               = microsoft_v2.value.login_scopes
        }
      }

      dynamic "twitter_v2" {
        for_each = auth_settings_v2.value.twitter_v2 != null ? [auth_settings_v2.value.twitter_v2] : []

        content {
          consumer_key                 = twitter_v2.value.consumer_key
          consumer_secret_setting_name = twitter_v2.value.consumer_secret_setting_name
        }
      }

      login {
        allowed_external_redirect_urls    = auth_settings_v2.value.login.allowed_external_redirect_urls
        cookie_expiration_convention      = auth_settings_v2.value.login.cookie_expiration_convention
        cookie_expiration_time            = auth_settings_v2.value.login.cookie_expiration_time
        logout_endpoint                   = auth_settings_v2.value.login.logout_endpoint
        nonce_expiration_time             = auth_settings_v2.value.login.nonce_expiration_time
        preserve_url_fragments_for_logins = auth_settings_v2.value.login.preserve_url_fragments_for_logins
        token_refresh_extension_time      = auth_settings_v2.value.login.token_refresh_extension_time
        token_store_enabled               = auth_settings_v2.value.login.token_store_enabled
        token_store_path                  = auth_settings_v2.value.login.token_store_path
        token_store_sas_setting_name      = auth_settings_v2.value.login.token_store_sas_setting_name
        validate_nonce                    = auth_settings_v2.value.login.validate_nonce
      }
    }
  }

  depends_on = [azurerm_role_assignment.storage]
}
