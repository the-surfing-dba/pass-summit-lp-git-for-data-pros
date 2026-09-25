# =============================================================================
#  Demo Terraform: an Azure SQL Database.
#
#  Session use:
#    - Change something here in a `feature/` branch (e.g. sku_name or a
#      firewall rule), open a PR, and let the `terraform-validate` CI job run.
#    - Great example of a "high blast radius" change that CODEOWNERS +
#      branch protection should force a review on before merge.
#
#  NOTE: `terraform validate` (what CI runs) needs NO Azure credentials.
#        `terraform apply` would — and the admin password comes from an
#        environment variable, never from a committed .tfvars file.
# =============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.project}-${var.environment}"
  location = var.location

  tags = local.tags
}

resource "azurerm_mssql_server" "this" {
  name                         = "sql-${var.project}-${var.environment}"
  resource_group_name          = azurerm_resource_group.this.name
  location                     = azurerm_resource_group.this.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password # sensitive; sourced from TF_VAR_sql_admin_password
  minimum_tls_version          = "1.2"

  tags = local.tags
}

resource "azurerm_mssql_database" "this" {
  name        = var.database_name
  server_id   = azurerm_mssql_server.this.id
  sku_name    = var.sku_name
  max_size_gb = var.max_size_gb
  collation   = "SQL_Latin1_General_CP1_CI_AS"

  # Keep demo costs down; no long-term backup retention.
  storage_account_type = "Local"

  tags = local.tags
}

# Allow Azure services (and, for the demo, your current IP via a var) to reach it.
resource "azurerm_mssql_firewall_rule" "client" {
  name             = "allow-client-ip"
  server_id        = azurerm_mssql_server.this.id
  start_ip_address = var.client_ip_address
  end_ip_address   = var.client_ip_address
}

locals {
  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
    demo        = "pass-data-summit"
  }
}
