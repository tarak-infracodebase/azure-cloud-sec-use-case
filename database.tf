# Secure PostgreSQL Flexible Server with Private Networking
resource "azurerm_postgresql_flexible_server" "main" {
  name                = local.postgresql_server_name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  # Administrator credentials (use Key Vault for production)
  administrator_login    = "psqladmin"
  administrator_password = random_password.postgresql_password.result

  # Server configuration
  sku_name                     = var.postgresql_sku_name
  version                      = var.postgresql_version
  storage_mb                   = 32768  # 32 GB
  storage_tier                 = "P4"
  auto_grow_enabled           = true

  # Enhanced security configuration
  public_network_access_enabled = false
  delegated_subnet_id          = azurerm_subnet.database.id
  private_dns_zone_id          = azurerm_private_dns_zone.postgresql.id

  # Backup configuration with geo-redundancy
  backup_retention_days        = var.postgresql_backup_retention_days
  geo_redundant_backup_enabled = var.enable_geo_redundant_backup

  # High availability configuration
  high_availability {
    mode                      = "ZoneRedundant"
    standby_availability_zone = "2"
  }

  # Maintenance window
  maintenance_window {
    day_of_week  = 0  # Sunday
    start_hour   = 2
    start_minute = 0
  }

  # Authentication configuration
  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = false  # Use Azure AD only
    tenant_id                     = data.azurerm_client_config.current.tenant_id
  }

  tags = local.common_tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgresql]
}

# Random password for PostgreSQL (will be stored in Key Vault)
resource "random_password" "postgresql_password" {
  length  = 32
  special = true
  upper   = true
  lower   = true
  numeric = true
}

# Store PostgreSQL password in Key Vault
resource "azurerm_key_vault_secret" "postgresql_password" {
  name         = "postgresql-admin-password"
  value        = random_password.postgresql_password.result
  key_vault_id = azurerm_key_vault.main.id

  tags = local.common_tags

  depends_on = [azurerm_role_assignment.kv_admin]
}

# PostgreSQL Azure AD Administrator
resource "azurerm_postgresql_flexible_server_active_directory_administrator" "main" {
  server_name         = azurerm_postgresql_flexible_server.main.name
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = data.azurerm_client_config.current.object_id
  principal_name      = "Terraform Service Principal"
  principal_type      = "ServicePrincipal"
}

# PostgreSQL Configuration for enhanced security
resource "azurerm_postgresql_flexible_server_configuration" "log_connections" {
  name      = "log_connections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "log_disconnections" {
  name      = "log_disconnections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "log_checkpoints" {
  name      = "log_checkpoints"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "log_statement" {
  name      = "log_statement"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "all"
}

resource "azurerm_postgresql_flexible_server_configuration" "connection_throttling" {
  name      = "connection_throttling"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

# PostgreSQL diagnostic settings
resource "azurerm_monitor_diagnostic_setting" "postgresql" {
  name                       = "diag-${local.naming_prefix}-postgres"
  target_resource_id         = azurerm_postgresql_flexible_server.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "PostgreSQLLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }

  depends_on = [azurerm_log_analytics_workspace.main]
}

# Microsoft Defender for PostgreSQL
resource "azurerm_security_center_server_vulnerability_assessment" "postgresql" {
  server_vulnerability_assessment_id = azurerm_postgresql_flexible_server.main.id
  storage_container_path              = "${azurerm_storage_account.main.primary_blob_endpoint}vulnerability-assessment"
  storage_account_access_key          = null  # Use managed identity

  recurring_scans {
    is_enabled                           = true
    email_subscription_admins            = true
    emails                               = []
  }

  depends_on = [azurerm_storage_account.main]
}