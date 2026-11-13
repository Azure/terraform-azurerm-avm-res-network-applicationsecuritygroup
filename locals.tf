locals {
  role_definition_resource_substring = "/providers/microsoft.authorization/roledefinitions/"
  subscription_id                    = provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id).subscription_id
  role_definition_ids_by_name = {
    for definition in try(data.azapi_resource_list.role_definitions[0].output.results, []) :
    lower(definition.role_name) => definition.id...
  }
  role_assignments = {
    for key, assignment in var.role_assignments : key => merge(assignment, {
      principal_type    = assignment.principal_type == null && assignment.skip_service_principal_aad_check ? "ServicePrincipal" : assignment.principal_type
      condition_version = assignment.condition != null && assignment.condition_version == null ? "2.0" : assignment.condition_version
      role_definition_id_or_name = (
        !strcontains(lower(assignment.role_definition_id_or_name), local.role_definition_resource_substring) ?
        try(local.role_definition_ids_by_name[lower(assignment.role_definition_id_or_name)][0], assignment.role_definition_id_or_name) :
        startswith(lower(assignment.role_definition_id_or_name), "/providers/") ?
        "/subscriptions/${local.subscription_id}${assignment.role_definition_id_or_name}" :
        assignment.role_definition_id_or_name
      )
    })
  }
  lock_notes = {
    CanNotDelete = "Cannot delete the resource or its child resources."
    ReadOnly     = "Cannot delete or modify the resource or its child resources."
  }
  lock = var.lock == null ? null : {
    kind  = var.lock.kind
    name  = coalesce(var.lock.name, "lock-${var.lock.kind}")
    notes = coalesce(var.lock.notes, lookup(local.lock_notes, var.lock.kind, ""))
  }
}
