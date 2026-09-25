output "resource_group_name" {
  description = "Name of the created resource group."
  value       = azurerm_resource_group.this.name
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the SQL server."
  value       = azurerm_mssql_server.this.fully_qualified_domain_name
}

output "database_name" {
  description = "Name of the SQL database."
  value       = azurerm_mssql_database.this.name
}

output "connection_string" {
  description = "ADO.NET connection string (password omitted — pull it from Key Vault at runtime)."
  value       = "Server=tcp:${azurerm_mssql_server.this.fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.this.name};User ID=${var.sql_admin_login};Encrypt=true;TrustServerCertificate=false;"
  sensitive   = true
}
