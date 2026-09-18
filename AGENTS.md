# AGENTS.md

## Repository purpose

This repository is a public, clean-room reconstruction of AWS multi-account landing-zone patterns previously implemented professionally.

It is a portfolio artifact intended to demonstrate senior AWS Cloud/DevOps consulting capability through architecture quality, implementation quality, testing, security, operational safety, and clear technical communication.

The repository must remain technically honest. Do not invent deployment results, test results, benchmarks, production outcomes, AWS validation results, or historical metrics.

## Source of truth

Before implementing a task:

1. Read this file.
2. Read the relevant files under `docs/`.
3. Read any referenced Architecture Decision Records under `docs/adr/`.
4. Follow the explicit scope and acceptance criteria in the task.
5. Do not silently make material architecture decisions.

If required architecture is unspecified and the decision materially affects security, cost, blast radius, public API design, Terraform state boundaries, AWS account boundaries, networking, identity, or repository positioning, stop and surface the decision instead of choosing silently.

For minor implementation details that do not materially affect architecture, choose a conventional approach and document it where useful.

## Architecture baseline

The approved architecture baseline is:

* Primary AWS region: `eu-west-1`.
* AWS Organizations multi-account architecture.
* Minimal use of the Organizations management account.
* Dedicated Security Tooling account.
* Dedicated Log Archive account.
* Shared Services account.
* Separate development, staging, and production workload accounts.
* Separate production and non-production organizational boundaries.
* Policy-Staging OU used for staged SCP validation.
* Sandbox OU.
* Security Hub central configuration with AWS Foundational Security Best Practices as the initial baseline.
* GuardDuty delegated administration.
* Centralized organization audit logging.
* IAM Identity Center for normal human access.
* Transit Gateway hub-and-spoke network architecture.
* Production-style workload VPCs using public/private subnet topology.
* Terraform for reusable infrastructure modules.
* Terragrunt for account/environment composition and dependency orchestration.
* Multiple Terraform state boundaries rather than one organization-wide state.
* GitHub Actions as the public CI orchestrator.
* CI implementation logic lives under `scripts/ci/`.
* Apache-2.0 license.

Do not introduce AWS Control Tower unless explicitly approved.

Do not introduce Kubernetes, application workloads, SIEM platforms, Network Firewall, service catalog, IPAM, multi-region workload architecture, or additional major services without explicit approval.

## Integrity rules

Never claim that this reconstructed repository was deployed in production.

Never claim that a test ran unless it actually ran successfully.

Never claim that infrastructure was validated against real AWS unless it actually was.

Historical professional experience and current repository validation are separate concepts and must remain separate in documentation.

Acceptable wording may describe the project as a clean-room reconstruction of patterns previously implemented professionally.

Repository-specific validation must accurately describe the validation environment and test method.

Never fabricate metrics.

## AWS safety rules

Never:

* use `AdministratorAccess` as an implementation shortcut;
* add wildcard IAM permissions without documented justification;
* hardcode real AWS account IDs;
* hardcode real ARNs;
* commit AWS credentials;
* commit access keys;
* commit private keys;
* store secrets in Terraform source code;
* disable security tooling merely to make tests pass;
* weaken an IAM policy merely to make tests pass;
* attach a restrictive SCP directly to broad production scope without following the approved staging strategy.

IAM permissions must follow least privilege where practical.

Any required wildcard must be narrowly justified in code comments or architecture documentation.

## AWS account boundaries

The management account is reserved for functions requiring the Organizations management account.

Security operations should use delegated administration where supported.

Security Tooling and Log Archive responsibilities remain separate.

Production and non-production workloads must remain intentionally isolated.

Do not create cross-account connectivity merely because Transit Gateway supports it.

## SCP rules

SCPs are governance guardrails, not IAM permission grants.

Every SCP implementation must have:

* documented purpose;
* intended attachment scope;
* expected effect;
* known exceptions;
* validation strategy;
* rollback guidance.

Restrictive SCPs follow the approved staged rollout model:

1. static validation;
2. Policy-Staging;
3. Sandbox where relevant;
4. non-production;
5. production.

Do not bypass that design in documentation or implementation.

## Terraform rules

Terraform modules must be reusable and environment-agnostic.

Do not embed testing-emulator endpoints inside production modules.

Environment/account composition belongs outside reusable modules.

Avoid giant modules.

Prefer explicit module responsibilities.

Every public module input must have:

* a meaningful type;
* a description;
* sensible validation where valuable.

Every public output must have a description.

Sensitive outputs and variables must use Terraform sensitivity controls where appropriate.

Terraform code must pass `terraform fmt`.

Terraform code must pass `terraform validate` where validation is possible.

