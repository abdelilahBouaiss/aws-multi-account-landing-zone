# ADR-0005: Staged SCP rollout strategy

## Status

Accepted

## Context

SCPs can impose organization-wide maximum-permission boundaries on governed
member accounts. A restrictive deny can affect valid workload, security,
logging, account, or automation workflows when its scope or exceptions are
not fully understood. SCPs do not grant permissions, do not restrict
management-account principals, and do not restrict service-linked roles.

The landing-zone hierarchy includes a dedicated Policy-Staging OU and a
Sandbox OU so restrictive controls can be evaluated before they reach
non-production and production workloads.

## Options considered

1. Attach new restrictive SCPs directly to broad workload or production scope.
2. Avoid preventive SCP guardrails and rely only on IAM and operational review.
3. Use deny-oriented SCP guardrails with static validation and staged promotion
   through Policy-Staging, Sandbox where relevant, NonProduction, and
   Production.

## Decision

Use deny-oriented SCP guardrails with staged rollout rather than broadly
attaching new restrictive policies immediately.

The approved sequence is:

1. static policy validation;
2. Policy-Staging OU;
3. Sandbox where relevant;
4. NonProduction; and
5. Production.

Each control must document its purpose, intended attachment scope, expected
effect, known exceptions, validation strategy, and rollback guidance before
implementation. The initial catalog and deferred implementation questions are
defined in `docs/scp-rollout.md`.

## Consequences

- Restrictive policy changes have a narrower initial blast radius and a defined
  promotion path.
- Policy-Staging provides a dedicated target for policy behavior; Sandbox can
  provide additional isolated workflow testing when relevant.
- Promotion requires validation of inherited policies, valid workflows,
  service and automation behavior, and rollback readiness.
- Rollout takes longer and requires coordination, evidence, and explicit
  approval at each broader scope.
- Exact policy JSON, API action lists, global-service exceptions, automation
  role exceptions, and root-user exception sets remain implementation decisions
  until they are validated.
- The repository may implement policy definitions and mocked tests without
  claiming that any SCP has been attached, enforced, or validated against
  production AWS.
