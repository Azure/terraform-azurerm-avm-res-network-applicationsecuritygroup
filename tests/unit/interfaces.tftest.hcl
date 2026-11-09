mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example/providers/Microsoft.Network/applicationSecurityGroups/example"
    }
  }
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [{
          id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
          role_name = "Reader"
        }]
      }
    }
  }
}

mock_provider "random" {}

mock_provider "time" {}

run "interfaces" {
  command = apply

  variables {
    name             = "example"
    location         = "eastus2"
    parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example"
    enable_telemetry = false
    lock = {
      kind  = "CanNotDelete"
      name  = "asg-protection"
      notes = "Protect the example ASG and its role assignment from accidental deletion."
    }
    role_assignments = {
      reader = {
        name                       = "22222222-2222-2222-2222-222222222222"
        role_definition_id_or_name = "Reader"
        principal_id               = "11111111-1111-1111-1111-111111111111"
        principal_type             = "ServicePrincipal"
        description                = "Read the example application security group."
      }
    }
    tags = {
      environment = "example"
      scenario    = "interfaces"
    }
  }

  assert {
    condition     = output.application_security_group.tags.scenario == "interfaces"
    error_message = "The interface scenario tags must reach the ASG."
  }
  assert {
    condition     = azapi_resource.lock[0].name == var.lock.name && azapi_resource.lock[0].body.properties.level == "CanNotDelete" && azapi_resource.lock[0].body.properties.notes == var.lock.notes
    error_message = "The custom lock name and notes must be honored with CanNotDelete protection."
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].name == var.role_assignments.reader.name && azapi_resource.role_assignments["reader"].body.properties.principalType == "ServicePrincipal" && azapi_resource.role_assignments["reader"].body.properties.description == var.role_assignments.reader.description
    error_message = "The explicit assignment GUID, principal type and description must be forwarded together."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}
