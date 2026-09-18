# ADR-0004: Terraform modules and Terragrunt orchestration

## Status

Accepted

## Context

The repository needs reusable infrastructure implementation as well as
account- and environment-specific composition. These concerns have different
lifecycles: reusable modules should remain environment-agnostic, while account
and environment stacks must express configuration, dependencies, and state
relationships.

## Options considered

1. Use Terraform for both reusable modules and all account/environment
   composition without a separate orchestration layer.
2. Put infrastructure implementation and reusable logic primarily in
   Terragrunt configuration.
3. Keep reusable infrastructure in Terraform modules and use Terragrunt for
   account/environment composition and dependency orchestration.

## Decision

Terraform provides reusable, environment-agnostic infrastructure modules with
explicit responsibilities. Terragrunt composes account and environment stacks
and orchestrates their explicit dependencies.

Terragrunt is not forced into every infrastructure concern. Reusable resource
implementation belongs in Terraform; Terragrunt is used where composition,
configuration, or cross-stack dependency orchestration provides value. This
keeps module interfaces testable and portable while avoiding orchestration
abstractions around self-contained infrastructure concerns.

## Consequences

- Module logic can be reused across accounts and environments without embedding
  environment-specific composition.
- Account and environment configuration has a defined home outside reusable
  Terraform modules.
- Dependencies between stacks must be explicit and maintained by the
  Terragrunt composition layer.
- The repository has two related configuration layers, which requires clear
  ownership and documentation.
- Terragrunt configuration should remain DRY where useful, but abstraction is
  not justified solely to reduce line count.
