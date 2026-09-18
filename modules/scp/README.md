# SCP module

## Purpose

This reusable Terraform module owns the repository's AWS Organizations service
control policy definitions and their explicit caller-selected attachments. The
current catalog contains four policies: `protect-account-membership`,
`restrict-regions`, `protect-cloudtrail`, and `protect-security-services`.

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

### `protect-cloudtrail`

This deny-oriented SCP is a defense-in-depth control for governed member
accounts. Organization trails already have service-level administration
boundaries: ordinary member accounts cannot modify an organization trail, and
management-account or CloudTrail delegated-administrator permissions are
required for organization-trail management. SCPs also do not restrict
management-account principals. This policy supplements those boundaries; it is
not the primary mechanism that makes an organization trail immutable.

It denies exactly these actions:

- `cloudtrail:StopLogging` — directly suspends recording and log delivery.
- `cloudtrail:DeleteTrail` — deletes the trail and stops future trail-based
  logging.
- `cloudtrail:UpdateTrail` — can materially change destinations and other
  trail settings.
- `cloudtrail:PutEventSelectors` — can reduce captured management, data, or
  network activity events and therefore audit coverage.

The policy does not deny `cloudtrail:CreateTrail`, `cloudtrail:StartLogging`,
`cloudtrail:AddTags`, `cloudtrail:RemoveTags`, or
`cloudtrail:PutInsightSelectors`. Creating an additional trail or starting
logging does not weaken audit coverage; tag operations do not alter captured
events; and CloudTrail Insights is outside the approved v1 audit-logging
baseline.

The statement uses `Resource = "*"`. At an attached governed account or OU, the
four denied mutation actions apply broadly to applicable trails in that scope,
not only to a named organization trail. This is an intentional centrally
governed landing-zone tradeoff. Resource-level filtering is deferred until a
centrally created trail ARN and validated requirement exist.

The intended path is Policy-Staging, Sandbox where relevant, NonProduction,
and Production. It is not automatically attached to Security Tooling, Log
Archive, Shared Services, the organization root, or the management account.
Attachment scope, rather than an IAM-role bypass, keeps a future central
CloudTrail delegated-administration control plane able to manage organization
trails. Any future automation required inside an attached scope needs explicit
design and AWS validation before an exception is considered.

### `protect-security-services`

This deny-oriented SCP is a defense-in-depth control for governed member
accounts. It does not replace GuardDuty delegated administration or
organization configuration, Security Hub delegated administration or central
configuration, or the service-level boundaries provided by those integrations.
Those security-service capabilities are later implementation concerns.

It denies exactly these actions:

- `guardduty:DeleteDetector` — deletes the regional detector and disables
  GuardDuty in that Region.
- `guardduty:UpdateDetector` — can change detector or protection-plan
  configuration and disable configured detection features.
- `securityhub:DisableSecurityHub` — disables Security Hub CSPM for an
  account/Region and its associated standards and controls.
- `securityhub:BatchDisableStandards` — can disable enabled Security Hub CSPM
  standards.
- `securityhub:BatchUpdateStandardsControlAssociations` — can disable
  security controls across standards.
- `securityhub:UpdateStandardsControl` — can enable or disable an individual
  control in a standard.

The policy intentionally does not deny GuardDuty delegated-administrator or
member-management APIs such as `guardduty:StopMonitoringMembers`,
`guardduty:DisassociateMembers`, `guardduty:DeleteMembers`,
`guardduty:UpdateMemberDetectors`,
`guardduty:UpdateOrganizationConfiguration`,
`guardduty:EnableOrganizationAdminAccount`, or
`guardduty:DisableOrganizationAdminAccount`. It also does not deny Security
Hub central-administration or configuration-policy APIs such as
`securityhub:UpdateOrganizationConfiguration`,
`securityhub:CreateConfigurationPolicy`,
`securityhub:UpdateConfigurationPolicy`,
`securityhub:DeleteConfigurationPolicy`,
`securityhub:StartConfigurationPolicyAssociation`,
`securityhub:StartConfigurationPolicyDisassociation`, or
`securityhub:DisassociateMembers`. The v1 policy also leaves
`guardduty:DisassociateFromAdministratorAccount` and
`securityhub:DisassociateFromAdministratorAccount` outside the deny set.
These exclusions preserve the central security control plane and the
Organizations-managed member model; no wildcard service deny is used.

The statement uses `Resource = "*"`, so the six denied capability-weakening
operations apply broadly to applicable GuardDuty and Security Hub resources in
an attached scope. The intended staged scope is Policy-Staging, Sandbox where
relevant, NonProduction, and Production. Security Tooling, Log Archive, Shared
Services, the organization root, and the management account are not
automatically in scope; Security Tooling must retain its future delegated
administrator role.

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

The separate `protect_cloudtrail_attachment_targets` input controls only
`protect-cloudtrail` attachments. It also defaults to an empty map and follows
the same staged workload and testing boundaries. It does not select a central
logging or delegated-administration target automatically.

The separate `protect_security_services_attachment_targets` input controls
only `protect-security-services` attachments. It defaults to an empty map and
accepts the same root, OU, and 12-digit account target IDs. The caller chooses
the staged workload and testing boundaries explicitly; Security Tooling is not
selected automatically.

Restrictive SCPs follow the approved sequence: static validation,
Policy-Staging, Sandbox where relevant, NonProduction, and Production. This
module provides the policy and explicit attachment mechanism; promotion and
rollback remain composition and governance responsibilities.

## Outputs

- `protect_account_membership_policy_id`: ID of the created SCP.
- `protect_account_membership_policy_arn`: ARN of the created SCP.
- `restrict_regions_policy_id`: ID of the created SCP.
- `restrict_regions_policy_arn`: ARN of the created SCP.
- `protect_cloudtrail_policy_id`: ID of the created SCP.
- `protect_cloudtrail_policy_arn`: ARN of the created SCP.
- `protect_security_services_policy_id`: ID of the created SCP.
- `protect_security_services_policy_arn`: ARN of the created SCP.

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
validation remains necessary during staged rollout before broader attachment,
including validation of GuardDuty/Security Hub behavior and delegated-admin
workflows.

The remaining approved SCP gate is the member-account root-user restriction.
It is not defined by this module yet.
