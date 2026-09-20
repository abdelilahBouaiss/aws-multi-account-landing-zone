# CloudTrail trusted-access module

## Purpose and responsibility

This reusable Terraform module enables AWS Organizations trusted service access
for the fixed CloudTrail service principal:

`cloudtrail.amazonaws.com`

It owns exactly one concern and one resource:

`aws_organizations_aws_service_access`

It does not own CloudTrail delegated-administrator registration, organization
trails, S3, KMS, accounts, OUs, SCPs, GuardDuty, Security Hub, IAM Identity
Center, CloudWatch Logs, SNS, or Terragrunt composition.

## Execution context

This module must execute with AWS Organizations management-account
credentials/provider context. Provider selection belongs to composition; this
module contains no provider block or alias.

The service principal is intentionally not configurable. This is a CloudTrail-
specific bootstrap module, not a generic trusted-access module.

## Bootstrap ordering

This module implements step 1 of the CloudTrail bootstrap sequence:

1. Enable Organizations trusted access for `cloudtrail.amazonaws.com` with this
   module.
2. Register Security Tooling as the CloudTrail delegated administrator with
   `modules/cloudtrail-bootstrap`.
3. Create and manage the organization trail with `modules/cloudtrail`.

The hard dependency is:

`modules/cloudtrail-trusted-access` → `modules/cloudtrail-bootstrap` → `modules/cloudtrail`

Reusable modules do not contain dependencies on one another. The implemented
Terragrunt live composition expresses the state and dependency ordering.

## Why this standalone resource is used

AWS recommends enabling trusted access through a service-specific console or
API when one is available because the service can perform required setup
actions. For this repository, v1 models the Organizations
`EnableAWSServiceAccess` operation explicitly with
`aws_organizations_aws_service_access` for CloudTrail.

The resource is intentionally separate from
`aws_organizations_organization.aws_service_access_principals` in
`modules/organization`. The standalone resource has its own lifecycle and
state boundary. The organization resource's inline argument can represent an
exclusive set, which could couple CloudTrail bootstrap to every other trusted
service and allow a later module to remove a service it does not own.

This resource models the AWS Organizations operation. It does not claim to
create every CloudTrail service-linked role or other AWS-managed side effect,
and mocked tests do not prove CloudTrail service-side integration behavior.

## Disable and destruction risk

Disabling or removing CloudTrail trusted access is not harmless cleanup. AWS
documents that disabling trusted access while CloudTrail organization trails
are in use can:

- remove organization trails for member accounts;
- convert management-account organization trails to account-level trails; and
- leave the CloudTrail service-linked role in place.

After trusted access is re-enabled, explicit trail updates may be required.
This module does not add casual toggle automation or `prevent_destroy`; later
production composition should protect this state and resource operationally.

## Testing and limitations

Run from this module directory:

```text
terraform init -backend=false
terraform validate
terraform test
```

Terraform-native tests use provider mocking to inspect the fixed service
principal and output. They do not prove management-account credentials,
Organizations membership, trusted-access enablement in AWS, CloudTrail
service-side setup, or service-linked-role behavior. No real AWS trusted-access
enablement has been validated by this repository.
