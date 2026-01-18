# Azure Provider Configuration
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }

    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    storage {
      soft_delete_on_destroy = true
    }
  }

  # Use environment variables for authentication
  # AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID
}

# Azure AD Provider Configuration
provider "azuread" {
  # Inherits authentication from azurerm provider
}