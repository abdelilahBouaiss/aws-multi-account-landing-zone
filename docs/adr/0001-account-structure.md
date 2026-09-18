# ADR-0001: AWS Organization and account hierarchy

## Status

Accepted

## Context

The landing-zone reconstruction needs explicit account boundaries for
organization administration, security operations, centralized logging, shared
services, workloads, sandbox activity, and staged policy validation. A flat or
single-account model would make those responsibilities and their blast-radius
boundaries less explicit.

## Options considered

1. Keep all functions in a single AWS account.
2. Use a flat set of member accounts without meaningful OU boundaries.
3. Use the approved AWS Organizations hierarchy with dedicated OUs and
   accounts for security, logging, infrastructure, workloads, sandbox activity,
   and policy staging.

## Decision

Adopt the following global AWS Organizations hierarchy. Regional services and
resources associated with this architecture use `eu-west-1` as the primary AWS
region:

- a minimally used Organizations management account;
- Security OU containing Security Tooling and Log Archive accounts;
- Infrastructure OU containing the Shared Services account;
- Workloads OU containing separate NonProduction and Production OUs;
- Development and Staging accounts under NonProduction;
- Production account under Production;
- Sandbox OU containing the Sandbox account; and
- Policy-Staging OU containing the Policy-Test account.

The management account remains directly under the organization root and is not
placed inside an OU used for member accounts. The OUs in this hierarchy organize
member accounts.

Member accounts are initially intended to be created by Terraform as part of
account-vending functionality.

## Consequences

- Security tooling, centralized logging, shared services, and workloads have
  distinct ownership and failure boundaries.
- Production and non-production receive separate organizational boundaries.
- Policy changes can be evaluated in Policy-Staging before broader rollout.
- Account creation and OU placement become architecture-level concerns that
  must remain consistent with this model.
- The hierarchy adds account and policy-management complexity; that complexity
  is accepted to preserve isolation and explicit responsibility boundaries.
