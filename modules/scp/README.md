# SCP module

## Purpose

This reusable Terraform module owns the repository's AWS Organizations service
control policy definitions and their explicit caller-selected attachments. The
current catalog contains two policies: `protect-account-membership` and
`restrict-regions`.

The module does not create the AWS Organization, organizational units, member
accounts, IAM permissions, security services, workload resources, or any live
Terragrunt composition.

## Policy catalog

### `protect-account-membership`

This deny-oriented SCP has one statement:

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

### `restrict-regions`

This deny-oriented SCP has one statement that denies requests sent outside
`eu-west-1`:

- Effect: `Deny`
- Resource: `*`
- Condition: `StringNotEquals` on `aws:RequestedRegion` with exactly
  `eu-west-1` allowed
- `NotAction` exceptions:
  - `cloudfront:*` — CloudFront is a global service.
  - `iam:*` — IAM is a global identity service.
  - `route53:*` — Route 53 is a global DNS control plane.
  - `support:*` — Support is a global service.
  - `organizations:*` — Organizations is part of this repository's
    multi-account governance and control plane.
  - `budgets:*` — Budgets supports the planned organization and account cost
    control capability.
  - `sts:*` — STS preserves global endpoint behavior; operational guidance may
    still prefer regional STS endpoints.

The exception list is intentionally scoped to this landing-zone architecture;
it is not asserted to be sufficient for every AWS organization. Future global
or control-plane services require deliberate policy review rather than a silent
exception-list expansion.

The intended v1 attachment scope is Policy-Staging, Sandbox where relevant,
NonProduction, and Production. Root attachment is not the default or intended
end state for this policy. Security Tooling, Log Archive, Shared Services, and
the management account are not automatically in scope.

`aws:RequestedRegion` constrains the Region to which an API request is sent. It
does not guarantee that an allowed API call has no cross-Region effect, so this
policy is not a complete data-residency control.

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

The separate `restrict_regions_attachment_targets` input controls only
`restrict-regions` attachments. It defaults to an empty map and is intended for
Policy-Staging, Sandbox where relevant, NonProduction, and Production during
staged rollout. Keeping the maps separate prevents the two controls from
sharing attachment scope accidentally.

Restrictive SCPs follow the approved sequence: static validation,
Policy-Staging, Sandbox where relevant, NonProduction, and Production. This
module provides the policy and explicit attachment mechanism; promotion and
rollback remain composition and governance responsibilities.

## Outputs

- `protect_account_membership_policy_id`: ID of the created SCP.
- `protect_account_membership_policy_arn`: ARN of the created SCP.
- `restrict_regions_policy_id`: ID of the created SCP.
- `restrict_regions_policy_arn`: ARN of the created SCP.

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

Later SCP gates may add the separately approved controls for centralized
CloudTrail protection, centrally governed security services, and member-account
root-user restrictions. The latter three are not defined by this module yet.
