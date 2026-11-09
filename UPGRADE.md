# Upgrading from v0.2.0 to the AzAPI candidate

> This is an unreleased local candidate. Fresh deployment and the standard
> v0.2.0 existing-state upgrade were verified in an isolated Azure test scope
> on 2026-11-05, with telemetry disabled. This scoped result is not release
> readiness or proof of the exceptional paths listed below.

## Verification status

The tested, uncommitted source snapshot has SHA256 manifest fingerprint
`1573739bb273a25c7e3b4bc49cdad6477962d87da41aa8fad99ab335864cfa26`.
Verification used Terraform 1.16.5, AzAPI 2.13.0, AzureRM 4.74.0 for the
released baseline, and interfaces utility 0.10.0, in westus2. The minimum
supported Terraform/AzAPI versions were not separately exercised.

A nested consumer successfully applied released v0.2.0, then upgraded the
same state to the exact candidate using the three module-owned moves.
The inspected upgrade plan had two local utility/delay additions and three
in-place updates, with no replacements, deletes or imports. ASG ARM ID,
original role-assignment GUID and lock name/notes were preserved. Azure did
not return the ASG's service-generated `resourceGuid`, so preservation of
that separate property is not independently proven.

Both fresh and upgraded fixtures passed independent Azure readbacks, two
immediate refreshed no-change plans, tag mutation/clearing/restoration, and
staged unlock, Reader removal/re-addition and relock. Normal Terraform
teardown passed with locks configured; final states were empty and exact
test objects independently absent. These were standalone saved-plan
fixtures using the managed-resolved Terraform binary, not executions of
the repository's runnable examples or a managed `avm test e2e` pass.

Enabled telemetry, older baselines, deliberate ASG replacement, immutable
RBAC replacement under an unchanged lock, ReadOnly, cross-tenant/delegated
or conditional assignments, external NIC/private-endpoint memberships,
non-default API versions and nonempty ignored body paths remain unverified
in Azure. Clean-commit `avm pr-check` passed for commit `82407cf` on
2026-11-09, along with `avm pre-commit` and 14 mocked tests. Subsequent
publication candidates require fresh affected checks; remote CI is separate.

## Prerequisites and input changes

- The supported starting point for verification is released **v0.2.0**,
  commit `41bc4aad258186777a12badc2b1125b2743c95a9`.
  Direct upgrades from older releases are not verified.
- Use Terraform `>= 1.11, < 2.0`, AzAPI `~> 2.12`, and the candidate's
  `Azure/avm-utl-interfaces/azure` dependency `0.10.0`.
- Replace `resource_group_name` with `parent_id`, using the full ID of the
  **same** existing resource group. Keep the ASG name and location unchanged.
- Configure and pass the correct AzAPI provider, including aliases. Keep the
  old AzureRM provider configuration and plugin available while state still
  refers to AzureRM; remove it from the consumer only after conversion.
- Back up state in protected storage. Keep saved plans and readbacks outside
  this repository. Do not use this guide as authorization to deploy.

## Module-owned state path

The module contains these declarative moves; they are relative to each instance
of the module, including a consumer's `module.asg["key"]` boundary:

| Released address | Candidate address |
| --- | --- |
| `azurerm_application_security_group.this` | `azapi_resource.this` |
| `azurerm_management_lock.this[0]` | `azapi_resource.lock[0]` |
| `azurerm_role_assignment.this["key"]` | `azapi_resource.role_assignments["key"]` |

AzAPI 2.12's `azapi_resource` state mover accepts AzureRM source types and derives
the ARM identity from their state IDs. Resource and collection boundaries stay
unchanged. No consumer import, migration flag or routine imperative state edit is
required by this standard path. Actual conversion was verified with the
resolved versions and scope above; this does not prove every provider version
or exceptional AzureRM state-ID format.