Do not use Terraform workspaces as the primary isolation mechanism for AWS accounts/environments.

Do not create one Terraform state containing the entire organization.

## Terragrunt rules

Terragrunt orchestrates account/environment composition and dependencies.

Do not move reusable infrastructure implementation into Terragrunt when it belongs in Terraform modules.

Keep configuration DRY where doing so improves maintainability, but do not create abstraction solely to reduce line count.

Dependencies between stacks must be explicit.

## Configuration rules

Do not hardcode values that belong to environment/account configuration.

Use clearly named configuration inputs.

Do not commit secrets.

Example configuration must contain placeholders rather than operational credentials or company-specific identifiers.

## Naming

Prefer predictable AWS resource naming.

Default conceptual pattern:

`{project}-{environment-or-account-role}-{resource-type}`

Do not blindly apply the pattern where AWS has different naming constraints or where a different name is clearer.

## Tagging

The minimum applicable tag baseline is:

* `Project`
* `Environment`
* `ManagedBy`
* `Owner`
* `CostCenter`

`ManagedBy` should normally be `Terraform`.

Use additional tags such as `DataClassification` or `Criticality` only where they have meaningful semantics.

Do not add meaningless tags merely to satisfy a count.

## Shell scripts

CI implementation logic belongs under `scripts/ci/`.

GitHub Actions workflows should primarily orchestrate these scripts rather than contain large inline shell implementations.

Shell scripts must:

* use Bash when Bash features are required;
* start with an appropriate shebang;
* use `set -euo pipefail` unless there is a documented reason not to;
* quote variable expansions correctly;
* produce useful failure messages;
* be compatible with ShellCheck expectations.

## CI/CD

GitHub Actions is the reference public CI implementation.

The underlying workflow must remain portable to systems such as GitLab CI or Jenkins by keeping substantive logic in `scripts/ci/`.

Pull-request CI will eventually include, where relevant:

* formatting;
* Terraform validation;
* Terragrunt validation;
* TFLint;
* ShellCheck;
* security scanning;
* Terraform native tests;
* repository/integration tests.

Do not add automatic production-style apply behavior without explicit approval.

## Security scanning

Expected security tools include Checkov and/or Trivy where useful.

Do not suppress findings solely to produce a green pipeline.

Every suppression must have a documented reason.

Avoid redundant scanners when they provide no additional useful signal.

## Testing philosophy

Testing must verify behavior, not merely file existence.

Use the appropriate layer:

1. static checks;
2. Terraform native tests;
3. integration tests;
4. architectural assertions.

Production Terraform modules must remain AWS-native.

Alternative AWS-compatible endpoints belong in the integration-test harness, not production modules.

One unavailable or failing test dependency must not be disguised as a passing test.

## Documentation

Documentation is part of the implementation.

Relevant changes must update relevant documentation.

The README is a concise portfolio/case-study entry point.

Detailed design material belongs under `docs/`.

Architecture decisions belong under `docs/adr/`.

Avoid oversized README content when detailed documentation is more appropriate.

## Architecture Decision Records

A material architecture decision should be documented using an ADR.

ADR structure:

* Status
* Context
* Options considered
* Decision
* Consequences

Do not generate ADRs merely to inflate the repository.

ADRs should capture genuine decisions with meaningful alternatives.

## Public documentation tone

Write like an experienced engineer documenting a real architecture.

Avoid:

* exaggerated marketing language;
* claims of being “enterprise-grade” without evidence;
* claims that the reconstruction itself achieved historical business outcomes;
* excessive emojis;
* generic AI-sounding filler;
* unnecessary feature lists;
* unexplained technology name-dropping.

Prefer concrete architectural reasoning and observable evidence.

## Historical metrics

Historical metrics may only be included if explicitly provided and approved by the repository owner.

Do not invent, extrapolate, improve, or reinterpret those metrics.

Clearly distinguish historical professional outcomes from validation performed against this public reconstruction.

## Commit scope

Keep changes scoped to the assigned task.

Do not refactor unrelated files.

Do not introduce new major dependencies, AWS services, modules, policies, tools, or architectural patterns unless the task requires them.

Before completing a task, inspect the diff for unrelated modifications.

## Completion criteria

A task is complete only when:

* requested scope is implemented;
* specified acceptance criteria are satisfied;
* applicable tests were actually executed;
* applicable static checks pass;
* security findings are resolved or documented;
* affected documentation is updated;
* architecture remains consistent with approved ADRs;
* no secrets or real company-specific information were introduced;
* no unrelated scope was added;
* the final response identifies exactly what changed and exactly which validation commands were run.

If validation could not be performed, state that explicitly.

Never replace missing validation with an assumption.
