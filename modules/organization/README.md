# Organization module

## Purpose

This reusable Terraform module establishes the AWS Organizations foundation for
the landing-zone reconstruction in the approved primary regional provider
configuration, `eu-west-1`. AWS Organizations itself is global; the region is
the provider convention for this repository and for future regional resources.

## Responsibilities

The module owns:

- one AWS Organization with all features enabled;
- the approved top-level member-account OUs:
  - Security;
  - Infrastructure;
  - Workloads;
  - Sandbox; and
  - Policy-Staging; and
- the nested Workloads OUs:
  - NonProduction; and
  - Production.

The management account remains directly under the organization root. It is not
represented as an OU or as an `aws_organizations_account` resource.

The module deliberately does not own member accounts, account vending, SCP
policies or attachments, delegated administrators, security services, logging,
identity, networking, budgets, or other workload resources. Those concerns
belong to later architectural phases.

## Hierarchy

```text
AWS Organization root
├── Security OU
├── Infrastructure OU
├── Workloads OU
│   ├── NonProduction OU
│   └── Production OU
├── Sandbox OU
└── Policy-Staging OU
```

The Organization management account is directly under the organization root
and is outside this member-account OU hierarchy.

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `tags` | `map(string)` | `{}` | Common tags applied to organizational units where the AWS provider supports tagging. |

The module does not make approved OU names configurable. They are architecture
boundaries rather than environment-specific values. The organization resource
itself is not assigned the OU tag map because this module uses provider
capabilities accurately and does not assume the same tagging model for every
Organizations resource.

## Outputs

- `organization_id`: AWS Organization ID.
- `organization_arn`: AWS Organization ARN.
- `root_id`: AWS Organizations root ID.
- `top_level_ou_ids`: map keyed by `security`, `infrastructure`, `workloads`,
  `sandbox`, and `policy_staging`.
- `workload_ou_ids`: map keyed by `non_production` and `production`.

The structured OU maps are intended to make later account and policy
composition explicit without exposing unrelated resource values.

## Testing

From this module directory:

```text
terraform init -backend=false
terraform test
```

The native test uses Terraform provider mocking and mocked apply-time
assertions. Apply-time evaluation is used because provider-generated
organization-root and OU IDs are computed values that are not reliably known
for these relationships during a mocked plan. The test checks the approved OU
names, parent relationships, all-features organization configuration, and
hierarchy outputs without creating a real Organization or member accounts. It
does not constitute AWS integration validation.

## Organizations lifecycle considerations

- Organizations is a global AWS service; the module does not create a regional
  Organization.
- The caller must configure the official `hashicorp/aws` provider for the
  repository's primary region, `eu-west-1`, where regional provider
  configuration is required by the surrounding stack.
- The organization must exist before its OUs can be created; Terraform
  references establish that dependency.
- OUs with accounts or other dependent resources cannot be safely removed until
  those dependencies have been handled by their owning phases.
- Account creation and SCP rollout are separate later phases and are not implied
  by this module or its tests.
