variable "project" {
  description = "Short project/app name used in resource names."
  type        = string
  default     = "passdemo"
}

variable "environment" {
  description = "Deployment environment (dev/test/prod). Drives naming and tags."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus2"
}

variable "sql_admin_login" {
  description = "SQL Server administrator login name."
  type        = string
  default     = "sqladmin"
}

variable "sql_admin_password" {
  description = "SQL admin password. NEVER hardcode — set via TF_VAR_sql_admin_password or Key Vault."
  type        = string
  sensitive   = true
}

variable "database_name" {
  description = "Name of the SQL database to create."
  type        = string
  default     = "YoMomma"
}

variable "sku_name" {
  description = "Database SKU (e.g. Basic, S0, GP_S_Gen5_1). Change this in a branch for the PR demo."
  type        = string
  default     = "Basic"
}

variable "max_size_gb" {
  description = "Max database size in GB."
  type        = number
  default     = 2
}

variable "client_ip_address" {
  description = "Public IP allowed through the SQL firewall for the demo."
  type        = string
  default     = "0.0.0.0"
}
