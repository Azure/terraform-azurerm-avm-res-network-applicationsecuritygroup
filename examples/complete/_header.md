# Complete example

Creates an application security group with tags, a CanNotDelete lock, a Reader
assignment to a test user-assigned identity, retry and timeout overrides. All
supporting Azure resources use AzAPI.

The caller needs resource-group creation, identity creation, ASG, RBAC and lock
permissions, plus subscription deployment permissions when telemetry is enabled.
`telemetry.auto.tfvars` enables telemetry, including in CI where the reusable
workflow otherwise disables it through an environment variable. To opt out
locally, pass `-var="enable_telemetry=false"` to Terraform plan, apply and destroy;
the checked-in variable file takes precedence over `TF_VAR_enable_telemetry`.
This example has not been deployed for the initial local refactor candidate.

The lock removal barrier applies to full teardown only. Before selectively
replacing the role assignment, remove the lock in a separate approved apply,
perform the replacement, then restore the lock.
