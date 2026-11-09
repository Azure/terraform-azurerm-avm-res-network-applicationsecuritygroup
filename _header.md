# Terraform Azure Application Security Group Module

This Terraform module is designed to create Application Security Groups. 

> [!WARNING]
> Major version Zero (0.y.z) is for initial development. Anything MAY change at any time. A module SHOULD NOT be considered stable till at least it is major version one (1.0.0) or greater. Changes will always be via new versions being published and no changes will be made to existing published versions. For more details please go to <https://semver.org/>

## Features

* Create an application security group with its various configuration options such as location, tags and name.

## Limitations

* Network security rules and NIC/private-endpoint ASG memberships belong to their respective resource owners, not to this module. This module does not write those resources.

## AzAPI implementation and compatibility

The module uses `Azure/azapi ~> 2.12` for the application security group and its optional locks and role assignments. Terraform 1.11 or later is required. Configure AzAPI with the intended subscription and authentication; an AzureRM provider alias does not configure AzAPI.

Supply the existing resource group's full ARM ID as `parent_id`; the former `resource_group_name` input is no longer accepted. Name, location and parent changes replace the ASG. Tags remain mutable.

`resource_id` remains the ASG ARM ID. The `application_security_group` output is now an explicit compatibility object containing `id`, `name`, `location`, `resource_group_name` and `tags`, rather than the entire AzureRM provider object. Provider-only attributes such as `timeouts` are not preserved. Use `name` and `resource_id` for new consumers.

Role names are resolved case-insensitively at the existing resource-group scope. Role assignment descriptions, previously accepted but not forwarded, are now sent to Azure. `skip_service_principal_aad_check = true` supplies `principalType = "ServicePrincipal"` when no explicit principal type is given. Existing assignment GUIDs are retained by the migration; immutable input changes request replacement. Do not specify conflicting assignment names or duplicate principal/role pairs.

The lock's default name and notes are preserved. A 30-second removal barrier orders full teardown after lock removal; it is not an update-time unlock or a guarantee of Azure propagation. Remove a ReadOnly lock in a separate approved apply before updates. Selective RBAC replacement under an unchanged CanNotDelete lock also requires staged unlock/relock.

Telemetry remains enabled by default and uses the managed subscription-scoped empty deployment introduced in v0.2.0. The interfaces utility also reports its own deployment when enabled. Both need subscription deployment read/write/delete permissions. Set `enable_telemetry = false` to opt out of both. Their template apply timestamps intentionally change on normal plans; do not discount other infrastructure drift. The authored AzAPI controls apply to ASG, RBAC and lock resources; governance-managed telemetry currently uses fixed generated settings.

See [UPGRADE.md](UPGRADE.md) for the module-owned state path and its current verification limits.
