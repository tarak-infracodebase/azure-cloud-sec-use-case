# Environment and naming variables
variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
  default     = "dev"
}

variable "location" {
  type        = string
  description = "Azure region for resource deployment"
  default     = "East US 2"
}

variable "project_name" {
  type        = string
  description = "Project name for resource naming"
  default     = "infracodebase"
}

variable "allowed_ip_ranges" {
  type        = list(string)
  description = "Allowed IP ranges for administrative access"
  default     = []
}

variable "key_vault_soft_delete_retention_days" {
  type        = number
  description = "Number of days to retain soft deleted Key Vault items"
  default     = 90

  validation {
    condition     = var.key_vault_soft_delete_retention_days >= 7 && var.key_vault_soft_delete_retention_days <= 90
    error_message = "Key Vault soft delete retention must be between 7 and 90 days."
  }
}

variable "storage_account_tier" {
  type        = string
  description = "Storage account performance tier"
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.storage_account_tier)
    error_message = "Storage account tier must be either Standard or Premium."
  }
}

variable "postgresql_version" {
  type        = string
  description = "PostgreSQL server version"
  default     = "16"
}

variable "postgresql_sku_name" {
  type        = string
  description = "PostgreSQL server SKU name"
  default     = "Standard_B1ms"
}

variable "postgresql_backup_retention_days" {
  type        = number
  description = "PostgreSQL backup retention period in days"
  default     = 35

  validation {
    condition     = var.postgresql_backup_retention_days >= 7 && var.postgresql_backup_retention_days <= 35
    error_message = "PostgreSQL backup retention must be between 7 and 35 days."
  }
}

variable "enable_geo_redundant_backup" {
  type        = bool
  description = "Enable geo-redundant backup for PostgreSQL"
  default     = true
}

variable "enable_advanced_security" {
  type        = bool
  description = "Enable advanced security features (Sentinel, additional monitoring)"
  default     = true
}

variable "patch_management_enabled" {
  type        = bool
  description = "Enable automated patch management"
  default     = true
}

variable "asset_management_enabled" {
  type        = bool
  description = "Enable automated asset management and documentation"
  default     = true
}

variable "compliance_frameworks" {
  type        = list(string)
  description = "Compliance frameworks to enforce"
  default     = ["OWASP-ISR", "Azure-Security-Benchmark", "CIS-Azure", "SOC2", "ISO27001"]
}

variable "tags" {
  type        = map(string)
  description = "Default tags to apply to all resources"
  default = {
    Project             = "infracodebase"
    Environment         = "dev"
    ManagedBy          = "terraform"
    Security           = "enhanced"
    ComplianceFramework = "OWASP-ISR-2024"
    AssetOwner         = "InfracodebaseTeam"
  }
}