The assignment `name` lifecycle ignore preserves AzureRM-generated GUIDs instead
of replacing them with utility-generated GUIDs. Input-based replacement triggers
still cover immutable assignment changes, including an explicit name change.
The initial adopted-state plan and two refreshed no-ops passed without
replacing the existing assignment. Immutable replacement under an unchanged
lock remains unverified; staged unlock/relock was tested separately.

Cross-tenant AzureRM role assignment state IDs with a `|tenant` suffix are not
covered by this standard-path claim. Stop and obtain a separately reviewed,
GUID-preserving adoption procedure if the provider cannot convert such an ID.
Do not strip suffixes or remove state indiscriminately.

## Required verification before use

In an explicitly approved isolated subscription and scope:

1. Successfully apply released v0.2.0 under a realistic nested consumer, with
   tags, representative RBAC and a lock. Capture IDs, assignment GUIDs, lock
   names/notes, outputs, state addresses and a normal refreshed baseline plan.
2. Switch the **same backend/workspace/state** to an immutable candidate.
   For a local source remove the registry `version`. Make only the documented
   input/provider changes and initialize dependencies.
3. Save and inspect the migration plan. Expect moves of the existing objects,
   utility UUID state and (when locked) a new local delay resource, not new ASGs
   or duplicate assignments. With telemetry enabled, the newly composed utility
   adds its own subscription telemetry deployment and local telemetry state.
   Explain updates individually, including description forwarding and narrow
   telemetry timestamp changes.
4. Stop on unintended replacement/deletion, changed IDs/GUIDs, unresolved role
   names or lost relationships. Apply only the inspected saved plan.
5. Independently read Azure identities, lock properties and role assignments.
   Require normal refreshed convergence; isolate only the documented telemetry
   timestamp at `azapi_resource.telemetry[*].body.properties.template.outputs.apply_id`
   and the same resource/path under `module.avm_interfaces`.
   Test telemetry disabled and enabled separately.
6. Exercise tag edits/clearing and role add/remove/immutable changes. Prove an
   unchanged ASG preserves externally owned NIC/private-endpoint memberships.
   Test full destroy, deliberate ASG replacement, selective RBAC replacement
   under locks and ReadOnly handling as separate cases.
7. Destroy only test-created objects through the migrated implementation and
   verify empty final state and independent absence. A lock-removal delay is not
   proof of successful cleanup. Do not use broad resource-group deletion as a
   substitute for a failed module destroy.

The scoped fresh-deployment and independent released-state results above
do not replace this risk-based sequence for untested scenarios or a changed
candidate. Local mocked tests alone do not prove these Azure behaviors.

## Output and behavior changes

`resource_id` is retained. `application_security_group` preserves the AzureRM
object's useful fields (`id`, `name`, `location`, `resource_group_name`, `tags`)
as an explicit object, not its provider-internal schema. Consumers of
`application_security_group.timeouts` must change. Empty-tag clearing and
westus2 output convergence were verified; broader null/default and location
normalization cases are not established by that scoped result.

Locks gain optional `notes`. RBAC gains optional explicit `name`. Descriptions
are now forwarded rather than silently ignored. The skip-AAD-check switch maps
to service-principal type only when no explicit type is provided.

`resource_types`, `retry`, `timeouts` and per-resource `ignore_body_changes`
control authored ASG, lock and RBAC requests. Governance-managed telemetry in
this module and the interfaces utility currently has fixed generated settings;
the candidate does not expose no-op telemetry override fields. This is a
current specification/tooling discrepancy requiring review, not a claim of
full TFFR6-8 compliance. Ignored body paths are not sent to Azure; changing the
ignore list takes effect only after apply.

## Rollback limitations

Do not assume reverting HCL can reverse a cross-provider state move. A return to
AzureRM may require a separately inspected re-import/state recovery procedure
and cannot undo changes already made in Azure. State restoration is not a
proven rollback. Preserve protected backups and do not resume competing writers.
