# Main Resource Group
resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location

  tags = local.common_tags
}

# Private DNS Zones for Private Endpoints
resource "azurerm_private_dns_zone" "key_vault" {
  name                = local.private_dns_zone_kv_name
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

resource "azurerm_private_dns_zone" "storage" {
  name                = local.private_dns_zone_storage_name
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

resource "azurerm_private_dns_zone" "postgresql" {
  name                = local.private_dns_zone_postgres_name
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

# Link private DNS zones to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  name                  = "link-${local.naming_prefix}-kv"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage" {
  name                  = "link-${local.naming_prefix}-storage"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.storage.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  name                  = "link-${local.naming_prefix}-postgres"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.postgresql.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false

  tags = local.common_tags
}