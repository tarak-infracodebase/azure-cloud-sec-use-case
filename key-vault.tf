# Secure Key Vault with RBAC and Private Endpoint
resource "azurerm_key_vault" "main" {
  name                          = local.key_vault_name
  location                      = var.location
  resource_group_name           = azurerm_resource_group.main.name
  enabled_for_disk_encryption   = false
  enabled_for_deployment        = false
  enabled_for_template_deployment = false
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days    = var.key_vault_soft_delete_retention_days
  purge_protection_enabled      = true
  sku_name                      = "standard"

  # Enhanced security settings
  public_network_access_enabled = false
  enable_rbac_authorization     = true

  # Network ACLs (backup security layer)
  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    ip_rules                   = var.allowed_ip_ranges
    virtual_network_subnet_ids = []
  }

  tags = local.common_tags
}

# RBAC assignments for Key Vault
resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Private endpoint for Key Vault
resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-${local.naming_prefix}-kv"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-${local.naming_prefix}-kv"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdz-${local.naming_prefix}-kv"
    private_dns_zone_ids = [azurerm_private_dns_zone.key_vault.id]
  }

  tags = local.common_tags
}

# Key Vault diagnostic settings
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "diag-${local.naming_prefix}-kv"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }

  depends_on = [azurerm_log_analytics_workspace.main]
}