variable "linux_function_apps" {
  description = "List of Azure Linux Function Apps configurations"
  type = list(object({
    name                                           = string
    rg_name                                        = string
    location                                       = string
    create_new_app_service_plan                    = optional(bool, true)
    app_service_plan_name                          = optional(string)
    service_plan_id                                = optional(string)
    os_type                                        = optional(string)
    sku_name                                       = string
    app_settings                                   = map(string)
    https_only                                     = optional(bool)
    tags                                           = optional(map(string))
    builtin_logging_enabled                        = optional(bool)
    client_certificate_enabled                     = optional(bool)
    client_certificate_exclusion_paths             = optional(string)
    client_certificate_mode                        = optional(string)
    daily_memory_time_quota                        = optional(number)
    enabled                                        = optional(bool, true)
    functions_extension_version                    = optional(string, "~4")
    content_share_force_disabled                   = optional(bool)
    identity_type                                  = optional(string)
    ftp_publish_basic_authentication_enable        = optional(bool, false)
    public_network_access_enabled                  = optional(bool, true)
    key_vault_reference_identity_id                = optional(string)
    virtual_network_subnet_id                      = optional(string)
    webdeploy_publish_basic_authentication_enabled = optional(bool, false)
    zip_deploy_file                                = optional(string)

    identity_ids                                       = optional(list(string))
    storage_account_name                               = optional(string)
    storage_account_access_key                         = optional(string)
    storage_key_vault_secret_id                        = optional(string)
    storage_uses_managed_identity                      = optional(bool)
    create_new_app_insights                            = optional(bool, false)
    workspace_id                                       = optional(string)
    app_insights_name                                  = optional(string)
    app_insights_type                                  = optional(string, "Web")
    app_insights_daily_cap_in_gb                       = optional(number)
    app_insights_daily_data_cap_notifications_disabled = optional(bool, false)
    app_insights_internet_ingestion_enabled            = optional(bool)
    app_insights_internet_query_enabled                = optional(bool)
    app_insights_local_authentication_disabled         = optional(bool, true)
    app_insights_force_customer_storage_for_profile    = optional(bool, false)
    app_insights_sampling_percentage                   = optional(number, 100)
    storage_account = optional(object({
      access_key   = string
      account_name = string
      name         = string
      share_name   = string
      type         = string
      mount_path   = optional(string)
    }))
    sticky_settings = optional(object({
      app_setting_names       = optional(list(string))
      connection_string_names = optional(list(string))
    }))
    connection_string = optional(object({
      name  = optional(string)
      type  = optional(string)
      value = optional(string)
    }))
    backup = optional(object({
      name                = optional(string)
      enabled             = optional(bool)
      storage_account_url = optional(string)
      backup_sas_url = optional(string)
      schedule = optional(object({
        frequency_interval       = optional(string)
        frequency_unit           = optional(string)
        keep_at_least_one_backup = optional(bool)
        retention_period_days    = optional(number)
        start_time               = optional(string)
      }))
    }))
    auth_settings_v2 = optional(object({
      auth_enabled                            = optional(bool)
      runtime_version                         = optional(string)
      config_file_path                        = optional(string)
      require_authentication                  = optional(bool)
      unauthenticated_action                  = optional(string)
      default_provider                        = optional(string)
      excluded_paths                          = optional(list(string))
      require_https                           = optional(bool)
      http_route_api_prefix                   = optional(string)
      forward_proxy_convention                = optional(string)
      forward_proxy_custom_host_header_name   = optional(string)
      forward_proxy_custom_scheme_header_name = optional(string)
      apple_v2 = optional(object({
        client_id                  = string
        client_secret_setting_name = string
        login_scopes               = list(string)
      }))
      active_directory_v2 = optional(object({
        client_id                            = string
        tenant_auth_endpoint                 = string
        client_secret_setting_name           = optional(string)
        client_secret_certificate_thumbprint = optional(string)
        jwt_allowed_groups                   = optional(list(string))
        jwt_allowed_client_applications      = optional(list(string))
        www_authentication_disabled          = optional(bool)
        allowed_groups                       = optional(list(string))
        allowed_identities                   = optional(list(string))
        allowed_applications                 = optional(list(string))
        login_parameters                     = optional(map(string))
        allowed_audiences                    = optional(list(string))
      }))
      azure_static_web_app_v2 = optional(object({
        client_id = string
      }))
      custom_oidc_v2 = optional(list(object({
        name                          = string
        client_id                     = string
        openid_configuration_endpoint = string
        name_claim_type               = optional(string)
        scopes                        = optional(list(string))
        client_credential_method      = string
        client_secret_setting_name    = string
        authorisation_endpoint        = string
        token_endpoint                = string
        issuer_endpoint               = string
        certification_uri             = string
      })))
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
        logout_endpoint                   = optional(string)
        token_store_enabled               = optional(bool)
        token_refresh_extension_time      = optional(number)
        token_store_path                  = optional(string)
        token_store_sas_setting_name      = optional(string)
        preserve_url_fragments_for_logins = optional(bool)
        allowed_external_redirect_urls    = optional(list(string))
        cookie_expiration_convention      = optional(string)
        cookie_expiration_time            = optional(string)
        validate_nonce                    = optional(bool)
        nonce_expiration_time             = optional(string)
      }))
    }))
    auth_settings = optional(object({
      enabled                        = optional(bool)
      additional_login_parameters    = optional(map(string))
      allowed_external_redirect_urls = optional(list(string))
      default_provider               = optional(string)
      issuer                         = optional(string)
      runtime_version                = optional(string)
      token_refresh_extension_hours  = optional(number)
      token_store_enabled            = optional(bool)
      unauthenticated_client_action  = optional(string)
      active_directory = optional(object({
        client_id         = optional(string)
        client_secret     = optional(string)
        allowed_audiences = optional(list(string))
      }))
      facebook = optional(object({
        app_id       = optional(string)
        app_secret   = optional(string)
        oauth_scopes = optional(list(string))
      }))
      google = optional(object({
        client_id     = optional(string)
        client_secret = optional(string)
        oauth_scopes  = optional(list(string))
      }))
      microsoft = optional(object({
        client_id     = optional(string)
        client_secret = optional(string)
        oauth_scopes  = optional(list(string))
      }))
      twitter = optional(object({
        consumer_key    = optional(string)
        consumer_secret = optional(string)
      }))
      github = optional(object({
        client_id                  = optional(string)
        client_secret              = optional(string)
        client_secret_setting_name = optional(string)
        oauth_scopes               = optional(list(string))
      }))
    }))
    site_config = optional(object({
      always_on                                     = optional(bool)
      api_definition_url                            = optional(string)
      api_management_api_id                         = optional(string)
      app_command_line                              = optional(string)
      application_insights_connection_string        = optional(string)
      application_insights_key                      = optional(string)
      container_registry_managed_identity_client_id = optional(string)
      container_registry_use_managed_identity       = optional(bool)
      elastic_instance_minimum                      = optional(number)
      ftps_state                                    = optional(string)
      health_check_path                             = optional(string)
      health_check_eviction_time_in_min             = optional(number)
      http2_enabled                                 = optional(bool)
      load_balancing_mode                           = optional(string)
      managed_pipeline_mode                         = optional(string)
      minimum_tls_version                           = optional(string, "1.2")
      pre_warmed_instance_count                     = optional(number)
      remote_debugging_enabled                      = optional(bool)
      remote_debugging_version                      = optional(string)
      runtime_scale_monitoring_enabled              = optional(bool)
      scm_minimum_tls_version                       = optional(string, "1.2")
      scm_use_main_ip_restriction                   = optional(bool, true)
      use_32_bit_worker                             = optional(bool)
      app_scale_limit                               = optional(number)
      websockets_enabled                            = optional(bool)
      vnet_route_all_enabled                        = optional(bool)
      worker_count                                  = optional(number)
      default_documents                             = optional(list(string))
      application_stack = optional(object({
        java_version                = optional(string)
        dotnet_version              = optional(string)
        use_dotnet_isolated_runtime = optional(bool)
        node_version                = optional(string)
        python_version              = optional(string)
        powershell_core_version     = optional(string)
        use_custom_runtime          = optional(bool)
        docker = optional(list(object({
          registry_url      = optional(string)
          registry_username = optional(string)
          registry_password = optional(string)
          image_name        = optional(string)
          image_tag         = optional(string)
        })))
      }))
      app_service_logs = optional(object({
        disk_quota_mb         = optional(number)
        retention_period_days = optional(number)
      }))
      cors = optional(object({
        allowed_origins     = optional(list(string))
        support_credentials = optional(bool)
      }))
      ip_restriction = optional(list(object({
        ip_address                = optional(string)
        service_tag               = optional(string)
        virtual_network_subnet_id = optional(string)
        name                      = optional(string)
        priority                  = optional(number)
        action                    = optional(string)
        headers = optional(object({
          x_azure_fdid      = optional(string)
          x_fd_health_probe = optional(string)
          x_forwarded_for   = optional(string)
          x_forwarded_host  = optional(string)
        }))
      })))
      scm_ip_restriction = optional(list(object({
        ip_address                = optional(string)
        service_tag               = optional(string)
        virtual_network_subnet_id = optional(string)
        name                      = optional(string)
        priority                  = optional(number)
        action                    = optional(string)
        headers = optional(object({
          x_azure_fdid      = optional(string)
          x_fd_health_probe = optional(string)
          x_forwarded_for   = optional(string)
          x_forwarded_host  = optional(string)
        }))
      })))
    }))
  }))
  default = []
}
