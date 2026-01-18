# Advanced Security Controls for Complete OWASP ISR Compliance
# Additional security measures for defense in depth

# Azure Sentinel (SIEM) for advanced threat detection
resource "azurerm_log_analytics_solution" "security_insights" {
  solution_name         = "SecurityInsights"
  location              = var.location
  resource_group_name   = azurerm_resource_group.asset_management.name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/SecurityInsights"
  }

  tags = local.common_tags
}

# Azure Sentinel data connectors
resource "azurerm_sentinel_data_connector_azure_active_directory" "aad" {
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

resource "azurerm_sentinel_data_connector_azure_security_center" "asc" {
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

resource "azurerm_sentinel_data_connector_azure_activity" "activity" {
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

# Azure Sentinel analytics rules for threat detection
resource "azurerm_sentinel_alert_rule_scheduled" "suspicious_login_activity" {
  name                       = "SuspiciousLoginActivity"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  display_name              = "Suspicious Login Activity Detected"
  severity                  = "High"
  enabled                   = true

  query_frequency   = "PT1H"
  query_period      = "PT1H"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  query = <<QUERY
SigninLogs
| where TimeGenerated > ago(1h)
| where ResultType != "0"
| where RiskLevelDuringSignIn == "high" or RiskLevelAggregated == "high"
| project TimeGenerated, UserPrincipalName, AppDisplayName, IPAddress, Location, RiskDetail
QUERY

  tactics = ["InitialAccess", "CredentialAccess"]

  incident_configuration {
    create_incident = true
    grouping {
      enabled                 = true
      lookback_duration      = "PT5H"
      reopen_closed_incidents = false
      entity_matching_method  = "AllEntities"
    }
  }
}

resource "azurerm_sentinel_alert_rule_scheduled" "privileged_account_changes" {
  name                       = "PrivilegedAccountChanges"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  display_name              = "Changes to Privileged Accounts"
  severity                  = "High"
  enabled                   = true

  query_frequency   = "PT15M"
  query_period      = "PT15M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  query = <<QUERY
AuditLogs
| where TimeGenerated > ago(15m)
| where OperationName has_any ("Add member to role", "Remove member from role", "Update role")
| where TargetResources has_any ("Global Administrator", "Security Administrator", "Privileged Role Administrator")
| project TimeGenerated, InitiatedBy, OperationName, TargetResources, Result
QUERY

  tactics = ["PrivilegeEscalation", "Persistence"]

  incident_configuration {
    create_incident = true
  }
}

# Just-In-Time VM Access (for future VM deployments)
resource "azurerm_security_center_jit_network_access_policy" "vm_jit" {
  count               = 0  # Enable when VMs are deployed
  kind                = "Basic"
  location            = var.location
  name                = "jit-${local.naming_prefix}"
  resource_group_name = azurerm_resource_group.main.name

  # Configuration for future VMs
  dynamic "virtual_machine" {
    for_each = []  # Will be populated when VMs exist
    content {
      id   = virtual_machine.value.id
      port {
        number                     = 22
        protocol                   = "TCP"
        allowed_source_address_prefix = var.allowed_ip_ranges[0]
        max_request_access_duration = "PT3H"
      }
    }
  }
}

# Conditional Access policies enforcement
resource "azurerm_monitor_scheduled_query_rule" "conditional_access_violations" {
  name                = "alert-${local.naming_prefix}-conditional-access-violations"
  location            = var.location
  resource_group_name = azurerm_resource_group.asset_management.name

  action {
    action_groups = [azurerm_monitor_action_group.security.id]
  }

  data_source_id = azurerm_log_analytics_workspace.main.id
  description    = "Alert on Conditional Access policy violations"
  enabled        = true

  query       = <<-QUERY
    SigninLogs
    | where TimeGenerated > ago(1h)
    | mv-expand ConditionalAccessPolicies
    | where ConditionalAccessPolicies.result == "failure"
    | project TimeGenerated, UserPrincipalName, AppDisplayName, IPAddress, ConditionalAccessPolicies.displayName
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

# Network traffic analysis
resource "azurerm_network_watcher_flow_log" "main" {
  count                = length([for nsg in [azurerm_network_security_group.private, azurerm_network_security_group.database, azurerm_network_security_group.private_endpoints] : nsg])
  network_watcher_name = "NetworkWatcher_${lower(replace(var.location, " ", ""))}"
  resource_group_name  = "NetworkWatcherRG"
  name                 = "flowlog-${local.naming_prefix}-${count.index}"

  network_security_group_id = [azurerm_network_security_group.private, azurerm_network_security_group.database, azurerm_network_security_group.private_endpoints][count.index].id
  storage_account_id        = azurerm_storage_account.main.id
  enabled                   = true
  version                   = 2

  retention_policy {
    enabled = true
    days    = 30
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.main.workspace_id
    workspace_region      = azurerm_log_analytics_workspace.main.location
    workspace_resource_id = azurerm_log_analytics_workspace.main.id
    interval_in_minutes   = 10
  }

  tags = local.common_tags
}

# Threat intelligence integration
resource "azurerm_sentinel_threat_intelligence_indicator" "malicious_ip_ranges" {
  count                      = 0  # Placeholder for threat intelligence feeds
  workspace_id              = azurerm_log_analytics_workspace.main.id
  display_name              = "Known Malicious IP Range"
  pattern                   = "[ipv4-addr:value = '0.0.0.0/32']"
  pattern_type              = "stix"
  source                    = "Microsoft Threat Intelligence"
  validate_from_cloud       = true
  threat_intelligence_tags  = ["malicious-activity"]

  # This would be populated from actual threat intelligence feeds
}

# Data Loss Prevention (DLP) monitoring
resource "azurerm_monitor_scheduled_query_rule" "data_exfiltration" {
  name                = "alert-${local.naming_prefix}-data-exfiltration"
  location            = var.location
  resource_group_name = azurerm_resource_group.asset_management.name

  action {
    action_groups = [azurerm_monitor_action_group.security.id]
  }

  data_source_id = azurerm_log_analytics_workspace.main.id
  description    = "Alert on potential data exfiltration attempts"
  enabled        = true

  query       = <<-QUERY
    StorageBlobLogs
    | where TimeGenerated > ago(1h)
    | where OperationName == "GetBlob"
    | summarize RequestCount = count(), DataTransferred = sum(ResponseBodySize) by ClientIP, bin(TimeGenerated, 5m)
    | where RequestCount > 100 or DataTransferred > 1000000  // 1MB threshold
    | project TimeGenerated, ClientIP, RequestCount, DataTransferred
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

# Compliance dashboard
resource "azurerm_dashboard" "security_compliance" {
  name                = "dashboard-${local.naming_prefix}-security"
  resource_group_name = azurerm_resource_group.asset_management.name
  location            = var.location

  dashboard_properties = jsonencode({
    lenses = {
      "0" = {
        order = 0
        parts = {
          "0" = {
            position = {
              x = 0
              y = 0
              colSpan = 6
              rowSpan = 4
            }
            metadata = {
              inputs = [
                {
                  name = "resourceId"
                  value = azurerm_log_analytics_workspace.main.id
                }
              ]
              type = "Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart"
            }
          }
        }
      }
    }
    metadata = {
      model = {
        timeRange = {
          value = {
            relative = {
              duration = 24
              timeUnit = 1
            }
          }
          type = "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
        }
      }
    }
  })

  tags = local.common_tags
}