# Upgrading from v0.2.0 to the AzAPI candidate

> This is an unreleased candidate. Fresh deployment and the standard
> v0.2.0 existing-state upgrade were verified in an isolated Azure test scope
> on 2026-11-05, with telemetry disabled. Additional NIC-membership and
> lock/replacement cases were verified against the exact published candidate
> on 2026-11-10, as detailed below. These scoped results are not release readiness.

## Verification status

The tested, uncommitted source snapshot has SHA256 manifest fingerprint
`1573739bb273a25c7e3b4bc49cdad6477962d87da41aa8fad99ab335864cfa26`.
Verification used Terraform 1.16.5, AzAPI 2.13.0, AzureRM 4.74.0 for the
released baseline, and interfaces utility 0.10.0, in westus2. That Azure
run did not exercise the minimum supported Terraform/AzAPI versions;
the separate local minimum-version results are recorded below.

A nested consumer successfully applied released v0.2.0, then upgraded the
same state to the exact candidate using the three module-owned moves.
The inspected upgrade plan had two local utility/delay additions and three
in-place updates, with no replacements, deletes or imports. ASG ARM ID,
original role-assignment GUID and lock name/notes were preserved. The released
module did not expose an ASG `resourceGuid`; it is not a compatibility
requirement or migration-readiness gate.

Both fresh and upgraded fixtures passed independent Azure readbacks, two
immediate refreshed no-change plans, tag mutation/clearing/restoration, and
staged unlock, Reader removal/re-addition and relock. Normal Terraform
teardown passed with locks configured; final states were empty and exact
test objects independently absent. These were standalone saved-plan
fixtures using the managed-resolved Terraform binary, not executions of
the repository's runnable examples or a managed `avm test e2e` pass.

At the time of that historical run, deliberate replacement, unchanged-lock
RBAC replacement, ReadOnly and external NIC memberships were unverified;
the separate 2026-11-10 results below supersede those coverage gaps.
Enabled telemetry, older baselines, cross-tenant/delegated or conditional
assignments, private-endpoint memberships,
non-default API versions for managed writes and nonempty ignored body paths remain unverified
in Azure. Clean-commit `avm pr-check` passed for commit `82407cf` on
2026-11-09, along with `avm pre-commit` and 14 mocked tests. Subsequent
publication candidates require fresh affected checks; remote CI is separate.

## NIC-membership and lock/replacement verification

On 2026-11-10, two separate MCAPS fixtures successfully applied released
ASG **v0.2.0**, then upgraded their existing state to exact candidate commit
`614e342bfa170983c63c8fe2860dc556d521d7dc`. The membership fixture also used
released NIC **v0.2.0** and VNet **v0.23.0**, including that release's subnet
submodule. Those supporting sources and provider locks were unchanged during
the ASG migration. Both fixtures used Terraform 1.16.5, AzAPI 2.13.0,
AzureRM 4.74.0, random 3.9.1 and time 0.14.2, with telemetry disabled.
These were saved-plan fixtures using the managed-resolved binary, not a
managed E2E run or minimum-version Azure proof.

| Case | Observed result |
| --- | --- |
| Released ASG/NIC/VNet composition and ASG migration | Passed: one ASG state move/in-place update; NIC, association, subnet and VNet remained no-op |
| ASG tag mutation, clearing and restoration | Passed: actual PUTs and independent readbacks preserved the exact NIC membership list and all infrastructure IDs |
| Released ASG/lock/Reader migration | Passed: three state moves/in-place updates, two local additions, no deletes/replacements/imports; original assignment GUID and lock identity preserved |
| Deliberate ASG name replacement with CanNotDelete and Reader configured | Passed: actual lock deletion, 30.003-second destroy barrier, old Reader/ASG deletion, new ASG/Reader creation, then relock |
| Role-only immutable description replacement with unchanged CanNotDelete | Expected failure: Azure rejected role deletion with HTTP 409 `ScopeLocked`; unchanged identities independently confirmed |
| Separately staged unlock, role replacement and relock | Recovered successfully; this does not make the original locked replacement a pass |
| ASG tag update with unchanged ReadOnly lock | Expected failure: Azure rejected the PUT with HTTP 409 `ScopeLocked`; blocked tag remained absent |
| Separately staged unlock, tag update and ReadOnly relock | Recovered successfully |
| Ordinary full destroy starting with ReadOnly and Reader configured | Passed: lock deletion, 30.003-second barrier, protected teardown; no preliminary manual unlock |

