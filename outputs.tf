# Resource identifiers and connection information
output "resource_group_name" {
  description = "Name of the main resource group"
  value       = azurerm_resource_group.main.name
}

output "virtual_network_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
  sensitive   = true
}

output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.main.id
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint of the storage account"
  value       = azurerm_storage_account.main.primary_blob_endpoint
  sensitive   = true
}

output "postgresql_server_id" {
  description = "ID of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.main.id
}

output "postgresql_server_fqdn" {
  description = "FQDN of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.main.fqdn
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "application_insights_id" {
  description = "ID of the Application Insights instance"
  value       = azurerm_application_insights.main.id
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection string for Application Insights"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

# Security-related outputs
output "private_dns_zones" {
  description = "List of private DNS zones created"
  value = {
    key_vault  = azurerm_private_dns_zone.key_vault.name
    storage    = azurerm_private_dns_zone.storage.name
    postgresql = azurerm_private_dns_zone.postgresql.name
  }
}

output "private_endpoints" {
  description = "List of private endpoints created"
  value = {
    key_vault    = azurerm_private_endpoint.key_vault.name
    storage_blob = azurerm_private_endpoint.storage_blob.name
  }
}

output "network_security_groups" {
  description = "List of Network Security Groups created"
  value = {
    private           = azurerm_network_security_group.private.name
    database          = azurerm_network_security_group.database.name
    private_endpoints = azurerm_network_security_group.private_endpoints.name
  }
}

# Compliance and security status
output "security_features_enabled" {
  description = "Summary of security features enabled"
  value = {
    key_vault_firewall                = "Enabled via private endpoint"
    key_vault_purge_protection        = azurerm_key_vault.main.purge_protection_enabled
    key_vault_rbac_authorization      = azurerm_key_vault.main.enable_rbac_authorization
    storage_https_only                = azurerm_storage_account.main.https_traffic_only_enabled
    storage_public_access_disabled    = !azurerm_storage_account.main.allow_nested_items_to_be_public
    storage_shared_key_disabled       = !azurerm_storage_account.main.shared_access_key_enabled
    postgresql_public_access_disabled = !azurerm_postgresql_flexible_server.main.public_network_access_enabled
    postgresql_azure_ad_auth          = true
    defender_for_storage              = "Enabled"
    defender_for_key_vault            = "Enabled via subscription"
    diagnostic_logging                = "Enabled for all resources"
  }
}