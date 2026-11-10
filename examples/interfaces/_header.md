# Interfaces example

Creates an application security group with tags, a custom-named CanNotDelete
lock with notes, and a Reader role assignment to a test user-assigned identity.
The assignment uses an explicit ServicePrincipal principal type and a
caller-generated GUID persisted by `random_uuid`. Retry and timeout overrides
are also supplied. All supporting Azure resources use AzAPI.

The identity is an RBAC recipient; this does not attach a managed identity to
the application security group.

The caller needs resource-group creation, identity creation, ASG, RBAC and lock
permissions, plus subscription deployment permissions when telemetry is enabled.
`telemetry.auto.tfvars` enables telemetry, including in CI where the reusable
workflow otherwise disables it through an environment variable. To opt out
locally, pass `-var="enable_telemetry=false"` to Terraform plan, apply and destroy;
the checked-in variable file takes precedence over `TF_VAR_enable_telemetry`.

Keep the assignment UUID in Terraform state; replacing it requests replacement
of the role assignment. Before selectively replacing an assignment, remove the
lock in a separate approved apply, perform the replacement, then restore the
lock. The module orders lock removal during full teardown, but that is not proof
of successful Azure cleanup.

ReadOnly locks, conditional/delegated RBAC, API-version overrides and ignored
body paths are deliberately not demonstrated by this runnable example.
No Azure deployment or cleanup has been verified for this example.
