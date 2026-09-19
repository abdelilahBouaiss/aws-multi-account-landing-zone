# Terragrunt live composition architecture

## Purpose and status

This document freezes the first Terragrunt live-composition layout and
dependency model for the centralized CloudTrail capability. It describes the
composition boundary around the reusable Terraform modules, including the
implemented foundation units and the future units that remain to be built.

Generated provider files, remote-state configuration, backend infrastructure,
credentials, or real deployment are not created or implied by this design.

## V1 live hierarchy

The approved v1 hierarchy is rooted in the primary Region:

```text
live/
└── eu-west-1/
    ├── management/
    │   ├── organization/
    │   ├── accounts/
    │   ├── cloudtrail-trusted-access/
    │   ├── cloudtrail-bootstrap/
    │   └── cloudtrail/
    └── log-archive/
        └── cloudtrail-storage/
```

The `management/organization`, `management/accounts`,
`management/cloudtrail-trusted-access`, and `management/cloudtrail-bootstrap`
directories are implemented live units. The remaining directories are a design
contract only and must not be created until later implementation gates.

All units in this hierarchy use `eu-west-1`. Multi-Region CloudTrail coverage
is a CloudTrail setting, not a reason to create additional v1 Terragrunt
Region directories.

## Unit responsibilities and provider contexts

| Unit | Terraform module | Provider context | Responsibility and inputs |
| --- | --- | --- | --- |
| `management/organization` | `modules/organization` | Management account | AWS Organization and approved OUs only. Exposes organization ID, management-account ID, and OU outputs. It does not include account vending. |
| `management/accounts` | `modules/account-vending` | Management account | Creates the eight approved member accounts and places them using OU IDs from `management/organization`. Owns a separate account-vending state boundary. |
| `management/cloudtrail-trusted-access` | `modules/cloudtrail-trusted-access` | Management account | CloudTrail trusted access only. Operationally follows organization creation. |
| `management/cloudtrail-bootstrap` | `modules/cloudtrail-bootstrap` | Management account | CloudTrail delegated-administrator registration only. Consumes the Security Tooling account ID and follows trusted access. |
| `log-archive/cloudtrail-storage` | `modules/log-archive` | Log Archive account | S3/KMS log storage only. Consumes `organization_id`, `management_account_id`, and `trail_name`. |
| `management/cloudtrail` | `modules/cloudtrail` | Management account in v1 | Organization trail only. Consumes the Log Archive bucket name and KMS key ARN and follows trusted access, delegated-admin bootstrap, and storage. |

The provider/account choice is a composition concern. Reusable Terraform
modules continue to contain no provider blocks or aliases.

### Management organization unit

This unit composes only `modules/organization`. Its state owns the AWS
Organization and approved OUs and exposes `organization_id`,
`management_account_id`, and the OU ID maps. Account creation is deliberately
not placed in this state.

### Account-vending unit

This unit composes only `modules/account-vending` using management-account
provider context. It consumes the `top_level_ou_ids` and `workload_ou_ids`
outputs from `management/organization`, and defines the frozen eight-account
map explicitly. Owner emails are read from environment variables with no
source-code fallback; no real account emails are stored in Git.

The unit has its own state boundary. Its resulting `account_ids` output map,
including the `security_tooling` and `log_archive` IDs, will later feed CloudTrail
delegated-administrator/bootstrap and Log Archive composition. No account
creation has been performed by this documentation or composition change.

### Trusted-access unit

This implemented unit composes `modules/cloudtrail-trusted-access` using
management-account provider context. Organization existence is an operational
prerequisite, expressed as an ordering-only Terragrunt dependency:

```hcl
dependencies {
  paths = ["../organization"]
}
```

It consumes no organization outputs, requires no account-vending outputs, and
has no module inputs. This composition does not mean that trusted access has
been enabled in AWS; real management-account authentication remains the
operator or CI responsibility.

### Delegated-administrator unit

This implemented unit composes `modules/cloudtrail-bootstrap` using
management-account provider context. It has a data dependency on
`management/accounts` for `account_ids.security_tooling` and an independent
ordering-only dependency on `management/cloudtrail-trusted-access`:

```hcl
dependency "accounts" {
  config_path = "../accounts"
}

dependencies {
  paths = ["../cloudtrail-trusted-access"]
}
```

