# Log Analytics Workspace for centralized logging
resource "azurerm_log_analytics_workspace" "main" {
  name                = local.log_analytics_workspace_name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 90  # Increased retention for security monitoring

  # Enable daily quota to control costs
  daily_quota_gb = 10

  tags = local.common_tags
}

# Application Insights for application monitoring
resource "azurerm_application_insights" "main" {
  name                = local.application_insights_name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  # Enhanced sampling for better monitoring
  sampling_percentage = 100

  tags = local.common_tags
}

# Security Alert Rules
resource "azurerm_monitor_scheduled_query_rule" "failed_logins" {
  name                = "alert-${local.naming_prefix}-failed-logins"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  action {
    action_groups = [azurerm_monitor_action_group.security.id]
  }

  data_source_id = azurerm_log_analytics_workspace.main.id
  description    = "Alert when there are multiple failed login attempts"
  enabled        = true

  query       = <<-QUERY
    SigninLogs
    | where ResultType != "0"
    | where TimeGenerated > ago(15m)
    | summarize count() by UserPrincipalName, ResultType
    | where count_ > 5
  QUERY

  severity    = 2
  frequency   = "PT15M"
  time_window = "PT15M"

  trigger {
    operator  = "GreaterThan"
    threshold = 0
  }

  tags = local.common_tags
}

resource "azurerm_monitor_scheduled_query_rule" "storage_access" {
  name                = "alert-${local.naming_prefix}-suspicious-storage-access"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  action {
    action_groups = [azurerm_monitor_action_group.security.id]
  }

  data_source_id = azurerm_log_analytics_workspace.main.id
  description    = "Alert on suspicious storage account access patterns"
  enabled        = true

  query       = <<-QUERY
    StorageBlobLogs
    | where TimeGenerated > ago(1h)
    | where StatusCode >= 400
    | summarize count() by ClientIP, OperationName
    | where count_ > 10
  QUERY

  severity    = 1
  frequency   = "PT1H"
  time_window = "PT1H"

  trigger {
    operator  = "GreaterThan"
    threshold = 0
  }

  tags = local.common_tags
}

# Action Group for Security Alerts
resource "azurerm_monitor_action_group" "security" {
  name                = "ag-${local.naming_prefix}-security"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "security"

  # Email notifications (add actual email addresses in production)
  email_receiver {
    name          = "security-team"
    email_address = "security@example.com"  # Replace with actual email
  }

  # Webhook for integration with SIEM/SOAR
  webhook_receiver {
    name                    = "security-webhook"
    service_uri             = "https://example.com/webhook"  # Replace with actual webhook
    use_common_alert_schema = true
  }

  tags = local.common_tags
}

# Activity Log Alert for administrative actions
resource "azurerm_monitor_activity_log_alert" "admin_actions" {
  name                = "alert-${local.naming_prefix}-admin-actions"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [data.azurerm_client_config.current.subscription_id]
  description         = "Alert on critical administrative actions"

  criteria {
    category = "Administrative"

    operation_name = "Microsoft.Authorization/roleAssignments/write"
    resource_type  = "Microsoft.Authorization/roleAssignments"
  }

  action {
    action_group_id = azurerm_monitor_action_group.security.id
  }

  tags = local.common_tags
}

# Data Collection Rule for enhanced monitoring
resource "azurerm_monitor_data_collection_rule" "security" {
  name                = "dcr-${local.naming_prefix}-security"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.main.id
      name                  = "destination-log"
    }
  }

  data_flow {
    streams      = ["Microsoft-SecurityEvent"]
    destinations = ["destination-log"]
  }

  data_sources {
    windows_event_log {
      streams        = ["Microsoft-SecurityEvent"]
      x_path_queries = ["Security!*"]
      name           = "eventLogsDataSource"
    }
  }

  tags = local.common_tags
}