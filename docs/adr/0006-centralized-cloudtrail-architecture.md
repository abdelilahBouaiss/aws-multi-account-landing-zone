# ADR-0006: Centralized CloudTrail and Log Archive architecture

## Status

Accepted

## Context

The landing-zone architecture needs a single durable audit-log custody
boundary without turning the Organizations management account into the routine
security or logging operations account. CloudTrail organization trails,
cross-account S3 delivery, customer-managed KMS encryption, delegated
administration, and staged security controls have different ownership and
failure boundaries that must remain explicit during Terraform implementation
and live composition.

The design must also distinguish trail creation from actual log delivery. A
trail can exist while S3 or KMS resource policies prevent useful audit
coverage.

## Options considered

1. Use a single-Region trail. This is simpler, but it can miss management
   activity outside the primary workload Region and does not provide the
   intended broad visibility.
2. Create per-account trails. This can support local ownership or specialized
   selectors, but duplicates administration and delivery configuration and
   does not provide the approved v1 centralized organization-trail model.
3. Manage the trail routinely from the Organizations management account. This
   follows the service-level ownership boundary, but expands routine exposure
   of the highest-blast-radius account and conflicts with the approved
   management-account minimization decision.
4. Make Log Archive the CloudTrail delegated administrator. This colocates
   storage and administration, but storage custody does not imply that the
   account should operate the security control plane; Security Tooling is the
   approved delegated-administration boundary.
5. Use SSE-S3 instead of a customer-managed KMS key. This is simpler, but
   provides less explicit control over key administration, cryptographic use,
   and separation of audit storage ownership from key usage.
6. Enable CloudWatch Logs delivery in the baseline. This can support streaming
   analysis and operational workflows, but adds another delivery dependency,
   permissions, and cost before those requirements are approved.
7. Include S3 Object Lock in the baseline. This can strengthen immutability,
   but introduces governance and retention commitments that are not yet
   designed or approved.

## Decision

Adopt one AWS Organizations organization trail with:

- `eu-west-1` as the home Region;
- multi-Region coverage enabled;
- global service events enabled;
- organization-trail scope enabled;
- log file validation enabled;
- read and write management events enabled;
- no baseline data events;
- no baseline network activity events;
- no baseline CloudTrail Insights;
- no baseline CloudWatch Logs delivery; and
- no baseline SNS delivery notifications.

Security Tooling is the intended CloudTrail delegated administrator. The
Organizations management account remains the service-level owner of the
organization trail and performs only the Organizations bootstrap required to
register the delegated administrator and enable required trusted access. It
must not become the routine CloudTrail operating account.

The Log Archive account owns the dedicated CloudTrail S3 bucket and the
customer-managed symmetric KMS key used for SSE-KMS encryption of log and
digest objects. The cross-account S3 and KMS resource policies must be
narrowly scoped to CloudTrail and the organization trail ARN, whose management
account ID is supplied by composition rather than hardcoded.

The CloudTrail bucket policy must authorize `s3:GetBucketAcl` on the destination
bucket and `s3:PutObject` for delivered trail objects under
`AWSLogs/<organization-id>/*`. The `organization_id`, management-account ID,
and organization trail ARN are composition inputs and must not be hardcoded.
The policy must preserve AWS-required ownership and ACL delivery semantics
without granting broad account access. The reusable `modules/log-archive`
module defines the policy explicitly; its real AWS behavior remains
unvalidated.

Lifecycle retention is configurable and is not frozen to an arbitrary number
of days. S3 Object Lock is deferred. This ADR does not itself register the
delegated administrator, enable trusted access, create the S3 bucket or KMS
key, or validate delivery. The separate reusable bootstrap module now defines
the CloudTrail-specific registration resource, but its execution remains a
management-account composition concern and no real registration is implied.

Implement this design as separate reusable modules:

- `modules/log-archive` for the S3 bucket, bucket controls, CloudTrail bucket
  policy, KMS key/key policy, and lifecycle configuration; and
- `modules/cloudtrail` for the organization trail, management-event
  configuration, and log-file validation, with CloudWatch Logs or SNS only if
  later approved.

Delegated-administrator/bootstrap resources remain a separate
organization/security composition concern. Terragrunt composes these concerns
and their dependencies across meaningful state boundaries. Until real
AWS/provider validation proves the delegated-admin trail path for the selected
Terraform provider, v1 composition runs the trail module with management-account
provider context; this does not change the intended Security Tooling
delegated-administrator architecture.

## Consequences

- Audit logging has one centralized organization-trail control plane and one
  dedicated Log Archive custody boundary.
- Multi-Region and global-event coverage provides visibility beyond the
  `eu-west-1` workload target and complements, rather than replaces, the
  `restrict-regions` SCP.
- Security Tooling and Log Archive have separate administration and storage
  responsibilities.
- Customer-managed KMS encryption provides explicit key-policy control but
  creates a delivery dependency: a disabled key or insufficient key policy can
  stop log delivery.
- S3 bucket policy and KMS policy changes require cross-account validation;
  successful trail resource creation is not evidence of audit coverage.
- Data events, network activity events, Insights, CloudWatch Logs, SNS, Object
  Lock, and fixed retention periods remain deliberately deferred.
- The design requires separate module and state composition rather than a
  single logging module or organization-wide state.
- No deployment, attachment, delegated administration, or real AWS validation
  is implied by this decision.
