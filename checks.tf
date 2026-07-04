# Elastic Premium plans want an Azure Files content share, and Files has no AAD data plane for
# it, so a keyless app on an EP plan needs the content share disabled (and a run-from-package
# deploy) or keys on. Only module-managed plans can be checked here: with a brought
# service_plan_id the sku is unknowable at plan time, so the same rule is on the caller.
check "keyless_elastic_premium_needs_no_content_share" {
  assert {
    condition = alltrue([
      for k, a in var.function_apps :
      !startswith(
        a.service_plan_key != null ? var.service_plans[a.service_plan_key].sku_name : "Y1",
        "EP",
      ) || a.storage_shared_access_key_enabled || a.content_share_force_disabled == true
      if a.service_plan_id == null
    ])
    error_message = "One or more keyless apps sit on an Elastic Premium plan without content_share_force_disabled = true: the content share needs storage keys, so either disable it (and deploy run-from-package) or enable storage_shared_access_key_enabled."
  }
}

# Bring-your-own identity means the module grants nothing on storage: the identity owner must
# hold the documented role set (and wire AzureWebJobsStorage__clientId for a user-assigned
# identity) or the host fails at start.
check "byo_identity_needs_caller_grants" {
  assert {
    condition = alltrue([
      for k, a in var.function_apps :
      a.create_user_assigned_identity || a.storage_key_vault_secret_id != null || a.storage_shared_access_key_enabled || a.identity != null
    ])
    error_message = "One or more keyless apps have no module-created identity: bring an identity that holds Storage Blob Data Owner/Contributor (and Queue/Table Contributor) on the storage account, or flip keys on."
  }
}
