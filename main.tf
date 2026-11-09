resource "azapi_resource" "this" {
  location               = var.location
  name                   = var.name
  parent_id              = var.parent_id
  type                   = var.resource_types.network_application_security_groups
  body                   = {}
  ignore_body_changes    = length(var.ignore_body_changes.network_application_security_groups) > 0 ? var.ignore_body_changes.network_application_security_groups : null
  response_export_values = []
  retry                  = var.retry
  tags                   = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}

module "avm_interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.10.0"

  enable_telemetry                          = var.enable_telemetry
  location                                  = var.location
  lock                                      = local.lock
  role_assignment_definition_lookup_enabled = false
  role_assignments                          = local.role_assignments
}

data "azapi_resource_list" "role_definitions" {
  count = anytrue([for assignment in var.role_assignments : !strcontains(lower(assignment.role_definition_id_or_name), local.role_definition_resource_substring)]) ? 1 : 0

  parent_id = var.parent_id
  type      = "Microsoft.Authorization/roleDefinitions@2022-04-01"
  response_export_values = {
    results = "value[].{id: id, role_name: properties.roleName}"
  }
}

resource "azapi_resource" "role_assignments" {
  for_each = var.role_assignments

  name                 = module.avm_interfaces.role_assignments_azapi[each.key].name
  parent_id            = azapi_resource.this.id
  type                 = var.resource_types.authorization_role_assignments
  body                 = module.avm_interfaces.role_assignments_azapi[each.key].body
  ignore_body_changes  = length(var.ignore_body_changes.authorization_role_assignments) > 0 ? var.ignore_body_changes.authorization_role_assignments : null
  ignore_casing        = true
  ignore_null_property = true
  replace_triggers_external_values = {
    name                                   = each.value.name
    principal_id                           = lower(each.value.principal_id)
    role_definition_id_or_name             = lower(each.value.role_definition_id_or_name)
    principal_type                         = local.role_assignments[each.key].principal_type
    condition                              = each.value.condition
    condition_version                      = each.value.condition_version
    delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
    description                            = each.value.description
  }
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  lifecycle {
    # AzureRM generated the original GUID. Keep it when the state is moved.
    ignore_changes = [name]
    precondition {
      condition     = strcontains(lower(local.role_assignments[each.key].role_definition_id_or_name), local.role_definition_resource_substring)
      error_message = "The role definition was not found at the parent scope. Supply an assignable role name or a fully-qualified role definition ID."
    }
    precondition {
      condition = length(distinct([
        for assignment in values(local.role_assignments) :
        lower("${assignment.principal_id}|${assignment.role_definition_id_or_name}")
      ])) == length(local.role_assignments)
      error_message = "Each principal and role definition pair must be unique at the application security group scope."
    }
    precondition {
      condition = length(distinct([
        for assignment in values(var.role_assignments) : lower(assignment.name) if assignment.name != null
        ])) == length([
        for assignment in values(var.role_assignments) : assignment.name if assignment.name != null
      ])
      error_message = "Explicit role assignment names must be unique at the application security group scope."
    }
    precondition {
      condition     = each.value.condition_version == null || each.value.condition != null
      error_message = "condition_version must not be set without condition."
    }
  }
}

resource "azapi_resource" "lock" {
  count = var.lock != null ? 1 : 0

  name                = module.avm_interfaces.lock_azapi.name
  parent_id           = azapi_resource.this.id
  type                = var.resource_types.authorization_locks
  body                = module.avm_interfaces.lock_azapi.body
  ignore_body_changes = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  replace_triggers_external_values = {
    kind  = var.lock.kind
    notes = local.lock.notes
  }
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  depends_on = [time_sleep.lock_removal]
}

resource "time_sleep" "lock_removal" {
  count = var.lock != null ? 1 : 0

  destroy_duration = "30s"
  triggers = {
    resource_id = azapi_resource.this.id
  }

  depends_on = [azapi_resource.this, azapi_resource.role_assignments]
}

moved {
  from = azurerm_application_security_group.this
  to   = azapi_resource.this
}

moved {
  from = azurerm_management_lock.this
  to   = azapi_resource.lock
}

moved {
  from = azurerm_role_assignment.this
  to   = azapi_resource.role_assignments
}