The accounts dependency uses a singular `dependency` block because the unit
consumes an output. Trusted access uses plural `dependencies` because only
execution ordering is required; no trusted-access outputs or mocks are used.
The account dependency has validation-only synthetic account-ID mocks. No
delegated administrator has actually been registered in AWS.

### Log Archive storage unit

This unit composes `modules/log-archive` using Log Archive account provider
context. It receives the organization ID, management-account ID, and trail name
from composition/configuration. Its outputs include the bucket name and KMS
key ARN consumed by the trail unit.

### Organization trail unit

This unit composes `modules/cloudtrail` using management-account provider
context in v1. This is a Terraform-provider compatibility constraint documented
in the CloudTrail architecture: real validation has not yet established that
the `aws_cloudtrail` resource works correctly from a delegated-administrator
provider context.

This execution choice does not change the intended Security Tooling delegated
administrator or management-account ownership model. Routine human use of the
management account remains minimized.

## Account-vending boundary

Account vending has its own deployable state/unit because account creation has
a separate lifecycle and blast radius from Organization/OU creation, and
downstream units require the Security Tooling and Log Archive account IDs. The
exact path is now frozen as:

```text
live/eu-west-1/management/accounts/
```

Before any real apply, composition must wire the account-vending outputs to
downstream units. The organization and account-vending states must not become
one organization-wide state. Remote state remains deferred.

## Dependency graph

The logical graph contains both data dependencies and ordering dependencies.
They are not interchangeable.

```text
organization
    ├── output: organization_id, management_account_id, and OU IDs
    │   └── accounts
    │       └── output: Security Tooling account ID
    │           └── cloudtrail-bootstrap
    ├── output: organization_id
    │   └── cloudtrail-storage
    │       └── output: bucket_name and kms_key_arn
    │           └── cloudtrail
    └── ordering: Organization exists
        └── cloudtrail-trusted-access

cloudtrail-trusted-access
    ├── ordering: trusted access must exist first
    │   └── cloudtrail-bootstrap
    └── ordering: trusted access must exist before trail management
        └── cloudtrail

cloudtrail-bootstrap
    └── ordering: delegated administration precedes trail management
        └── cloudtrail
```

The required relationships are:

- `organization -> accounts`: output dependency for OU placement and account
  composition;
- `accounts -> cloudtrail-bootstrap`: output dependency for the Security
  Tooling account ID;
- `organization -> cloudtrail-storage`: output dependency for `organization_id`
  and `management_account_id`, with trail name supplied by composition;
- `organization -> cloudtrail-trusted-access`: ordering-only dependency because
  trusted access requires an existing Organization but consumes no Organization
  output;
- `cloudtrail-trusted-access -> cloudtrail-bootstrap`: ordering dependency;
- `cloudtrail-trusted-access -> cloudtrail`: ordering dependency;
- `cloudtrail-storage -> cloudtrail`: output dependency for the bucket name and
  KMS key ARN; and
- `cloudtrail-bootstrap -> cloudtrail`: ordering dependency.

The trail also follows trusted access operationally. Terragrunt may represent
that as an explicit ordering dependency when needed, but no reusable Terraform
module depends directly on another module.

## Terragrunt dependency model

Terragrunt uses two dependency primitives. Use a singular `dependency` block
when a downstream unit consumes outputs from another unit:

```hcl
dependency "<name>" {
  config_path = "..."
}
```

Downstream `inputs` then consume values from
`dependency.<name>.outputs.<value>`. In this architecture, this is used for
`organization -> accounts`, `accounts -> cloudtrail-bootstrap`,
`organization -> cloudtrail-storage`, and `cloudtrail-storage -> cloudtrail`.
Dependency inputs are not used as a substitute for dependency outputs.

Use a plural `dependencies` block when a unit must run after another unit but
consumes no output:

```hcl
dependencies {
  paths = ["..."]
}
```

In this architecture, this is used for `organization ->
cloudtrail-trusted-access`, `cloudtrail-trusted-access -> cloudtrail-bootstrap`,
`cloudtrail-bootstrap -> cloudtrail`, and the explicit
`cloudtrail-trusted-access -> cloudtrail` ordering edge. Do not manufacture
unused outputs merely to create ordering. Both primitives participate in the
live orchestration graph, and dependency declarations remain in the consuming
unit configurations rather than being hidden in root includes.

