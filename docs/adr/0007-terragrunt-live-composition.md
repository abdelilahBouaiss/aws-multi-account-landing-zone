# ADR-0007: Terragrunt live composition

## Status

Accepted

## Context

The repository contains reusable Terraform modules for Organizations, account
vending, CloudTrail trusted access, CloudTrail delegated-administrator
registration, Log Archive storage, and the organization trail. These concerns
have different AWS account contexts, lifecycles, blast radii, and rollback
risks. They need a live composition boundary without moving infrastructure
implementation into Terragrunt.

CloudTrail also has an explicit ordering relationship: trusted access must be
enabled before delegated-administrator registration, and storage outputs must
be available before the organization trail can be composed. Account IDs needed
downstream are produced by the separate account-vending live unit at
`live/eu-west-1/management/accounts/`.

## Options considered

1. Use one root Terraform stack for Organization, account vending, trusted
   access, delegated administration, storage, and the trail. This centralizes
   wiring but couples unrelated lifecycles and creates an unnecessarily broad
   state blast radius.
2. Use one Terragrunt unit for all logging. This simplifies local navigation,
   but couples trusted access, delegated administration, storage, and trail
   rollback and obscures their different provider/account contexts.
3. Put provider aliases inside reusable Terraform modules. This could encode
   multiple account contexts in module source, but makes modules less portable
   and moves composition concerns into infrastructure implementation.
4. Build dependency paths dynamically from unresolved outputs. This could
   appear flexible, but prevents Terragrunt from reliably constructing the
   dependency graph for `run --all`.
5. Allow mocked dependency outputs for apply. This can make local execution
   appear convenient, but risks mutating resources with fake IDs and is not
   appropriate for an apply boundary.
6. Use remote Git module sources immediately. This would resemble a published
   consumer workflow, but adds release/version coordination before this
   same-repository reconstruction and its live layout are stable.
7. Use a delegated-administrator provider for `aws_cloudtrail` before real
   validation. This follows the intended service operating model, but the
   current Terraform-provider compatibility question is not resolved.

## Decision

Use separate Terragrunt units aligned with meaningful lifecycle and Terraform
state boundaries under `live/eu-west-1`:

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

The management units use management-account provider context. The storage unit
uses Log Archive account provider context. The `modules/cloudtrail` unit
initially uses management-account provider context until real AWS/provider
validation proves that the selected Terraform provider supports the delegated-
administrator execution path correctly.

Terragrunt uses singular `dependency` blocks for output/data relationships and
plural `dependencies` blocks for ordering-only relationships. The graph must
remain static enough for `run --all`; dependency paths must not depend on
unresolved outputs. Dependency outputs are consumed as unit inputs, ordering
does not require manufactured outputs, and both declarations remain in
consuming unit configurations rather than hidden in root includes.

Provider files are generated at the composition layer with Terragrunt
`generate` blocks. Reusable Terraform modules remain free of provider blocks.
Authentication is supplied by operator or CI configuration; no profile names,
role ARNs, SSO session names, or account IDs are frozen in this ADR.

Mock outputs belong only to singular `dependency` blocks and are allowed only
for non-mutating developer workflows. Ordering-only `dependencies` blocks do
not require mocks. The starting allow-list is `validate`; a deliberately safe
plan may be approved per unit later. Mocks are never allowed for apply or
destroy and are not evidence of deployed upstream infrastructure.

Use local module paths first, such as `../../../../modules/<module-name>` from
the approved unit depth. Versioned immutable module references remain the
expected direction for published production consumers.

Remote state is deferred. Later composition will use a separate state key per
unit, with backend configuration in root/common Terragrunt configuration and
remote-state infrastructure as a separate concern. Backend names, locking
mechanisms, KMS keys, and ownership are not decided here.

Account vending receives its own state boundary at
`live/eu-west-1/management/accounts/`. Its outputs for Security Tooling and Log
Archive are required before actual apply of downstream CloudTrail units. The
unit uses environment-supplied account owner emails; no real emails or account
IDs are encoded in the composition.

## Consequences

- Organization, account vending, trusted access, delegated administration,
  Log Archive storage, and the CloudTrail trail can be planned and recovered
  within narrower lifecycle/state boundaries.
- Provider/account contexts are explicit at the live-composition layer while
  Terraform modules remain reusable and independently testable.
- Cross-unit outputs and ordering are visible in the Terragrunt graph rather
  than hidden in a monolithic state.
- Mocked validation can proceed before all upstream states exist, but the
  command allow-list prevents fake outputs from reaching apply or destroy.
- There are more state boundaries and orchestration overhead than in a single
  stack, and the account-vending path must be resolved before real apply.
- Management-account provider context remains the initial Terraform execution
  choice for the trail despite Security Tooling being the intended delegated
  administrator; this preserves a documented compatibility safeguard pending
  real AWS/provider validation.
- No live Terragrunt configuration, generated provider, remote state, account
  credential, deployment, or real AWS validation is implied by this ADR.
