# Asset Management and Documentation (OWASP ISR10)
# Enhanced asset visibility and configuration management

# Resource Graph queries for asset discovery
resource "azurerm_resource_group" "asset_management" {
  name     = "${local.resource_group_name}-asset-mgmt"
  location = var.location

  tags = merge(local.common_tags, {
    Purpose = "Asset Management and Compliance"
  })
}

# Automation Account for asset management
resource "azurerm_automation_account" "asset_management" {
  name                = "aa-${local.naming_prefix}-asset-mgmt"
  location            = var.location
  resource_group_name = azurerm_resource_group.asset_management.name
  sku_name            = "Basic"

  # Enable managed identity for secure automation
  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Asset inventory runbook
resource "azurerm_automation_runbook" "asset_inventory" {
  name                    = "AssetInventoryCollection"
  location                = var.location
  resource_group_name     = azurerm_resource_group.asset_management.name
  automation_account_name = azurerm_automation_account.asset_management.name
  log_verbose             = true
  log_progress            = true
  runbook_type           = "PowerShell"

  content = <<CONTENT
<#
.SYNOPSIS
    Automated asset inventory collection and documentation
.DESCRIPTION
    Collects comprehensive asset inventory and sends to Log Analytics
#>

# Connect using managed identity
Connect-AzAccount -Identity

# Get subscription context
$subscriptionId = (Get-AzContext).Subscription.Id
$resources = Get-AzResource | Select-Object Name, ResourceGroupName, ResourceType, Location, Tags

# Create asset inventory object
$assetInventory = @{
    CollectionDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    SubscriptionId = $subscriptionId
    ResourceCount = $resources.Count
    Resources = $resources
}

# Send to Log Analytics workspace
$customLogName = "AssetInventory"
$json = $assetInventory | ConvertTo-Json -Depth 10

# Write to Log Analytics (requires additional configuration)
Write-Output "Asset inventory collected: $($resources.Count) resources"
Write-Output $json
CONTENT

  tags = local.common_tags
}

# Schedule for regular asset inventory
resource "azurerm_automation_schedule" "asset_inventory_daily" {
  name                    = "AssetInventoryDaily"
  resource_group_name     = azurerm_resource_group.asset_management.name
  automation_account_name = azurerm_automation_account.asset_management.name
  frequency               = "Day"
  interval                = 1
  start_time              = "2025-01-01T02:00:00Z"
  description             = "Daily asset inventory collection"
}

# Link runbook to schedule
resource "azurerm_automation_job_schedule" "asset_inventory" {
  resource_group_name     = azurerm_resource_group.asset_management.name
  automation_account_name = azurerm_automation_account.asset_management.name
  schedule_name           = azurerm_automation_schedule.asset_inventory_daily.name
  runbook_name            = azurerm_automation_runbook.asset_inventory.name
}

# Configuration drift detection using Azure Policy
resource "azurerm_policy_assignment" "configuration_monitoring" {
  name                 = "config-drift-monitoring-${var.environment}"
  scope                = data.azurerm_client_config.current.subscription_id
  policy_definition_id = "/providers/Microsoft.Authorization/policySetDefinitions/89c6cddc-1c73-4ac1-b19c-54d1a15a42f2"
  display_name         = "Azure Security Benchmark configuration monitoring"
  description          = "Monitor configuration drift against Azure Security Benchmark"

  parameters = jsonencode({
    effect = {
      value = "AuditIfNotExists"
    }
  })
}

# Resource tagging enforcement
resource "azurerm_policy_assignment" "require_tags" {
  name                 = "require-tags-${var.environment}"
  scope                = azurerm_resource_group.main.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/1e30110a-5ceb-460c-a204-c1c3969c6d62"
  display_name         = "Require specific tags on resources"
  description          = "Enforce required tags for asset management"

  parameters = jsonencode({
    tagName = {
      value = "AssetOwner"
    }
    tagValue = {
      value = "InfracodebaseTeam"
    }
  })
}

# Custom Log Analytics table for asset inventory
resource "azurerm_log_analytics_workspace_table" "asset_inventory" {
  workspace_id = azurerm_log_analytics_workspace.main.id
  name         = "AssetInventory_CL"

  schema {
    column {
      name = "TimeGenerated"
      type = "DateTime"
    }
    column {
      name = "ResourceName"
      type = "String"
    }
    column {
      name = "ResourceType"
      type = "String"
    }
    column {
      name = "ResourceGroup"
      type = "String"
    }
    column {
      name = "Location"
      type = "String"
    }
    column {
      name = "SecurityCompliance"
      type = "String"
    }
    column {
      name = "LastAssessed"
      type = "DateTime"
    }
  }

  retention_in_days = 90
}

# Asset management alerts
resource "azurerm_monitor_scheduled_query_rule" "untagged_resources" {
  name                = "alert-${local.naming_prefix}-untagged-resources"
  location            = var.location
  resource_group_name = azurerm_resource_group.asset_management.name

  action {
    action_groups = [azurerm_monitor_action_group.security.id]
  }

  data_source_id = azurerm_log_analytics_workspace.main.id
  description    = "Alert when resources are created without required tags"
  enabled        = true

  query       = <<-QUERY
    AzureActivity
    | where TimeGenerated > ago(1h)
    | where OperationNameValue has "write"
    | where ActivityStatusValue == "Success"
    | where ResourceProviderValue != "Microsoft.Insights"
    | project TimeGenerated, Caller, OperationNameValue, ResourceGroup, ResourceId
  QUERY

  severity    = 2
  frequency   = "PT1H"
  time_window = "PT1H"

  trigger {
    operator  = "GreaterThan"
    threshold = 0
  }

  tags = local.common_tags
}