The NIC module retained ownership of
`ipConfigurations[].properties.applicationSecurityGroups`; no second writer
or ASG-owned membership configuration was introduced. Independent GETs
confirmed the exact one-ASG membership after migration and every parent tag
write. NIC `resourceGuid` was preserved. Tag clearing omitted `tags` from the actual ASG PUT, and an
independent GET confirmed clearing rather than inferring it from the request.

Two ordinary refreshed no-op plans followed migration and each tag-write
case, as well as parent replacement and both staged recoveries. The released
NIC baseline initially needed an inspected zero-action apply to persist
refresh-only `dns_servers`/`tags` normalization; that original strict
assertion failure and recovery were retained separately. No supporting
configuration changes or infrastructure drift were hidden.

On deliberate parent replacement, the lock name stayed unchanged but its
full ARM ID changed with the parent scope. The replacement role used the
utility's persisted UUID; preservation of the released role GUID applies to
the nondestructive migration, not creation at a different ASG scope.
The replacement fixture did not include the NIC, so it does not prove
membership retargeting during deliberate ASG replacement.

Both fixtures completed normal Terraform teardown and had empty final
states. Independent final GETs returned HTTP 404 for all nine recorded test
resource IDs; the existing resource group was preserved. No VM, public IP,
registration change or live test infrastructure remained. Failed locked
operations and their newly inspected staged recoveries are separate outcomes,
not automatic update-time unlocking.

This coverage is one NIC/one ASG IPv4 membership. It does not establish
multi-member mutation, cross-state handoff, private-endpoint membership,
enabled telemetry, minimum-version Azure behavior or rollback.

## Supplemental ASG GUID API-version investigation

Released v0.2.0 exposes `application_security_group` (the AzureRM resource
object) and `resource_id` (the ARM ID), not an ASG service GUID. The tested
AzureRM 4.74.0 resource schema and read/flatten implementation do not expose
or persist `resourceGuid`; both retained released-baseline states confirm
its absence. This investigation sought an extra identity signal, not a
released output or feature. It is not an outstanding compatibility issue
or release blocker.

On 2026-11-10, a separately approved temporary ASG was created in westus2
using API `2025-01-01`. After provisioning succeeded, both the resource GET
and resource-group list endpoints were queried for all **63 API versions**
advertised for `Microsoft.Network/applicationSecurityGroups` in the test
subscription, from `2017-09-01` through `2026-07-01`.

