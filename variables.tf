variable "function_apps" {
  description = <<-DESC
    Linux function apps keyed by name. Fast to get going: an entry with just an
    application_stack runtime gets a dedicated Y1 consumption plan, a keyless storage account,
    a user-assigned identity granted the full documented role set, and identity-based host
    storage (storage_uses_managed_identity) wired automatically. Flexible when it matters:
    every default has an explicit override.

    PLAN: exactly one of service_plan_key (a plan from service_plans), service_plan_id (bring
    your own), or neither (dedicated Y1 consumption plan created).

    STORAGE, three shapes: created (default), bring-your-own account via storage_account_id
    (the module can still grant roles because it has the scope), or the
    storage_key_vault_secret_id escape hatch (the caller owns everything; Key Vault holds the
    connection string). storage_shared_access_key_enabled defaults FALSE (keyless): the host
    authenticates with the identity via storage_uses_managed_identity plus the
    AzureWebJobsStorage__clientId setting. CONTENT SHARE TRAP: Consumption (Y1) and Elastic
    Premium plans want an Azure Files content share, and Files has no AAD data plane for it, so
    keyless apps on those plans must set content_share_force_disabled = true and deploy with
    WEBSITE_RUN_FROM_PACKAGE (a check enforces this); dedicated plans (B/S/P) have no content
    share need. Set storage_shared_access_key_enabled = true for the keys-on opt-out.

    IDENTITY: the module creates a user-assigned identity per app by default
    (create_user_assigned_identity), attached as "SystemAssigned, UserAssigned" so both kinds
    are live. Pass identity to bring your own of any type (the module then grants nothing on
    storage: the identity owner does). Set create_user_assigned_identity = false with no
    identity block for an identity-less app (needs keys-on storage or the Key Vault shape).

    SECURE DEFAULTS overriding the provider's: https_only true,
    ftp_publish_basic_authentication_enabled false, webdeploy_publish_basic_authentication_enabled
    false, builtin_logging_enabled false (App Insights supersedes the legacy dashboard).
    NOTE: zip_deploy_file relies on the basic-auth publishing profile, so using it requires
    webdeploy_publish_basic_authentication_enabled = true plus WEBSITE_RUN_FROM_PACKAGE or
    SCM_DO_BUILD_DURING_DEPLOYMENT in app_settings (a validation enforces the pairing); the
    AAD path (az functionapp deployment source config-zip after apply) works with basic auth
    off and is what this repo's CI demonstrates.

    APP INSIGHTS: pass app_insights_connection_string to wire the app setting; with an
    app_insights_id and a module-created identity the AAD ingestion auth string and Monitoring
    Metrics Publisher grant are wired too.
  DESC
  type = map(object({
    service_plan_key = optional(string)
    service_plan_id  = optional(string)

    # Storage (three shapes; see description).
    create_storage_account                    = optional(bool, true)
    storage_account_name                      = optional(string)
    storage_account_id                        = optional(string)
    storage_key_vault_secret_id               = optional(string)
    storage_shared_access_key_enabled         = optional(bool, false)
    storage_infrastructure_encryption_enabled = optional(bool, true)
    storage_account_access_key                = optional(string)
    storage_role_names                        = optional(list(string), ["Storage Blob Data Owner", "Storage Blob Data Contributor", "Storage Queue Data Contributor", "Storage Table Data Contributor"])
    storage_account_replication_type          = optional(string, "LRS")
    storage_network_rules = optional(object({
      default_action             = string
      bypass                     = optional(list(string), ["AzureServices"])
      ip_rules                   = optional(list(string))
      virtual_network_subnet_ids = optional(list(string))
    }))
    wire_host_storage_settings   = optional(bool, true)
    content_share_force_disabled = optional(bool)

    # Identity.
    create_user_assigned_identity = optional(bool, true)
    identity = optional(object({
      type         = string
      identity_ids = optional(list(string))
    }))
    key_vault_reference_identity_id = optional(string)

    # Observability. The grant flag exists because the AI id is usually a same-plan module
    # output (unknown until apply), and for_each keys must stay plan-known: set it alongside
    # app_insights_id to grant Monitoring Metrics Publisher to the module-created identity.
    app_insights_connection_string       = optional(string)
    app_insights_id                      = optional(string)
    grant_app_insights_metrics_publisher = optional(bool, false)

    # Functions runtime and behaviour.
    functions_extension_version = optional(string, "~4")
    builtin_logging_enabled     = optional(bool, false)
    daily_memory_time_quota     = optional(number)

    # Security and networking.
    https_only                                     = optional(bool, true)
    public_network_access_enabled                  = optional(bool, true)
    virtual_network_subnet_id                      = optional(string)
    virtual_network_backup_restore_enabled         = optional(bool)
    vnet_image_pull_enabled                        = optional(bool)
    client_certificate_enabled                     = optional(bool)
    client_certificate_mode                        = optional(string)
    client_certificate_exclusion_paths             = optional(string)
    ftp_publish_basic_authentication_enabled       = optional(bool, false)
    webdeploy_publish_basic_authentication_enabled = optional(bool, false)
    enabled                                        = optional(bool, true)

    # Deployment. zip_deploy_file works on normal plans but requires the basic-auth publishing
    # profile plus WEBSITE_RUN_FROM_PACKAGE or SCM_DO_BUILD_DURING_DEPLOYMENT; the AAD push
    # (az functionapp deployment source config-zip) needs neither and is the documented default.
    zip_deploy_file = optional(string)

    # Settings.
    app_settings = optional(map(string), {})
    connection_strings = optional(list(object({
      name  = string
      type  = string
      value = string
    })), [])
    sticky_settings = optional(object({
      app_setting_names       = optional(list(string))
      connection_string_names = optional(list(string))
    }))

    # Azure Files / Blob mounts.
    storage_account_mounts = optional(list(object({
      name         = string
      account_name = string
      access_key   = string
      share_name   = string
      type         = string
      mount_path   = optional(string)
    })), [])

    backup = optional(object({
      name                = string
      storage_account_url = string
      enabled             = optional(bool, true)
      schedule = object({
        frequency_interval       = number
        frequency_unit           = string
        keep_at_least_one_backup = optional(bool)
        retention_period_days    = optional(number)
        start_time               = optional(string)
      })
    }))

    site_config = optional(object({
      always_on                                     = optional(bool)
      api_definition_url                            = optional(string)
      api_management_api_id                         = optional(string)
      app_command_line                              = optional(string)
      app_scale_limit                               = optional(number)
      application_insights_connection_string        = optional(string)
      application_insights_key                      = optional(string)
      container_registry_managed_identity_client_id = optional(string)
      container_registry_use_managed_identity       = optional(bool)
      default_documents                             = optional(list(string))
      elastic_instance_minimum                      = optional(number)
      ftps_state                                    = optional(string)
      health_check_eviction_time_in_min             = optional(number)
      health_check_path                             = optional(string)
      http2_enabled                                 = optional(bool)
      ip_restriction_default_action                 = optional(string)
      load_balancing_mode                           = optional(string)
      managed_pipeline_mode                         = optional(string)
      minimum_tls_cipher_suite                      = optional(string)
      minimum_tls_version                           = optional(string)
      pre_warmed_instance_count                     = optional(number)
      remote_debugging_enabled                      = optional(bool)
      remote_debugging_version                      = optional(string)
      runtime_scale_monitoring_enabled              = optional(bool)
      scm_ip_restriction_default_action             = optional(string)
      scm_minimum_tls_version                       = optional(string)
      scm_use_main_ip_restriction                   = optional(bool)
      use_32_bit_worker                             = optional(bool)
      vnet_route_all_enabled                        = optional(bool)
      websockets_enabled                            = optional(bool)
      worker_count                                  = optional(number)

      application_stack = optional(object({
        dotnet_version              = optional(string)
        use_dotnet_isolated_runtime = optional(bool)
        java_version                = optional(string)
        node_version                = optional(string)
        powershell_core_version     = optional(string)
        python_version              = optional(string)
        use_custom_runtime          = optional(bool)
        docker = optional(list(object({
          image_name        = string
          image_tag         = string
          registry_url      = string
          registry_username = optional(string)
          registry_password = optional(string)
        })), [])
      }))

      app_service_logs = optional(object({
        disk_quota_mb         = optional(number)
        retention_period_days = optional(number)
      }))

      cors = optional(object({
        allowed_origins     = optional(list(string))
        support_credentials = optional(bool)
      }))

      ip_restrictions = optional(list(object({
        action                    = optional(string)
        description               = optional(string)
        ip_address                = optional(string)
        name                      = optional(string)
        priority                  = optional(number)
        service_tag               = optional(string)
        virtual_network_subnet_id = optional(string)
        headers = optional(list(object({
          x_azure_fdid      = optional(list(string))
          x_fd_health_probe = optional(list(string))
          x_forwarded_for   = optional(list(string))
          x_forwarded_host  = optional(list(string))
        })))
      })), [])

      scm_ip_restrictions = optional(list(object({
        action                    = optional(string)
        description               = optional(string)
        ip_address                = optional(string)
        name                      = optional(string)
        priority                  = optional(number)
        service_tag               = optional(string)
        virtual_network_subnet_id = optional(string)
        headers = optional(list(object({
          x_azure_fdid      = optional(list(string))
          x_fd_health_probe = optional(list(string))
          x_forwarded_for   = optional(list(string))
          x_forwarded_host  = optional(list(string))
        })))
      })), [])
    }), {})

    auth_settings = optional(object({
      enabled                        = bool
      additional_login_parameters    = optional(map(string))
      allowed_external_redirect_urls = optional(list(string))
      default_provider               = optional(string)
      issuer                         = optional(string)
      runtime_version                = optional(string)
      token_refresh_extension_hours  = optional(number)
      token_store_enabled            = optional(bool)
      unauthenticated_client_action  = optional(string)

      active_directory = optional(object({
        client_id                  = string
        allowed_audiences          = optional(list(string))
        client_secret              = optional(string)
        client_secret_setting_name = optional(string)
      }))
      facebook = optional(object({
        app_id                  = string
        app_secret              = optional(string)
        app_secret_setting_name = optional(string)
        oauth_scopes            = optional(list(string))
      }))
      github = optional(object({
        client_id                  = string
        client_secret              = optional(string)
        client_secret_setting_name = optional(string)
        oauth_scopes               = optional(list(string))
      }))
      google = optional(object({
        client_id                  = string
        client_secret              = optional(string)
        client_secret_setting_name = optional(string)
        oauth_scopes               = optional(list(string))
      }))
      microsoft = optional(object({
        client_id                  = string
        client_secret              = optional(string)
        client_secret_setting_name = optional(string)
        oauth_scopes               = optional(list(string))
      }))
      twitter = optional(object({
        consumer_key                 = string
        consumer_secret              = optional(string)
        consumer_secret_setting_name = optional(string)
      }))
    }))

    auth_settings_v2 = optional(object({
      auth_enabled                            = optional(bool)
      config_file_path                        = optional(string)
      default_provider                        = optional(string)
      excluded_paths                          = optional(list(string))
      forward_proxy_convention                = optional(string)
      forward_proxy_custom_host_header_name   = optional(string)
      forward_proxy_custom_scheme_header_name = optional(string)
      http_route_api_prefix                   = optional(string)
      require_authentication                  = optional(bool)
      require_https                           = optional(bool)
      runtime_version                         = optional(string)
      unauthenticated_action                  = optional(string)

      active_directory_v2 = optional(object({
        client_id                            = string
        tenant_auth_endpoint                 = string
        allowed_applications                 = optional(list(string))
        allowed_audiences                    = optional(list(string))
        allowed_groups                       = optional(list(string))
        allowed_identities                   = optional(list(string))
        client_secret_certificate_thumbprint = optional(string)
        client_secret_setting_name           = optional(string)
        jwt_allowed_client_applications      = optional(list(string))
        jwt_allowed_groups                   = optional(list(string))
        login_parameters                     = optional(map(string))
        www_authentication_disabled          = optional(bool)
      }))
      apple_v2 = optional(object({
        client_id                  = string
        client_secret_setting_name = string
      }))
      azure_static_web_app_v2 = optional(object({
        client_id = string
      }))
      custom_oidc_v2 = optional(list(object({
        client_id                     = string
        name                          = string
        openid_configuration_endpoint = string
        name_claim_type               = optional(string)
        scopes                        = optional(list(string))
      })), [])
      facebook_v2 = optional(object({
        app_id                  = string
        app_secret_setting_name = string
        graph_api_version       = optional(string)
        login_scopes            = optional(list(string))
      }))
      github_v2 = optional(object({
        client_id                  = string
        client_secret_setting_name = string
        login_scopes               = optional(list(string))
      }))
      google_v2 = optional(object({
        client_id                  = string
        client_secret_setting_name = string
        allowed_audiences          = optional(list(string))
        login_scopes               = optional(list(string))
      }))
      microsoft_v2 = optional(object({
        client_id                  = string
        client_secret_setting_name = string
        allowed_audiences          = optional(list(string))
        login_scopes               = optional(list(string))
      }))
      twitter_v2 = optional(object({
        consumer_key                 = string
        consumer_secret_setting_name = string
      }))
      login = optional(object({
        allowed_external_redirect_urls    = optional(list(string))
        cookie_expiration_convention      = optional(string)
        cookie_expiration_time            = optional(string)
        logout_endpoint                   = optional(string)
        nonce_expiration_time             = optional(string)
        preserve_url_fragments_for_logins = optional(bool)
        token_refresh_extension_time      = optional(number)
        token_store_enabled               = optional(bool)
        token_store_path                  = optional(string)
        token_store_sas_setting_name      = optional(string)
        validate_nonce                    = optional(bool)
      }), {})
    }))

    tags = optional(map(string))
  }))
  default = {}

  validation {
    condition = alltrue([
      for a in values(var.function_apps) :
      length([for v in [a.service_plan_key, a.service_plan_id] : v if v != null]) <= 1
    ])
    error_message = "Set at most one of service_plan_key or service_plan_id per app (neither means a dedicated Y1 plan is created)."
  }

  validation {
    condition = alltrue([
      for a in values(var.function_apps) :
      length([for v in [a.storage_account_id, a.storage_key_vault_secret_id] : v if v != null]) <= 1 && (a.storage_account_id == null && a.storage_key_vault_secret_id == null ? true : !a.create_storage_account)
    ])
    error_message = "Pick ONE storage shape per app: created (create_storage_account, the default), bring-your-own via storage_account_id, or storage_key_vault_secret_id (and set create_storage_account = false with either of the latter two)."
  }

  validation {
    condition = alltrue([
      for a in values(var.function_apps) :
      a.storage_key_vault_secret_id == null || (!a.wire_host_storage_settings && a.storage_account_access_key == null)
    ])
    error_message = "storage_key_vault_secret_id is caller-owned: set wire_host_storage_settings = false and pass no storage_account_access_key."
  }

  validation {
    condition = alltrue([
      for a in values(var.function_apps) :
      a.storage_account_access_key == null || a.storage_shared_access_key_enabled || !a.create_storage_account
    ])
    error_message = "A passed storage_account_access_key needs storage_shared_access_key_enabled = true on a created account."
  }

  validation {
    condition = alltrue([
      for a in values(var.function_apps) :
      a.zip_deploy_file == null || (
        a.webdeploy_publish_basic_authentication_enabled &&
        (contains(keys(a.app_settings), "WEBSITE_RUN_FROM_PACKAGE") || contains(keys(a.app_settings), "SCM_DO_BUILD_DURING_DEPLOYMENT"))
      )
    ])
    error_message = "zip_deploy_file relies on the basic-auth publishing profile: set webdeploy_publish_basic_authentication_enabled = true and WEBSITE_RUN_FROM_PACKAGE = \"1\" (or SCM_DO_BUILD_DURING_DEPLOYMENT = \"true\") in app_settings, or deploy with the AAD push after apply instead (see the README)."
  }

  validation {
    condition     = alltrue([for a in values(var.function_apps) : a.identity == null || !a.create_user_assigned_identity])
    error_message = "Set create_user_assigned_identity = false when bringing your own identity block."
  }

  validation {
    condition     = alltrue([for a in values(var.function_apps) : !a.grant_app_insights_metrics_publisher || a.create_user_assigned_identity])
    error_message = "grant_app_insights_metrics_publisher needs the module-created identity (create_user_assigned_identity = true); with your own identity, grant Monitoring Metrics Publisher yourself."
  }

  validation {
    condition = alltrue([
      for a in values(var.function_apps) :
      try(a.site_config.cors, null) == null ? true : !(coalesce(a.site_config.cors.support_credentials, false) && contains(coalesce(a.site_config.cors.allowed_origins, []), "*"))
    ])
    error_message = "CORS cannot combine the * wildcard origin with support_credentials = true."
  }
}

variable "location" {
  description = "Azure region for all resources in this module."
  type        = string
}

variable "resource_group_id" {
  description = "Id of the resource group the apps live in; the module parses the name from it."
  type        = string
}

variable "service_plans" {
  description = <<-DESC
    App service plans keyed by name, shareable by multiple apps via service_plan_key. sku_name
    defaults to Y1 (Linux consumption); anything the platform supports is accepted (B1/S1/P1v3
    dedicated, EP1-EP3 elastic premium, and so on). app_service_environment_id places the plan
    on an App Service Environment. Apps that reference no plan get their own dedicated Y1 plan
    automatically.
  DESC
  type = map(object({
    os_type                      = optional(string, "Linux")
    sku_name                     = optional(string, "Y1")
    app_service_environment_id   = optional(string)
    maximum_elastic_worker_count = optional(number)
    per_site_scaling_enabled     = optional(bool)
    worker_count                 = optional(number)
    zone_balancing_enabled       = optional(bool)
    tags                         = optional(map(string))
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to all resources; per-app and per-plan tags override these."
  type        = map(string)
  default     = {}
}
