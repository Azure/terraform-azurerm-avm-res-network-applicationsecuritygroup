output "application_security_group" {
  description = "The Azure resource of the application security group."
  value       = azurerm_application_security_group.this
}

output "resource_id" {
  description = "The Azure resource id of the application security group."
  value       = azurerm_application_security_group.this.id
}
