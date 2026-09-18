# ADR-0003: Terraform state boundaries

## Status

Accepted

## Context

The landing-zone architecture spans organization administration, account
vending, security, logging, shared services, networking, and workload account
boundaries. A single Terraform state for the entire organization would couple
unrelated changes and increase the blast radius of state operations.

The repository needs state boundaries that reflect meaningful architecture
without prematurely prescribing backend resource names or a final stack
inventory.

## Options considered

1. Store the entire organization in one Terraform state.
2. Use Terraform workspaces as the primary isolation mechanism for all
   accounts and environments.
3. Separate state by meaningful architectural domain and account boundary,
   with explicit composition and dependencies between those states.

## Decision

Use multiple Terraform state boundaries aligned with meaningful architectural
domains and account boundaries. Do not create one organization-wide state, and
do not use Terraform workspaces as the primary isolation mechanism for AWS
accounts or environments.

The exact backend bucket, locking-table, key, and stack names are intentionally
not decided by this ADR. Those details belong to the later implementation and
environment-composition design.

## Consequences

- Unrelated changes can be planned and applied within narrower boundaries.
- State failures and accidental changes have a more limited potential blast
  radius.
- Cross-state relationships must be explicit and maintained as the architecture
  evolves.
- There will be more state files and orchestration overhead than in a single
  state design.
- Backend naming and the precise state partitioning remain implementation
  decisions constrained by this boundary principle.
