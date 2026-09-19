# CloudTrail bootstrap module

## Purpose and responsibility

This reusable Terraform module registers the Security Tooling member account as
the AWS CloudTrail organization delegated administrator. It owns exactly one
resource:

`aws_cloudtrail_organization_delegated_admin_account`

It does not create the organization trail, Log Archive S3 bucket, KMS key,
SCPs, accounts, OUs, GuardDuty, Security Hub, IAM Identity Center, CloudWatch
Logs, SNS, or Terragrunt composition.

The organization trail remains the responsibility of
`modules/cloudtrail`. Log Archive storage remains the responsibility of
`modules/log-archive`.

## Execution context

This module must execute with AWS Organizations management-account
credentials/provider context. Only the management account can register or
remove a CloudTrail organization delegated administrator. Provider selection
belongs to composition; this reusable module contains no provider block or
alias.

The caller supplies the Security Tooling account ID produced by account
composition. The module does not discover an account from an email or name and
does not hardcode an account ID.

## Trusted-access prerequisite and ordering

This module is only the CloudTrail delegated-administrator registration step.
It is not the complete CloudTrail or AWS Organizations bootstrap.

Before this module can successfully apply, AWS Organizations trusted access
for CloudTrail must already be enabled from the management account for
`cloudtrail.amazonaws.com`. If trusted access is absent, delegated-admin
registration can fail with `CloudTrailAccessNotEnabledException`.

Trusted-access enablement is intentionally outside this module and will be
owned by a separate bootstrap or composition gate. The required sequence is:

1. Enable Organizations trusted access for `cloudtrail.amazonaws.com` from the
   management account.
2. Register Security Tooling as the CloudTrail delegated administrator with
   this module.
3. Create and manage the organization trail with `modules/cloudtrail`.

The presence of this module does not imply that trusted access currently exists
or that registration has occurred in AWS.

Registration is a prerequisite for delegated CloudTrail organization-trail
administration. AWS may create or manage CloudTrail service-linked roles as
part of this service-specific registration workflow. Those AWS control-plane
side effects are not represented as separate resources here.

## Why the CloudTrail-specific resource is used

The CloudTrail-specific resource maps to CloudTrail delegated-administrator
registration and its service control plane. It is preferred over the generic
`aws_organizations_delegated_administrator` resource because CloudTrail's
registration path integrates the CloudTrail-specific setup and has different
documented service-linked-role behavior from raw Organizations API delegation.
The module therefore uses the service-specific control plane rather than only
the generic Organizations delegation API.

## Provider compatibility note

AWS CloudTrail supports delegated administrators managing organization trails.
However, the current Terraform `aws_cloudtrail` resource documentation
describes organization-trail creation from the management account, and
historical provider behavior has had issues when creating an organization trail
directly from a delegated-administrator provider context.

This is a Terraform-provider execution and validation constraint, not an AWS
service limitation. Until real AWS validation proves the exact provider version
works correctly from the delegated-admin context, v1 composition will run
`modules/cloudtrail` with a management-account provider. That does not change
the architectural ownership model or the intended Security Tooling delegated
administration boundary. The routine human use of the management account
remains minimized.

## Inputs

- `security_tooling_account_id`: required 12-digit member-account ID for the
  intended Security Tooling delegated administrator.

## Outputs

- `delegated_admin_account_id`
- `delegated_admin_arn`
- `service_principal`

## Testing and limitations

Run from this module directory:

```text
terraform init -backend=false
terraform validate
terraform test
```

Terraform-native tests use provider mocking to inspect the resource contract,
account ID, service principal, outputs, and input validation. They do not prove
that the account belongs to the organization, that management-account
credentials are being used, that AWS registered the delegated administrator,
that service-linked roles exist, or that delegated access works in a real AWS
organization.
