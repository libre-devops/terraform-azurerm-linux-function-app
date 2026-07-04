provider "azurerm" {
  features {
    resource_group {
      # Application Insights auto-creates an untracked "Smart Detection" action group in the
      # group; without this, the disposable stack's destroy is blocked by it.
      prevent_deletion_if_contains_resources = false
    }
  }

  storage_use_azuread = true
  use_oidc            = true
}