Dependency paths must remain static and simple enough for Terragrunt to build
the graph for `run --all`. A dependency path must not itself depend on an
unresolved dependency output. Root/common includes should not contain unit
dependency blocks because that complicates graph parsing and hides lifecycle
relationships.

### Mock outputs

`mock_outputs` belong only to singular `dependency` blocks because they stand
in for dependency outputs. They are approved only for non-mutating developer
workflows where an upstream state is not available, such as validation and a
deliberately safe plan. Ordering-only `dependencies` relationships require no
mocks. The starting policy is:

```text
mock_outputs_allowed_terraform_commands = ["validate"]
```

Plan may be added for a specific unit only after its safety is reviewed. Mock
outputs must never be allowed for `apply` or `destroy`.

Mocks allow downstream configuration to be parsed and validated before
upstream state exists. They are not evidence of deployed infrastructure. Fake
IDs and ARNs must be structurally valid, must not contain real company or
account identifiers, and must not be used to force an apply. `skip_outputs =
true` is not used merely to force mocks because it hides the real dependency
output contract.

## Provider generation and authentication

Provider generation is a live-composition concern. Later unit configurations
should use Terragrunt `generate` blocks to produce `provider.tf` for the
selected provider context. The generated providers should use:

- management context: Region `eu-west-1` and operator/CI-supplied
  management-account authentication;
- Log Archive context: Region `eu-west-1` and operator/CI-supplied Log Archive
  account authentication.

No profile names, role ARNs, SSO session names, or account IDs are frozen here.
Authentication belongs to operator or CI configuration. Real account IDs and
role ARNs must come from composition/configuration, not reusable module source
code.

There is deliberately no Security Tooling provider for `modules/cloudtrail` in
v1. The trail unit initially uses management-account provider context until the
documented Terraform-provider compatibility question is validated against real
AWS.

## Root and include strategy

A DRY hierarchy is recommended without freezing excessive inheritance:

```text
live/root.hcl
live/eu-west-1/region.hcl
live/eu-west-1/management/account.hcl
live/eu-west-1/log-archive/account.hcl
```

Unit configurations should include only the root, Region, and account context
appropriate to their location. Root/common configuration should contain common
Terraform source conventions, future remote-state configuration, provider
generation primitives, and common tags only when those tags have meaningful
semantics. Region configuration should contain `region = "eu-west-1"`.
Account configuration should later contain account role/context metadata
supplied by composition.

Dependencies belong in the unit that consumes the output, not in the root
include, unless a later Terragrunt implementation demonstrates a compelling
reason otherwise.

### Current implementation status

The current foundation includes:

- `live/root.hcl` with common provider generation behavior;
- `live/eu-west-1/region.hcl` defining the `eu-west-1` Region contract;
- `live/eu-west-1/management/account.hcl` identifying the semantic
  `management` provider context; and
- `live/eu-west-1/management/organization/terragrunt.hcl` composing only
  `modules/organization` through the local source path
  `../../../../modules/organization`. Its outputs include
  `organization_id`, `management_account_id`, and the OU ID maps; and
- `live/eu-west-1/management/accounts/terragrunt.hcl` composing only
  `modules/account-vending` through the local source path
  `../../../../modules/account-vending`; and
- `live/eu-west-1/management/cloudtrail-trusted-access/terragrunt.hcl`
  composing only `modules/cloudtrail-trusted-access` through the local source
  path `../../../../modules/cloudtrail-trusted-access`; and
- `live/eu-west-1/management/cloudtrail-bootstrap/terragrunt.hcl` composing
  only `modules/cloudtrail-bootstrap` through the local source path
  `../../../../modules/cloudtrail-bootstrap`.

The generated provider uses ambient operator or CI credentials and the
`eu-west-1` Region. The management account context is semantic configuration;
it does not verify that the caller's credentials target the Organizations
management account. The operator or CI environment must ensure that account
selection is correct.

Log Archive storage, the organization trail, and remote state are not
implemented. Trusted access has not actually been enabled and no delegated
administrator has been registered in AWS. Local state remains suitable only
for local validation and static development examples, not the production state
architecture.

