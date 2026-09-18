# ADR-0002: Minimize use of the Organizations management account

## Status

Accepted

## Context

The AWS Organizations management account has organization-wide authority and a
large blast radius. Using it as a general-purpose location for security,
logging, shared services, or workloads would make separation of duties and
failure containment less clear.

AWS supports delegated administration for selected security services, allowing
those responsibilities to operate from a designated member account.

## Options considered

1. Use the management account as the central location for most landing-zone,
   security, logging, and workload functions.
2. Use the management account only where AWS Organizations requires it, while
   moving supported security responsibilities to delegated member accounts.
3. Avoid centralized administration and operate every security function
   independently in workload accounts.

## Decision

Minimize use of the Organizations management account. Reserve it for
organization-level functions that require that account, including applicable
Organizations administration and account governance.

Use delegated administration where AWS supports it. In this architecture,
Security Hub uses delegated administration with central configuration and
GuardDuty uses delegated administration from the dedicated Security Tooling
account. Centralized logging remains in the separate Log Archive account.

## Consequences

- The management account has a narrower operational scope and a smaller
  routine-exposure surface.
- Security operations have a dedicated member-account boundary.
- Security Tooling and Log Archive remain separate responsibilities.
- The design depends on the capabilities and limitations of AWS delegated
  administration for each service.
- Functions that genuinely require the management account still need explicit
  handling there; minimization does not mean eliminating that account's role.
