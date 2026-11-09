provider "azapi" {}

data "azapi_client_config" "current" {}

resource "random_uuid" "example" {}

resource "azapi_resource" "resource_group" {
  location               = var.location
  name                   = "rg-asg-${substr(random_uuid.example.result, 0, 8)}"
  parent_id              = data.azapi_client_config.current.subscription_resource_id
  type                   = "Microsoft.Resources/resourceGroups@2025-04-01"
  response_export_values = []
}

resource "azapi_resource" "identity" {
  location               = var.location
  name                   = "id-asg-${substr(random_uuid.example.result, 0, 8)}"
  parent_id              = azapi_resource.resource_group.id
  type                   = "Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30"
  response_export_values = ["properties.principalId"]
}

module "asg" {
  source = "../../"

  location         = var.location
  name             = "asg-${substr(random_uuid.example.result, 0, 8)}"
  parent_id        = azapi_resource.resource_group.id
  enable_telemetry = var.enable_telemetry
  lock = {
    kind = "CanNotDelete"
  }
  retry = {
    error_message_regex  = ["ScopeLocked", "PrincipalNotFound"]
    interval_seconds     = 5
    max_interval_seconds = 30
  }
  role_assignments = {
    reader = {
      role_definition_id_or_name       = "reader"
      principal_id                     = azapi_resource.identity.output.properties.principalId
      skip_service_principal_aad_check = true
      description                      = "Read the example application security group."
    }
  }
  tags = {
    environment = "example"
  }
  timeouts = {
    create = "30m"
    read   = "5m"
    update = "30m"
    delete = "30m"
  }
}
