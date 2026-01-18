# Microsoft Defender for Cloud Configuration
resource "azurerm_security_center_subscription_pricing" "defender_servers" {
  tier          = "Standard"
  resource_type = "VirtualMachines"
  subplan       = "P2"
}

resource "azurerm_security_center_subscription_pricing" "defender_app_services" {
  tier          = "Standard"
  resource_type = "AppServices"
}

resource "azurerm_security_center_subscription_pricing" "defender_sql_servers" {
  tier          = "Standard"
  resource_type = "SqlServers"
}

resource "azurerm_security_center_subscription_pricing" "defender_sql_server_vms" {
  tier          = "Standard"
  resource_type = "SqlServerVirtualMachines"
}

resource "azurerm_security_center_subscription_pricing" "defender_open_source_dbs" {
  tier          = "Standard"
  resource_type = "OpenSourceRelationalDatabases"
}

resource "azurerm_security_center_subscription_pricing" "defender_cosmos_db" {
  tier          = "Standard"
  resource_type = "CosmosDbs"
}

resource "azurerm_security_center_subscription_pricing" "defender_storage" {
  tier          = "Standard"
  resource_type = "StorageAccounts"
  subplan       = "DefenderForStorageV2"
}

resource "azurerm_security_center_subscription_pricing" "defender_containers" {
  tier          = "Standard"
  resource_type = "Containers"
}

resource "azurerm_security_center_subscription_pricing" "defender_key_vault" {
  tier          = "Standard"
  resource_type = "KeyVaults"
}

resource "azurerm_security_center_subscription_pricing" "defender_resource_manager" {
  tier          = "Standard"
  resource_type = "Arm"
}

resource "azurerm_security_center_subscription_pricing" "defender_apis" {
  tier          = "Standard"
  resource_type = "Api"
}

resource "azurerm_security_center_subscription_pricing" "defender_cspm" {
  tier          = "Standard"
  resource_type = "CloudPosture"
}

# Security Center Contact
resource "azurerm_security_center_contact" "main" {
  email = "security@example.com"  # Replace with actual security team email
  phone = "+1-555-555-5555"       # Replace with actual phone number

  alert_notifications = true
  alerts_to_admins    = true
}

# Security Center Auto Provisioning
resource "azurerm_security_center_auto_provisioning" "main" {
  auto_provision = "On"
}

# Security policies and assessments
resource "azurerm_security_center_assessment_policy" "custom_security_policy" {
  display_name = "Custom Security Assessment - ${var.project_name}"
  severity     = "Medium"
  description  = "Custom security assessment for enhanced monitoring"

  implementation_effort   = "Low"
  remediation_description = "Follow the security best practices outlined in the assessment"
  assessment_type         = "CustomerManaged"
  categories              = ["Data"]
  user_impact             = "Low"

  depends_on = [azurerm_log_analytics_workspace.main]
}

# Enable Microsoft Defender for specific resources
resource "azurerm_security_center_server_vulnerability_assessment" "key_vault" {
  server_vulnerability_assessment_id = azurerm_key_vault.main.id
  storage_container_path              = "${azurerm_storage_account.main.primary_blob_endpoint}vulnerability-assessment"
  storage_account_access_key          = null  # Use managed identity

  recurring_scans {
    is_enabled                           = true
    email_subscription_admins            = true
    emails                               = ["security@example.com"]  # Replace with actual email
  }

  depends_on = [azurerm_storage_account.main]
}

# Azure Policy Assignments for Security
resource "azurerm_policy_assignment" "require_https_storage" {
  name                 = "require-https-storage-${var.environment}"
  scope                = azurerm_resource_group.main.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9"
  display_name         = "Secure transfer to storage accounts should be enabled"
  description          = "Audit requirement of Secure transfer in your storage account"

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}

resource "azurerm_policy_assignment" "require_key_vault_firewall" {
  name                 = "require-kv-firewall-${var.environment}"
  scope                = azurerm_resource_group.main.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/55615ac9-af46-4a59-874e-391cc3dfb490"
  display_name         = "Azure Key Vault should have firewall enabled"
  description          = "Audit Azure Key Vault instances that do not have firewall enabled"

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}

resource "azurerm_policy_assignment" "require_private_endpoints" {
  name                 = "require-private-endpoints-${var.environment}"
  scope                = azurerm_resource_group.main.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/6edd7eda-6dd8-40f7-810d-67160c639cd9"
  display_name         = "Storage accounts should use private link"
  description          = "Azure Private Link lets you connect your virtual network to Azure services without a public IP address"

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}

# Diagnostic settings for subscription-level activities
resource "azurerm_monitor_diagnostic_setting" "subscription" {
  name                       = "diag-${local.naming_prefix}-subscription"
  target_resource_id         = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "Administrative"
  }

  enabled_log {
    category = "Security"
  }

  enabled_log {
    category = "Alert"
  }

  enabled_log {
    category = "Policy"
  }

  depends_on = [azurerm_log_analytics_workspace.main]
}