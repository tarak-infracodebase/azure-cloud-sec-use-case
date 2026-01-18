# Local values for consistent naming and configuration
locals {
  # Naming conventions
  naming_prefix = "${var.project_name}-${var.environment}"
  location_short = {
    "East US"   = "use"
    "East US 2" = "use2"
    "West US"   = "usw"
    "West US 2" = "usw2"
  }
  location_abbreviation = local.location_short[var.location]

  # Resource names
  resource_group_name               = "rg-${local.location_abbreviation}-${local.naming_prefix}"
  virtual_network_name              = "vnet-${local.location_abbreviation}-${local.naming_prefix}"
  key_vault_name                    = "kv-${local.location_abbreviation}-${var.project_name}-${var.environment}"
  storage_account_name              = replace("st${local.location_abbreviation}${var.project_name}${var.environment}", "-", "")
  postgresql_server_name            = "psql-${local.location_abbreviation}-${local.naming_prefix}"
  log_analytics_workspace_name     = "log-${local.location_abbreviation}-${local.naming_prefix}"
  application_insights_name         = "appi-${local.location_abbreviation}-${local.naming_prefix}"
  private_dns_zone_kv_name         = "privatelink.vaultcore.azure.net"
  private_dns_zone_postgres_name   = "privatelink.postgres.database.azure.com"
  private_dns_zone_storage_name    = "privatelink.blob.core.windows.net"

  # Network configuration
  vnet_address_space     = ["10.0.0.0/16"]
  subnet_private_cidr    = "10.0.1.0/24"
  subnet_endpoints_cidr  = "10.0.2.0/24"
  subnet_database_cidr   = "10.0.3.0/24"

  # Common tags
  common_tags = merge(var.tags, {
    CreatedDate = formatdate("YYYY-MM-DD", timestamp())
    Location    = var.location
  })
}

# Data sources for existing resources
data "azurerm_client_config" "current" {}

data "azuread_client_config" "current" {}

# Get current user for Key Vault access
data "azuread_user" "current" {
  object_id = data.azuread_client_config.current.object_id
}