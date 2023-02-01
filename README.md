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
| [azurerm_app_service_virtual_network_swift_connection.function_vnet_integration](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_virtual_network_swift_connection) | resource |
| [azurerm_application_insights.app_insights_non_workspace](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights) | resource |
| [azurerm_application_insights.app_insights_workspace](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights) | resource |
| [azurerm_linux_function_app.function_app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_function_app) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_active_directory_auth_setttings"></a> [active\_directory\_auth\_setttings](#input\_active\_directory\_auth\_setttings) | Active directory authentication provider settings for app service | `any` | `{}` | no |
| <a name="input_app_insights_daily_cap_in_gb"></a> [app\_insights\_daily\_cap\_in\_gb](#input\_app\_insights\_daily\_cap\_in\_gb) | The daily cap for app insights | `string` | `null` | no |
| <a name="input_app_insights_daily_data_cap_notifications_disabled"></a> [app\_insights\_daily\_data\_cap\_notifications\_disabled](#input\_app\_insights\_daily\_data\_cap\_notifications\_disabled) | Whether notifications are enabled or not, defaults to false | `bool` | `null` | no |
| <a name="input_app_insights_force_customer_storage_for_profile"></a> [app\_insights\_force\_customer\_storage\_for\_profile](#input\_app\_insights\_force\_customer\_storage\_for\_profile) | Whether the force profile is being enabled | `bool` | `null` | no |
| <a name="input_app_insights_internet_ingestion_enabled"></a> [app\_insights\_internet\_ingestion\_enabled](#input\_app\_insights\_internet\_ingestion\_enabled) | Whether internet ingestion is enabled | `bool` | `null` | no |
| <a name="input_app_insights_internet_query_enabled"></a> [app\_insights\_internet\_query\_enabled](#input\_app\_insights\_internet\_query\_enabled) | Whether or not your workspace can be queried from the internet | `bool` | `null` | no |
| <a name="input_app_insights_local_authentication_disabled"></a> [app\_insights\_local\_authentication\_disabled](#input\_app\_insights\_local\_authentication\_disabled) | Whether local authentication is disabled | `bool` | `null` | no |
| <a name="input_app_insights_sampling_percentage"></a> [app\_insights\_sampling\_percentage](#input\_app\_insights\_sampling\_percentage) | The app insights sampling percentage | `string` | `null` | no |
| <a name="input_app_insights_type"></a> [app\_insights\_type](#input\_app\_insights\_type) | What the type of app insights to be made is | `string` | `null` | no |
| <a name="input_app_name"></a> [app\_name](#input\_app\_name) | The name of the function app | `string` | n/a | yes |
| <a name="input_app_settings"></a> [app\_settings](#input\_app\_settings) | Function App application settings | `map(any)` | `{}` | no |
| <a name="input_backup_sas_url"></a> [backup\_sas\_url](#input\_backup\_sas\_url) | URL SAS to backup | `string` | `""` | no |
| <a name="input_builtin_logging_enabled"></a> [builtin\_logging\_enabled](#input\_builtin\_logging\_enabled) | Whether AzureWebJobsDashboards should be enabled, default is true | `bool` | `true` | no |
| <a name="input_client_certificate_enabled"></a> [client\_certificate\_enabled](#input\_client\_certificate\_enabled) | Whether client certificate auth is enabled, default is false | `bool` | `false` | no |
| <a name="input_client_certificate_mode"></a> [client\_certificate\_mode](#input\_client\_certificate\_mode) | The option for client certificates | `string` | `"Optional"` | no |
| <a name="input_connect_app_insights_to_law_workspace"></a> [connect\_app\_insights\_to\_law\_workspace](#input\_connect\_app\_insights\_to\_law\_workspace) | Whether the app insights being made should be connected to a workspace id | `bool` | `null` | no |
| <a name="input_connection_strings"></a> [connection\_strings](#input\_connection\_strings) | Connection strings for App Service | `list(map(string))` | `[]` | no |
| <a name="input_daily_memory_time_quota"></a> [daily\_memory\_time\_quota](#input\_daily\_memory\_time\_quota) | The amount of memory in gigabyte-seconds that your app can consume per day, defaults to 0 | `number` | `0` | no |
| <a name="input_enable_app_insights"></a> [enable\_app\_insights](#input\_enable\_app\_insights) | Whether app insights should be made | `bool` | `false` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Is the function app enabled? Default is true | `bool` | `true` | no |
| <a name="input_force_disabled_content_share"></a> [force\_disabled\_content\_share](#input\_force\_disabled\_content\_share) | Should content share be disabled in storage account? Default is false | `bool` | `false` | no |
| <a name="input_function_app_vnet_integration_enabled"></a> [function\_app\_vnet\_integration\_enabled](#input\_function\_app\_vnet\_integration\_enabled) | Enable VNET integration with the Function App. `function_app_vnet_integration_subnet_id` is mandatory if enabled | `bool` | `false` | no |
| <a name="input_function_app_vnet_integration_subnet_id"></a> [function\_app\_vnet\_integration\_subnet\_id](#input\_function\_app\_vnet\_integration\_subnet\_id) | ID of the subnet to associate with the Function App (VNet integration) | `string` | `null` | no |
| <a name="input_functions_extension_version"></a> [functions\_extension\_version](#input\_functions\_extension\_version) | The function extension version | `string` | n/a | yes |
| <a name="input_https_only"></a> [https\_only](#input\_https\_only) | Disable http procotol and keep only https | `bool` | `true` | no |
| <a name="input_identity_ids"></a> [identity\_ids](#input\_identity\_ids) | Specifies a list of user managed identity ids to be assigned to the VM. | `list(string)` | `[]` | no |
| <a name="input_identity_type"></a> [identity\_type](#input\_identity\_type) | The Managed Service Identity Type of this Virtual Machine. | `string` | `""` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure location. | `string` | n/a | yes |
| <a name="input_rg_name"></a> [rg\_name](#input\_rg\_name) | Resource group name | `string` | n/a | yes |
| <a name="input_service_plan_id"></a> [service\_plan\_id](#input\_service\_plan\_id) | Id of the App Service Plan for Function App hosting | `string` | n/a | yes |
| <a name="input_settings"></a> [settings](#input\_settings) | Specifies the Authentication enabled or not | `bool` | `false` | no |
| <a name="input_site_config"></a> [site\_config](#input\_site\_config) | Site config for App Service. See documentation https://www.terraform.io/docs/providers/azurerm/r/app_service.html#site_config. IP restriction attribute is not managed in this block. | `any` | `{}` | no |
| <a name="input_storage_account_access_key"></a> [storage\_account\_access\_key](#input\_storage\_account\_access\_key) | Access key the storage account to use. If null a new storage account is created | `string` | `null` | no |
| <a name="input_storage_account_name"></a> [storage\_account\_name](#input\_storage\_account\_name) | Name of storage account | `string` | n/a | yes |
| <a name="input_storage_container_name"></a> [storage\_container\_name](#input\_storage\_container\_name) | The name of the storage container to keep backups | `any` | `null` | no |
| <a name="input_storage_key_vault_secret_id"></a> [storage\_key\_vault\_secret\_id](#input\_storage\_key\_vault\_secret\_id) | The secret ID for the connection string of the storage account used by the function app | `string` | `""` | no |
| <a name="input_storage_uses_managed_identity"></a> [storage\_uses\_managed\_identity](#input\_storage\_uses\_managed\_identity) | If you want the storage account to use a managed identity instead of a access key | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of the tags to use on the resources that are deployed with this module. | `map(string)` | <pre>{<br>  "source": "terraform"<br>}</pre> | no |
| <a name="input_workspace_id"></a> [workspace\_id](#input\_workspace\_id) | if app insights count is set to true. the workspace id | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_app_id"></a> [app\_id](#output\_app\_id) | The app id of the application insights |
| <a name="output_app_insights_connection_string"></a> [app\_insights\_connection\_string](#output\_app\_insights\_connection\_string) | The connection string for the application insights |
| <a name="output_custom_domain_vertification_id"></a> [custom\_domain\_vertification\_id](#output\_custom\_domain\_vertification\_id) | The identifier for DNS txt ownership |
| <a name="output_default_hostname"></a> [default\_hostname](#output\_default\_hostname) | The default hostname for the function app |
| <a name="output_fnc_app_id"></a> [fnc\_app\_id](#output\_fnc\_app\_id) | The ID of the App Service. |
| <a name="output_fnc_app_name"></a> [fnc\_app\_name](#output\_fnc\_app\_name) | The name of the App Service. |
| <a name="output_fnc_identity"></a> [fnc\_identity](#output\_fnc\_identity) | The managed identity block from the Function app |
| <a name="output_fnc_site_credential"></a> [fnc\_site\_credential](#output\_fnc\_site\_credential) | The site credential block |
| <a name="output_instrumentation_key"></a> [instrumentation\_key](#output\_instrumentation\_key) | The instrumentation key of app insights |
| <a name="output_kind"></a> [kind](#output\_kind) | The kind of the functionapp |
| <a name="output_outbound_ip_addresses"></a> [outbound\_ip\_addresses](#output\_outbound\_ip\_addresses) | A comma separated list of outbound IP addresses |
| <a name="output_possible_outbound_ip_addresses"></a> [possible\_outbound\_ip\_addresses](#output\_possible\_outbound\_ip\_addresses) | A comma separated list of outbound IP addresses. not all of which are necessarily in use |
| <a name="output_site_credential"></a> [site\_credential](#output\_site\_credential) | The output of any site credentials |
