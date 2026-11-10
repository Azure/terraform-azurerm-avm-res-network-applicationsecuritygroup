# Default example

This deploys the module in its simplest form, using an AzAPI resource group.
The `resource_id` output exposes the deployed ASG for downstream references.
The location is explicit (defaults to `eastus2`); no AzureRM-backed region
discovery is required.

`telemetry.auto.tfvars` enables telemetry, including in CI where the reusable
workflow otherwise disables it through an environment variable. The caller needs
subscription deployment read, write and delete permissions. To opt out locally,
pass `-var="enable_telemetry=false"` to Terraform plan, apply and destroy; the
checked-in variable file takes precedence over `TF_VAR_enable_telemetry`.
