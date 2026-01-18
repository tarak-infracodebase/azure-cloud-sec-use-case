# Secure Storage Account with Advanced Security Features
resource "azurerm_storage_account" "main" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  account_tier             = var.storage_account_tier
  account_replication_type = "ZRS"  # Zone-redundant storage for high availability

  # Enhanced security configuration
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication  = true
  min_tls_version                  = "TLS1_2"
  https_traffic_only_enabled       = true

  # Enable infrastructure encryption
  infrastructure_encryption_enabled = true

  # Blob properties for enhanced security
  blob_properties {
    # Enable blob versioning
    versioning_enabled = true

    # Enable change feed
    change_feed_enabled = true

    # Enable point-in-time restore
    restore_policy {
      days = 30
    }

    # Container soft delete
    container_delete_retention_policy {
      days = 30
    }

    # Blob soft delete
    delete_retention_policy {
      days = 30
    }
  }

  # Network access rules
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    ip_rules                   = var.allowed_ip_ranges
    virtual_network_subnet_ids = []
  }

  tags = local.common_tags
}

# Private endpoint for Blob storage
resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pe-${local.naming_prefix}-storage-blob"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-${local.naming_prefix}-storage-blob"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdz-${local.naming_prefix}-storage"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage.id]
  }

  tags = local.common_tags
}

# Advanced Threat Protection for Storage
resource "azurerm_security_center_storage_defender" "main" {
  storage_account_id = azurerm_storage_account.main.id

  # Enable all advanced threat protection features
  malware_scanning_on_upload_enabled         = true
  malware_scanning_on_upload_cap_gb_per_month = 5000
  sensitive_data_discovery_enabled           = true
  override_subscription_settings_enabled     = false
}

# Storage account diagnostic settings
resource "azurerm_monitor_diagnostic_setting" "storage_account" {
  name                       = "diag-${local.naming_prefix}-storage"
  target_resource_id         = azurerm_storage_account.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  metric {
    category = "Transaction"
    enabled  = true
  }

  depends_on = [azurerm_log_analytics_workspace.main]
}

# Blob service diagnostic settings
resource "azurerm_monitor_diagnostic_setting" "storage_blob" {
  name                       = "diag-${local.naming_prefix}-storage-blob"
  target_resource_id         = "${azurerm_storage_account.main.id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
    enabled  = true
  }

  depends_on = [azurerm_log_analytics_workspace.main]
}