# SCP governance and rollout strategy

## Purpose

Service control policies (SCPs) provide organization-level preventive
guardrails for governed member accounts. This document defines the approved
rollout lifecycle and the initial catalog of controls during implementation.

SCPs are deny-oriented guardrails. They establish the maximum permissions
available to principals in affected member accounts; they do not grant IAM
permissions. An explicit SCP `Deny` overrides permissions granted by IAM.

The `protect-account-membership`, `restrict-regions`, and `protect-cloudtrail`
policy definitions are implemented in the reusable `modules/scp` module, with
separate caller-controlled attachments. The other catalog policies remain
design-only. The catalog records intended behavior, scope, risks, and
validation requirements without inventing final statements, actions,
conditions, `NotAction` lists, role names, or exceptions for those later
controls.

## AWS policy semantics

The following semantics govern design and review:

- SCPs establish maximum available permissions; they do not grant permissions.
- An explicit SCP `Deny` overrides permissions granted by IAM.
- SCPs do not restrict principals in the AWS Organizations management account.
- SCPs do not restrict service-linked roles.
- Inherited SCPs and other inherited policies must be considered when reasoning
  about effective permissions.
- Restrictive policies require testing before broader attachment.

The management account remains directly under the organization root and is not
placed in a member-account OU. A policy intended for root attachment must
therefore be reasoned about as applying to member accounts below the root, not
as a control on management-account principals.

## Rollout lifecycle

Restrictive SCPs follow this sequence:

1. **Static policy validation:** Review policy structure, intended scope,
   documented behavior, known exceptions, and implementation assumptions. This
   stage does not demonstrate AWS enforcement.
2. **Policy-Staging OU:** Attach the candidate policy to the Policy-Test
   account in the dedicated Policy-Staging OU. Evaluate intended denies,
   permitted workflows, inheritance, and rollback behavior in a controlled
   policy-test boundary.
3. **Sandbox where relevant:** Test the candidate in the Sandbox account when
   isolated experimentation or a broader set of representative workflows is
   relevant to the control.
4. **NonProduction:** Promote to the approved non-production workload scope,
   covering Development and Staging accounts as applicable. Confirm that valid
   pre-production operations and required security, logging, and automation
   workflows remain usable.
5. **Production:** Promote to the Production scope only after the promotion
   criteria below are satisfied and the change has an explicit approval.

Each stage must preserve the policy purpose, intended attachment scope,
expected effect, known exceptions, validation evidence, and rollback guidance.
The sequence is a control boundary, not an assertion that any stage has
already been executed.

## Policy-Staging and Sandbox

Policy-Staging is a purpose-built policy-validation boundary. The Policy-Test
account exists to evaluate candidate SCP behavior and attachment effects before
the policy is exposed to broader workload scopes.

Sandbox is an isolated experimentation boundary. It may be used when the
control needs additional representative workflow or resource testing, but it
is not a replacement for Policy-Staging and is not automatically required for
every control. Sandbox testing also does not authorize promotion without the
remaining validation and approval steps.

## Promotion criteria

A candidate may advance only when all applicable criteria are met:

- static validation has completed without unresolved structural or scope
  concerns;
- expected denied actions and permitted workflows have been evaluated at the
  current stage;
- no unexplained impact to valid security, logging, account, or workload
  automation remains;
- known exceptions are explicitly documented, and any required exception
  behavior has been validated;
- inherited policies and the management-account and service-linked-role limits
  have been considered;
- rollback can be performed at the current attachment scope; and
- an authorized review has approved promotion to the next stage.

Promotion must stop when a control produces an unexplained deny, an action
expected to be denied remains permitted, or an unvalidated automation impact.

## Rollback process

For a failed stage or unexpected impact:

1. Stop further promotion.
2. Remove or revert the candidate restrictive attachment from the affected
   scope, preserving unrelated approved guardrails.
3. Restore the previously approved policy state for that scope.
4. Re-evaluate the affected workflow and confirm that the impact is understood
   before retrying.
5. Record the failure, required exception or policy change, validation gap, and
   revised promotion conditions.

Emergency rollback is expected to be reversible and limited to the affected
restrictive control. An authorized operator may roll back a policy immediately
when it causes material access or service impact; the policy must then return
through validation before re-attachment. Emergency rollback does not authorize
silently weakening unrelated controls or bypassing the staged model for the
next attempt.

## Initial preventive-control catalog