All **126 requests returned HTTP 200**, and each list contained the exact
test ASG. None returned `properties.resourceGuid`; resource GETs also had
no top-level `resourceGuid`. Representative published schemas, including
`2017-09-01`, `2025-01-01` and `2026-03-01`, declare this property read-only,
but that declaration did not match the observed service responses.
See the [2025-01-01 schema](https://github.com/Azure/azure-rest-api-specs/blob/e4d2d2ae2c8f429796350ca6b443159a8991ca42/specification/network/resource-manager/Microsoft.Network/Network/stable/2025-01-01/applicationSecurityGroup.json).

No tested API version supplied a GUID for this fresh ASG. This is not a
claim that every ASG in every environment omits it, nor proof of GUID
preservation during migration. An extra AzAPI lookup against the tested
endpoints would not recover the absent field, so the module API version
and resource implementation were not changed. The temporary ASG was deleted;
an exact GET returned HTTP 404 and the existing resource group remained
HTTP 200. No NIC, lock, role assignment or telemetry deployment was created.

## Minimum-version verification

On 2026-11-10, isolated source copies of commit
`614e342bfa170983c63c8fe2860dc556d521d7dc` were tested using
Avm.Authoring 0.41.2. Exact provider constraints were applied only in those
fixtures; the module's published constraints were not changed. All entries
used interfaces 0.10.0, random 3.9.1 and time 0.13.0.

| Terraform | AzAPI | Initialization and validation | Unmodified mocked suite |
| --- | --- | --- | --- |
| 1.11.0 | 2.12.0 | Passed | Failed: 2 passed, 1 failed, 11 skipped |
| 1.11.0 | 2.13.0 | Passed | Failed: same write-only mock error |
| 1.11.4 | 2.12.0 | Passed | All 14 passed |
| 1.16.5 | 2.12.0 | Passed | All 14 passed |

The failing run supplies nonempty `ignore_body_changes`. Terraform's mock
provider incorrectly returns that write-only input in its planned value.
This is the confirmed Terraform defect
[hashicorp/terraform#36819](https://github.com/hashicorp/terraform/issues/36819),
fixed in
[Terraform 1.11.4](https://github.com/hashicorp/terraform/blob/v1.11.4/CHANGELOG.md).
The failure was retained, not skipped or suppressed. Contributors should
use Terraform 1.11.4 or later for this mocked suite; the runtime constraint
remains `>= 1.11, < 2.0`.

A separate **real-provider, offline plan** passed with Terraform 1.11.0 and
AzAPI 2.12.0, including ASG, lock, RBAC, retry/timeouts and nonempty
lock/RBAC body-ignore paths. It planned five creations, with no deletions
or imports. Telemetry and refresh were disabled, credentials were dummy
values, and outbound provider access was blocked. This proves configuration
and planning compatibility, not Azure persistence, apply-time body-ignore
behavior or released-state conversion at the minimum versions. The existing
live proof retains its original, newer toolchain attribution.

## Telemetry ownership

The current [SFR3](https://azure.github.io/Azure-Verified-Modules/spec/SFR3/)
requires `Avm.Authoring` to generate and maintain the root telemetry
deployment. [SFR4](https://azure.github.io/Azure-Verified-Modules/spec/SFR4/)
requires forwarding the consumer's opt-out to instrumented dependencies.
This module forwards both `enable_telemetry` and `location` to interfaces
0.10.0; it does not own the dependency's telemetry resources.

| Surface | Implementation owner | Current consumer control |
| --- | --- | --- |
| `azapi_resource.telemetry` | `Azure/azure-verified-modules-tools`, through the managed generator | Root `enable_telemetry` and `location` |
| `module.avm_interfaces.azapi_resource.telemetry` | `Azure/terraform-azure-avm-utl-interfaces`, pinned at 0.10.0 | The same toggle and location, forwarded by this module |
| ASG, lock and RBAC | This module | Authored `resource_types`, `retry`, `timeouts` and per-resource `ignore_body_changes` |

Full mocked resource trees confirmed two distinct subscription telemetry
deployments when enabled, and no telemetry deployments or local telemetry
identities in either scope when disabled. This is mocked ownership/opt-out
evidence, not enabled-telemetry Azure proof.

The runnable `default`, `complete` and `interfaces` examples now include
`telemetry.auto.tfvars` with `enable_telemetry = true`. This overrides the
pinned reusable CI workflow's `TF_VAR_enable_telemetry=false` environment
default without changing managed workflow files or the module's opt-out.
The managed E2E runner distinguishes generated telemetry updates from
infrastructure drift. CI needs subscription deployment read/write/delete
permissions; a future CI execution, not this configuration change, must prove
the enabled deployment and cleanup. For a local opt-out, supply
`-var="enable_telemetry=false"` to Terraform plan, apply and destroy.

The generator shipped with Avm.Authoring 0.41.2 and interfaces 0.10.0 still
fix the deployment type to `Microsoft.Resources/deployments@2025-04-01` and
provide no consumer retry, timeout or body-ignore wiring. The utility exposes
none of those input variables. The current TFFR6-8 text covers directly
declared AzAPI resources and has no explicit telemetry exemption; SFR3
simultaneously prescribes the generated telemetry implementation.

Avm.Authoring 0.41.2 supports replacement Mapotf profiles under
`config/mapotf/<profile>` or `AVM_MPTF_CONFIG_DIR`. Thus generator-managed
controls are technically possible without hand-editing `main.telemetry.tf`.
Profiles replace, rather than extend, the selected bundled profile: a local
replacement must preserve its other transforms and migration behavior.
This mechanism cannot modify an installed dependency's implementation and
does not authorize an exception to SFR3's prescribed API.

The minimum prerequisite design is:

1. **Specification reconciliation:** make SFR3's
   `Microsoft.Resources/deployments@2025-04-01` the required default, with
   explicit permission for the TFFR6 consumer override. Reconcile TFFR8
   with the mandatory empty-template and per-plan write behavior: ignored
   paths must not disable `outputs.apply_id` or its ancestors. This is a
   proposed specification change, not an already approved interpretation.
   An explicit centrally approved telemetry exception is an alternative,
   not a local waiver this module can assume.
2. **Generator:** in all three telemetry creation/update forms, read
   `var.resource_types.resources_deployments`, assign `retry = var.retry`,
   generate dynamic timeouts and collapse the telemetry-specific
   `ignore_body_changes.resources_deployments` empty list to `null`.
   Generate or merge the canonical variable fields without replacing
   existing resource/submodule fields. Preserve addresses, identity,
   metadata-backed names, opt-out, scope, location and migration blocks.
   The update transform needs `match_nested_block_labels = true`;
   otherwise repeated generation appends duplicate dynamic timeout blocks.
3. **Interfaces utility:** its only Azure managed resource is telemetry;
   local role-assignment UUIDs and Azure data sources do not justify adding
   a telemetry deployment under SFR3's resource-free utility rule. Publish
   a telemetry-free release: remove instrumentation, its client lookup and
   telemetry-only locals; stop selecting the root telemetry profile by
   removing the active metadata telemetry prefix through the metadata
   review process. Keep role-assignment UUID resources and outputs intact.
   Do not add four unused AzAPI control inputs to a resource-free utility.
   Removing its telemetry-only `location` and `enable_telemetry` inputs
   requires explicit breaking-change guidance and caller updates.
4. **Utility state transition:** use module-owned `removed` blocks for
   `azapi_resource.telemetry` and `terraform_data.telemetry`, each with
   `lifecycle { destroy = false }`. These forget state
   bindings; they do not delete the existing Azure deployment history or
   transfer it to this module. Retained history needs an explicit retention
   owner and separately approved cleanup, not a claim of empty Azure state.
   Keep any legacy ModTM/telemetry UUID forget blocks needed by supported
   baselines. Do not move utility telemetry into the root: the two existing
   deployments have distinct reporting identities.
5. **ASG adoption:** consume the exact released utility fix and updated
   generator only after review; remove the now-unsupported utility call
   arguments, while keeping root telemetry enabled by default. Root
   deployment API/body-ignore fields must be real wired controls, not
   placeholders. No speculative release number or dependency bump is made.

A separate, mock-only prerequisite fixture verified generator-managed
default behavior, non-default type/retry/all four timeouts, stable local
telemetry identity/name across control changes, and opt-out (three passing
runs). Regeneration with the corrected profile passed drift checking.
Generated source inspection, not mocked state, establishes write-only
body-ignore wiring; provider persistence remains unproved. The experimental
API override requires the specification change above and is **not** installed
in this module. The existing ASG suite also passed all 14 mocked runs.

Before adoption, upstream acceptance must cover fresh and existing generated
files (including the additional-content form), variable-field preservation,
repeated transform/format drift, and real provider serialization/refresh.
The utility needs a released-0.10.0 same-state upgrade proving telemetry is
forgotten rather than destroyed, role UUIDs and interface outputs survive,
and fresh installs create no telemetry. ASG then needs independent released
baseline-to-exact-candidate migration verification and separately approved
enabled-root-telemetry deployment, timestamp write, opt-out and cleanup tests.
Existing telemetry-disabled Azure evidence does not cover these changes.

No cached dependency edits, generated-source hand edits, unilateral child
opt-out, unwired override fields, exception or waiver were introduced.
The runtime implementation remains unchanged and this telemetry remediation
remains blocked on the concrete specification/tooling and utility release
prerequisites above; passing local checks is not blanket compliance.

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
replacing the existing assignment. The separate 2026-11-10 immutable
description-replacement attempt under an unchanged CanNotDelete lock failed
with `ScopeLocked`; staged unlock/replacement/relock recovered successfully.
The module does not automatically unlock an unchanged lock.

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
