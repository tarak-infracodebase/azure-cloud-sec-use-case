# Patch Management and Vulnerability Assessment (OWASP ISR01)
# Automated patching and vulnerability scanning

# Azure Update Management for OS patching
resource "azurerm_automation_account" "patch_management" {
  name                = "aa-${local.naming_prefix}-patch-mgmt"
  location            = var.location
  resource_group_name = azurerm_resource_group.asset_management.name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Update Management solution
resource "azurerm_log_analytics_solution" "updates" {
  solution_name         = "Updates"
  location              = var.location
  resource_group_name   = azurerm_resource_group.asset_management.name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Updates"
  }

  tags = local.common_tags
}

# Container vulnerability scanning
resource "azurerm_security_center_subscription_pricing" "defender_containers_extended" {
  tier          = "Standard"
  resource_type = "Containers"
}

# SQL vulnerability assessments
resource "azurerm_mssql_server_security_alert_policy" "postgresql_security" {
  count                      = 0  # Only if SQL Server exists
  # This is for future SQL Server instances
}

# Custom vulnerability assessment script
resource "azurerm_automation_runbook" "vulnerability_scan" {
  name                    = "VulnerabilityAssessment"
  location                = var.location
  resource_group_name     = azurerm_resource_group.asset_management.name
  automation_account_name = azurerm_automation_account.patch_management.name
  log_verbose             = true
  log_progress            = true
  runbook_type           = "PowerShell"

  content = <<CONTENT
<#
.SYNOPSIS
    Comprehensive vulnerability assessment
.DESCRIPTION
    Scans for known vulnerabilities and configuration issues
#>

# Connect using managed identity
Connect-AzAccount -Identity

# Check for outdated software versions
$vulnerabilities = @()

# Check PostgreSQL version
$postgresqlServers = Get-AzPostgreSqlServer
foreach ($server in $postgresqlServers) {
    if ([version]$server.Version -lt [version]"16.0") {
        $vulnerabilities += @{
            ResourceId = $server.Id
            ResourceType = "PostgreSQL"
            Vulnerability = "Outdated PostgreSQL version"
            Severity = "High"
            Recommendation = "Upgrade to PostgreSQL 16"
        }
    }
}

# Check storage account TLS versions
$storageAccounts = Get-AzStorageAccount
foreach ($storage in $storageAccounts) {
    if ($storage.MinimumTlsVersion -ne "TLS1_2") {
        $vulnerabilities += @{
            ResourceId = $storage.Id
            ResourceType = "StorageAccount"
            Vulnerability = "Weak TLS version"
            Severity = "Medium"
            Recommendation = "Enforce TLS 1.2 minimum"
        }
    }
}

# Output results
Write-Output "Vulnerability scan completed. Found $($vulnerabilities.Count) issues."
$vulnerabilities | ConvertTo-Json -Depth 3
CONTENT

  tags = local.common_tags
}

# Schedule vulnerability scans
resource "azurerm_automation_schedule" "vulnerability_scan_weekly" {
  name                    = "VulnerabilityScanWeekly"
  resource_group_name     = azurerm_resource_group.asset_management.name
  automation_account_name = azurerm_automation_account.patch_management.name
  frequency               = "Week"
  interval                = 1
  week_days               = ["Sunday"]
  start_time              = "2025-01-05T03:00:00Z"
  description             = "Weekly vulnerability assessment"
}

resource "azurerm_automation_job_schedule" "vulnerability_scan" {
  resource_group_name     = azurerm_resource_group.asset_management.name
  automation_account_name = azurerm_automation_account.patch_management.name
  schedule_name           = azurerm_automation_schedule.vulnerability_scan_weekly.name
  runbook_name            = azurerm_automation_runbook.vulnerability_scan.name
}

# Software update deployment
resource "azurerm_automation_software_update_configuration" "security_updates" {
  name                    = "SecurityUpdatesDeployment"
  automation_account_id   = azurerm_automation_account.patch_management.id

  operating_system = "Linux"

  linux {
    classification_included = ["Security", "Critical"]
    excluded_packages       = []
    included_packages       = []
    reboot_setting         = "IfRequired"
  }

  duration = "PT2H"

  schedule {
    frequency           = "Week"
    interval            = 1
    start_time          = "2025-01-05T02:00:00Z"
    advanced_week_days  = ["Sunday"]
    description         = "Weekly security updates deployment"
    next_run            = "2025-01-05T02:00:00Z"
    next_run_offset_minutes = 0
  }

  # Target specific resource groups
  target {
    azure_query {
      scope = [azurerm_resource_group.main.id]
      tag_filter = "Any"
    }
  }

  # Pre and post deployment scripts
  pre_task {
    source = "BackupBeforePatching"
    parameters = {
      "ResourceGroupName" = azurerm_resource_group.main.name
    }
  }

  post_task {
    source = "ValidateAfterPatching"
    parameters = {
      "ResourceGroupName" = azurerm_resource_group.main.name
    }
  }
}

# Patch compliance monitoring
resource "azurerm_monitor_scheduled_query_rule" "patch_compliance" {
  name                = "alert-${local.naming_prefix}-patch-compliance"
  location            = var.location
  resource_group_name = azurerm_resource_group.asset_management.name

  action {
    action_groups = [azurerm_monitor_action_group.security.id]
  }

  data_source_id = azurerm_log_analytics_workspace.main.id
  description    = "Alert on systems with missing critical patches"
  enabled        = true

  query       = <<-QUERY
    Update
    | where TimeGenerated > ago(7d)
    | where Classification == "Security Updates" or Classification == "Critical Updates"
    | where UpdateState == "Needed"
    | summarize MissingUpdates = count() by Computer
    | where MissingUpdates > 0
  QUERY

  severity    = 1
  frequency   = "PT6H"
  time_window = "PT6H"

  trigger {
    operator  = "GreaterThan"
    threshold = 0
  }

  tags = local.common_tags
}