| Policy name | Purpose | Target scope | Principal risk | Service/automation risk | Validation requirement |
| --- | --- | --- | --- | --- | --- |
| `protect-account-membership` | Prevent member accounts from leaving the organization or being closed without authorization. | Intended for attachment at the organization root so the guardrail applies to member accounts below it; SCP semantics do not restrict the management account. | A compromised member-account principal could attempt organization escape or unauthorized account closure. | Account-vending, account-governance, recovery, or other approved Organizations workflows could be denied. | Validate member-account behavior, management-account semantics, account lifecycle workflows, and the emergency rollback path before root attachment. |
| `restrict-regions` | Limit regional API activity to `eu-west-1` while preserving the architecture's approved global/control-plane services. | Policy-Staging, Sandbox where relevant, NonProduction, and Production; the management account and dedicated platform accounts are not automatically in scope. | A member-account principal could create resources outside the approved workload region, increasing governance, data-residency, and cost risk. | The fixed v1 `NotAction` exceptions are `cloudfront:*`, `iam:*`, `route53:*`, `support:*`, `organizations:*`, `budgets:*`, and `sts:*`. Future services require deliberate review. | Validate regional and global-service behavior in AWS. `aws:RequestedRegion` does not guarantee that an allowed API has no cross-Region effect and is not a complete data-residency control. |
| `protect-cloudtrail` | Defense in depth against governed member-account weakening of trail-based audit logging. Organization trails already require management-account or delegated-administrator permissions to manage. | Policy-Staging, Sandbox where relevant, NonProduction, and Production. It is not automatically attached to central logging, delegated-administration, root, or management boundaries. | A compromised member-account principal could attempt to reduce audit evidence. | The policy broadly denies four mutation actions for applicable trails in an attached scope. Future automation inside that scope requires explicit design and validation. | Validate real AWS enforcement, organization-trail administration boundaries, central logging workflows, and rollback before broader attachment. |
| `protect-security-services` | Protect centrally governed GuardDuty and Security Hub configuration from unauthorized member-account changes. | Governed member accounts; delegated security administration remains in the Security Tooling account. | A member-account principal could weaken detection or central security configuration to hide activity. | Delegated administration, central configuration, and approved security automation could be denied. Exact API actions and exceptions are deferred. | Validate GuardDuty and Security Hub service behavior, delegated administration, exact API actions, and exceptions before attachment. |
| `restrict-member-root-user` | Restrict routine AWS API use by root users in member accounts. | Member accounts; SCPs do not restrict management-account principals. | Use of member-account root credentials could bypass normal human-access controls and increase blast radius. | Some AWS operations may legitimately require root credentials; the exact exception set must be explicitly designed. | Identify legitimate root-required operations, validate the exception set, and test both denied routine use and permitted exceptional operations before attachment. |

## Control-specific implementation constraints

The catalog deliberately leaves implementation details open:

- `protect-account-membership` denies `organizations:LeaveOrganization` and
  `account:CloseAccount` to prevent unauthorized member-account departure and
  self-service account closure.
- `restrict-regions` is implemented with the fixed v1 `NotAction` list:
  `cloudfront:*`, `iam:*`, `route53:*`, `support:*`, `organizations:*`,
  `budgets:*`, and `sts:*`. These exceptions are intentionally scoped to this
  architecture and are not a universal AWS organization baseline. Future
  global or control-plane services require deliberate policy review rather than
  silent exception-list expansion. `aws:RequestedRegion` constrains where an
  API request is sent but does not guarantee that an allowed API has no
  cross-Region effect, so the policy is not a complete data-residency control.
- `protect-cloudtrail` is implemented as defense in depth, not as the primary
  protection for organization trails. It denies exactly
  `cloudtrail:StopLogging`, `cloudtrail:DeleteTrail`,
  `cloudtrail:UpdateTrail`, and `cloudtrail:PutEventSelectors`. With
  `Resource = "*"`, those actions are broadly denied for applicable trails in
  an attached governed account or OU. The policy does not deny
  `cloudtrail:CreateTrail`, `cloudtrail:StartLogging`,
  `cloudtrail:AddTags`, `cloudtrail:RemoveTags`, or
  `cloudtrail:PutInsightSelectors`. The central organization-trail
  infrastructure and delegated administration are not implemented here; real
  AWS enforcement and central logging workflow validation remain required.
- `protect-security-services` must be designed around validated GuardDuty and
  Security Hub behavior, delegated administration, API actions, and exceptions.
- `restrict-member-root-user` must have an explicitly designed and validated
  exception set for legitimate root-only operations.

No additional SCPs, declarative policies, or resource control policies are
included in this initial catalog.

## Local and emulated validation limits

Static, local, or emulated validation can help assess policy structure,
documentation, selected evaluation cases, and test-harness behavior. It cannot
fully reproduce real AWS Organizations inheritance, the management-account
exclusion, service-linked-role behavior, delegated administration, global versus
regional service behavior, condition-key support, or service-specific API
enforcement.

A passing local or emulated check is therefore not evidence of validation
against real AWS. Final policy behavior and exceptions require implementation-
time validation in an appropriate AWS environment before broader attachment.

## Status

This document records approved governance intent for the reconstruction. The
repository currently contains the `protect-account-membership`,
`restrict-regions`, and `protect-cloudtrail` policy definitions and mocked
Terraform validation for their documents and attachment models. This does not
claim that any policy has been attached, deployed, or validated against real
AWS or in production; broader rollout still requires the approved staged
process and AWS validation.
