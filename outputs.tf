output "application_security_group" {
  description = "Compatibility projection of the application security group: id, name, location, resource_group_name and tags. This is not a provider resource object."
  value = {
    id                  = azapi_resource.this.id
    name                = azapi_resource.this.name
    location            = azapi_resource.this.location
    resource_group_name = provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id).resource_group_name
    tags                = azapi_resource.this.tags
  }
}

output "name" {
  description = "The name of the application security group."
  value       = azapi_resource.this.name
}

output "resource_id" {
  description = "The Azure resource id of the application security group."
  value       = azapi_resource.this.id
}