## Module source strategy

For this same-repository portfolio reconstruction, unit configurations should
use local module sources first. From the approved unit depth, the conceptual
source is:

```text
../../../../modules/<module-name>
```

The exact relative path must be checked from each unit when live configuration
is implemented. Production consumers would generally use immutable,
versioned module references, but requiring Git tags or releases before this
repository is published would add unnecessary coupling while modules and live
composition are developed together. No repository URL is assumed.

## Remote state and state boundaries

Remote state is deferred. Later design and implementation must provide a
separate state key per Terragrunt unit, with backend configuration owned by
root/common Terragrunt configuration and remote-state infrastructure treated
as a separate bootstrap concern.

This gate deliberately does not choose a backend bucket name, locking table,
OpenTofu lock mechanism, KMS key, or account owner. Local state may be used for
local/static development examples only; it is not a production state
architecture claim.

The minimum intended state boundaries are:

- Organization/OUs;
- account vending;
- CloudTrail trusted access;
- CloudTrail delegated-administrator registration;
- Log Archive storage; and
- the organization CloudTrail trail.

These boundaries reflect different provider/account contexts, blast radii,
lifecycle and rollback characteristics, and explicit dependency relationships.
They avoid coupling all organization concerns to a monolithic state.

## Failure and ordering scenarios

| Scenario | Likely impact | Where failure should occur | Recovery direction |
| --- | --- | --- | --- |
| Delegated-admin registration runs before trusted access. | Registration can fail with `CloudTrailAccessNotEnabledException`. | Trusted-access/delegated-admin dependency or AWS registration call. | Apply trusted access first, verify its state, then retry registration. |
| CloudTrail is planned before Log Archive outputs exist. | Trail inputs are unavailable or mocked, so a plan may be incomplete or unsafe. | Terragrunt dependency output resolution and plan policy. | Make storage output available; allow mocks only for safe validation, never apply. |
| Log Archive state is unavailable. | The trail cannot receive authoritative bucket/KMS outputs. | `cloudtrail` dependency resolution. | Restore/read the storage state or stop the trail operation until outputs are real. |
| Management provider targets the wrong account. | Organization/bootstrap resources may be attempted from an unauthorized or incorrect account. | Generated provider/authentication context and AWS authorization. | Stop, correct operator/CI account selection, and re-plan before mutation. |
| Log Archive provider targets the wrong account. | Storage may be created outside the Log Archive custody boundary or fail authorization. | Generated provider/authentication context and storage plan review. | Stop, correct account selection, and verify the planned account before apply. |
| Provider Region is not `eu-west-1`. | Region-anchored resources can fail validation or be created in the wrong context. | Provider generation and the CloudTrail module precondition. | Correct Region configuration and re-plan; do not add another v1 live Region. |
| Mock outputs reach apply. | Downstream resources could use fake identifiers or target nonexistent infrastructure. | Terragrunt command allow-list and review controls. | Disallow mocks for apply/destroy and obtain real dependency outputs. |
| A circular dependency is introduced between trail and storage. | `run --all` cannot construct a valid graph; neither unit has a safe order. | Terragrunt dependency graph construction. | Keep storage independent of the trail and remove the cycle. |
| Account-vending outputs are unavailable. | Security Tooling/Log Archive IDs cannot be wired to downstream units. | Account-vending dependency resolution. | Resolve the separate account-vending state/unit before actual apply. |
| One unit fails during multi-unit execution. | Later units may remain unexecuted or have stale upstream assumptions. | Terragrunt execution result and state review. | Stop, inspect the failed unit/state, recover it independently, then rerun the affected dependency path. |

These are composition and operator recovery directions, not monitoring or
automated recovery infrastructure.

## Validation limits and unresolved work

No live Terragrunt configuration, provider generation, remote state, or account
credentials are present yet. Terragrunt parsing and Terraform plan/validate do
not prove cross-account authorization, role assumption, trusted access,
delegated administration, CloudTrail delivery, or KMS/S3 service behavior.
No real AWS validation is claimed.

The next composition dependency to resolve before any actual apply is the
account-vending unit and its outputs for the Security Tooling and Log Archive
account IDs. The exact account-vending path, authentication implementation,
remote-state design, and real provider-context behavior for the trail remain
open implementation gates.
