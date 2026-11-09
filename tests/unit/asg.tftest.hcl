mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example/providers/Microsoft.Network/applicationSecurityGroups/example"
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
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "random" {}

mock_provider "time" {}

variables {
  name             = "example"
  location         = "eastus2"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example"
  enable_telemetry = false
}

run "defaults_and_compatibility_outputs" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/applicationSecurityGroups@2025-01-01" && azapi_resource.this.parent_id == var.parent_id
    error_message = "The ASG must use the configured resource-group scope and stable API."
  }
  assert {
    condition     = length(keys(azapi_resource.this.body)) == 0 && length(azapi_resource.this.response_export_values) == 0
    error_message = "ASG has no writable service properties; do not replay read-only properties or associations."
  }
  assert {
    condition     = length(azapi_resource.lock) == 0 && length(azapi_resource.role_assignments) == 0 && length(azapi_resource.telemetry) == 0
    error_message = "Optional resources and opted-out telemetry must be absent."
  }
  assert {
    condition     = length(var.ignore_body_changes.network_application_security_groups) == 0 && length(var.ignore_body_changes.authorization_locks) == 0 && length(var.ignore_body_changes.authorization_role_assignments) == 0
    error_message = "Body-ignore controls must default to empty lists."
  }
  assert {
    condition     = output.application_security_group.id == output.resource_id && output.application_security_group.name == output.name && output.application_security_group.resource_group_name == "example"
    error_message = "Compatibility output fields must retain their meaning."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "interfaces_and_controls" {
  command = apply

  variables {
    tags = { environment = "test" }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = {
        role_definition_id_or_name       = "rEaDeR"
        principal_id                     = "11111111-1111-1111-1111-111111111111"
        skip_service_principal_aad_check = true
        description                      = "Read ASG"
      }
    }
    retry = {
      error_message_regex  = ["ScopeLocked"]
      interval_seconds     = 5
      max_interval_seconds = 30
    }
    timeouts = { create = "40m", read = "5m", update = "40m", delete = "40m" }
    resource_types = {
      network_application_security_groups = "Microsoft.Network/applicationSecurityGroups@2024-05-01"
    }
    ignore_body_changes = {
      authorization_role_assignments = ["properties.description"]
    }
  }

  assert {
    condition     = azapi_resource.this.tags.environment == "test" && azapi_resource.this.type == "Microsoft.Network/applicationSecurityGroups@2024-05-01"
    error_message = "Tags and API overrides must reach the ASG."
  }
  assert {
    condition     = azapi_resource.lock[0].name == "lock-CanNotDelete" && azapi_resource.lock[0].body.properties.level == "CanNotDelete" && azapi_resource.lock[0].body.properties.notes == "Cannot delete the resource or its child resources."
    error_message = "Preserve the released lock identity, ARM casing and notes."
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].body.properties.roleDefinitionId == "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7" && azapi_resource.role_assignments["reader"].body.properties.principalType == "ServicePrincipal" && azapi_resource.role_assignments["reader"].body.properties.description == "Read ASG"
    error_message = "Resolve role names case-insensitively and forward ARM properties, not invented skip-check fields."
  }
  assert {
    condition     = azapi_resource.this.retry.interval_seconds == 5 && azapi_resource.lock[0].retry.interval_seconds == 5 && azapi_resource.role_assignments["reader"].retry.interval_seconds == 5
    error_message = "Retry overrides must reach all resources."
  }
  assert {
    condition     = azapi_resource.this.timeouts.create == "40m" && azapi_resource.lock[0].timeouts.delete == "40m" && azapi_resource.role_assignments["reader"].timeouts.read == "5m"
    error_message = "Timeout overrides must reach all resources."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "explicit_lock_and_role_id" {
  command = apply

  variables {
    lock = { kind = "ReadOnly", name = "custom-lock", notes = "Custom notes" }
    role_assignments = {
      explicit = {
        name                             = "22222222-2222-2222-2222-222222222222"
        role_definition_id_or_name       = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        principal_id                     = "11111111-1111-1111-1111-111111111111"
        principal_type                   = "Group"
        skip_service_principal_aad_check = true
      }
    }
    resource_types = {
      authorization_locks            = "Microsoft.Authorization/locks@2016-09-01"
      authorization_role_assignments = "Microsoft.Authorization/roleAssignments@2020-04-01-preview"
    }
  }
  assert {
    condition     = azapi_resource.lock[0].name == "custom-lock" && azapi_resource.lock[0].body.properties.notes == "Custom notes"
    error_message = "Honor explicit lock name and notes."
  }
  assert {
    condition     = azapi_resource.role_assignments["explicit"].name == "22222222-2222-2222-2222-222222222222" && azapi_resource.role_assignments["explicit"].body.properties.principalType == "Group" && startswith(azapi_resource.role_assignments["explicit"].body.properties.roleDefinitionId, "/subscriptions/")
    error_message = "Explicit principal type wins and tenant-level role-definition IDs get the subscription prefix."
  }
  assert {
    condition     = azapi_resource.lock[0].type == var.resource_types.authorization_locks && azapi_resource.role_assignments["explicit"].type == var.resource_types.authorization_role_assignments
    error_message = "API-version overrides must reach locks and role assignments."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_name" {
  command = plan
  variables {
    name = "-invalid"
  }
  expect_failures = [var.name]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "telemetry_enabled" {
  command = apply
  variables {
    enable_telemetry = true
  }
  assert {
    condition     = length(azapi_resource.telemetry) == 1 && azapi_resource.telemetry[0].body.properties.mode == "Incremental" && length(azapi_resource.telemetry[0].body.properties.template.resources) == 0
    error_message = "Enabled telemetry must use an empty incremental deployment."
  }
  assert {
    condition     = azapi_resource.telemetry[0].parent_id == "/subscriptions/00000000-0000-0000-0000-000000000000" && azapi_resource.telemetry[0].location == var.location
    error_message = "Telemetry must use the active subscription and requested location."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "rbac_condition_and_delegation" {
  command = apply
  variables {
    role_assignments = {
      conditional = {
        role_definition_id_or_name             = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        principal_id                           = "11111111-1111-1111-1111-111111111111"
        condition                              = "test-condition"
        delegated_managed_identity_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example/providers/Microsoft.ManagedIdentity/userAssignedIdentities/example"
      }
    }
  }
  assert {
    condition     = azapi_resource.role_assignments["conditional"].body.properties.condition == "test-condition" && azapi_resource.role_assignments["conditional"].body.properties.conditionVersion == "2.0" && azapi_resource.role_assignments["conditional"].body.properties.delegatedManagedIdentityResourceId == var.role_assignments["conditional"].delegated_managed_identity_resource_id
    error_message = "Preserve AzureRM's default condition version and the ARM delegated identity mapping."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_delegated_identity" {
  command = plan
  variables {
    role_assignments = {
      invalid = {
        role_definition_id_or_name             = "Reader"
        principal_id                           = "11111111-1111-1111-1111-111111111111"
        delegated_managed_identity_resource_id = "not-an-arm-id"
      }
    }
  }
  expect_failures = [var.role_assignments]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "duplicate_role_identity" {
  command = plan
  variables {
    role_assignments = {
      first = {
        role_definition_id_or_name = "Reader"
        principal_id               = "11111111-1111-1111-1111-111111111111"
      }
      duplicate = {
        role_definition_id_or_name = "rEaDeR"
        principal_id               = "11111111-1111-1111-1111-111111111111"
      }
    }
  }
  expect_failures = [azapi_resource.role_assignments["first"], azapi_resource.role_assignments["duplicate"]]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "duplicate_assignment_names" {
  command = plan
  variables {
    role_assignments = {
      first = {
        name                       = "22222222-2222-2222-2222-222222222222"
        role_definition_id_or_name = "Reader"
        principal_id               = "11111111-1111-1111-1111-111111111111"
      }
      duplicate = {
        name                       = "22222222-2222-2222-2222-222222222222"
        role_definition_id_or_name = "Reader"
        principal_id               = "33333333-3333-3333-3333-333333333333"
      }
    }
  }
  expect_failures = [azapi_resource.role_assignments["first"], azapi_resource.role_assignments["duplicate"]]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "condition_version_without_condition" {
  command = plan
  variables {
    role_assignments = {
      invalid = {
        role_definition_id_or_name = "Reader"
        principal_id               = "11111111-1111-1111-1111-111111111111"
        condition_version          = "2.0"
      }
    }
  }
  expect_failures = [azapi_resource.role_assignments["invalid"]]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_parent" {
  command = plan
  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  }
  expect_failures = [var.parent_id]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_lock" {
  command = plan
  variables {
    lock = { kind = "Invalid" }
  }
  expect_failures = [var.lock]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "unknown_role" {
  command = plan
  variables {
    role_assignments = {
      unknown = {
        role_definition_id_or_name = "Not an assignable role"
        principal_id               = "11111111-1111-1111-1111-111111111111"
      }
    }
  }
  expect_failures = [azapi_resource.role_assignments["unknown"]]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}
