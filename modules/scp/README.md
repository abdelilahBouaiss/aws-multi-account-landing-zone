# SCP module

## Purpose

This reusable Terraform module owns the repository's AWS Organizations service
control policy definitions and their explicit caller-selected attachments. The
current catalog contains one policy: `protect-account-membership`.

The module does not create the AWS Organization, organizational units, member
accounts, IAM permissions, security services, workload resources, or any live
Terragrunt composition.

## Current policy

`protect-account-membership` is a deny-oriented SCP with one statement:

- Effect: `Deny`
- Resource: `*`
- Actions: `organizations:LeaveOrganization` and `account:CloseAccount`

These are member-account self-service actions for leaving the organization and
closing an account. The policy does not include management-account governance
actions such as `organizations:RemoveAccountFromOrganization` or
`organizations:CloseAccount`.

SCPs establish maximum available permissions; they do not grant permissions.
An explicit SCP deny overrides permissions granted by IAM. SCPs also do not
restrict principals in the Organizations management account, so this policy is
intended to govern member accounts below an attachment target, not management-
account principals.

## Attachment targets

The `attachment_targets` input is an optional `map(string)` from a stable
caller-defined label to an AWS Organizations target ID. Root IDs, OU IDs, and
12-digit member-account IDs are accepted. The default empty map creates the
policy without any attachments, keeping policy creation and attachment
lifecycle separate.

The intended eventual broad scope for `protect-account-membership` is the
organization root. Staged rollout remains possible by first supplying narrower
targets such as Policy-Staging, Sandbox where relevant, or NonProduction. The
module does not hardcode a root or OU ID and does not choose rollout scope for
the caller.

Restrictive SCPs follow the approved sequence: static validation,
Policy-Staging, Sandbox where relevant, NonProduction, and Production. This
module provides the policy and explicit attachment mechanism; promotion and
rollback remain composition and governance responsibilities.

## Outputs

- `protect_account_membership_policy_id`: ID of the created SCP.
- `protect_account_membership_policy_arn`: ARN of the created SCP.

## Testing and limitations

Run the native tests from this module directory:

```text
terraform init -backend=false
terraform test
```

Tests use Terraform provider mocking to inspect the generated policy document,
attachment behavior, target propagation, and input validation. They do not
perform real AWS mutations or prove Organizations inheritance, management-
account exclusions, service behavior, or real AWS enforcement. Real AWS
validation remains necessary during staged rollout before broader attachment.

Later SCP gates may add the separately approved controls for region
restriction, centralized CloudTrail protection, centrally governed security
services, and member-account root-user restrictions. They are not defined by
this module yet.
