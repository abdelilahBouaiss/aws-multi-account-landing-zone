# Centralized CloudTrail and Log Archive architecture

## Purpose and status

This document freezes the v1 design for centralized AWS CloudTrail audit
logging and the Log Archive storage boundary. It is an architecture contract
for later implementation gates, not an implementation report.

The repository currently contains no organization trail, S3 log bucket, KMS
key, CloudTrail delegated administrator, or delivery validation against real
AWS. No trail, bucket, or key should be inferred from this design document.

## V1 organization trail

The baseline contains exactly one AWS Organizations organization trail:

| Concern | V1 decision |
| --- | --- |
| Trail count | One organization trail; no per-account trails in the baseline. |
| Home Region | `eu-west-1`. |
| Regional coverage | Multi-Region trail enabled. |
| Global services | Global service events enabled. |
| Organization scope | Organization trail enabled. |
| Integrity | Log file validation enabled. |
| Management events | Read and write management events enabled. |
| Data events | Not enabled in the baseline. |
| Network activity events | Not enabled in the baseline. |
| CloudTrail Insights | Not enabled in the baseline. |
| CloudWatch Logs | Deferred. |
| SNS notifications | Deferred. |

The trail is a centralized control-plane capability. The design does not add
additional trails merely to provide account-local ownership or duplicate the
organization trail.

### Coverage rationale

Multi-Region coverage records management activity across enabled AWS Regions.
It reduces the chance that activity outside `eu-west-1` is missed and follows
AWS guidance for broad trail coverage. It complements, rather than replaces,
the `restrict-regions` SCP.

Global service events are enabled because services such as IAM and some STS or
CloudFront activity have special CloudTrail Region behavior. A workload Region
restriction does not eliminate the need to record global-service activity, and
the trail must not assume that every event is naturally attributed to
`eu-west-1`.

Read and write management events provide visibility into both observation and
change of AWS control-plane resources. Data events remain disabled because
they are workload-specific, potentially high-volume, and can add significant
cost. Future workloads may deliberately enable required S3, Lambda, or other
data-event coverage through a reviewed configuration.

Network activity events and CloudTrail Insights are outside the v1 baseline.
CloudWatch Logs delivery and SNS delivery notifications are also deferred;
their absence here is not a claim that they are never useful.

Log file validation enables verification of delivered log files through
CloudTrail digest files. It provides a mechanism to detect or verify
modification; it does not prevent modification by itself.

## Account ownership and administration

### Security Tooling account

Security Tooling is the intended CloudTrail delegated-administrator account.
After a later bootstrap gate, it should manage the organization trail and its
control plane using the AWS delegated-administration model. It does not own
the durable central log-storage bucket or its KMS key.

CloudTrail delegated administration is not implemented in this repository yet.
The intended role of Security Tooling does not imply that delegated access,
trusted service access, or the required service configuration currently exists.

### Log Archive account

Log Archive owns the dedicated CloudTrail S3 bucket and the customer-managed
KMS key used for CloudTrail log encryption. It is the durable audit-log
custody boundary. Storing the logs does not make Log Archive the CloudTrail
delegated administrator.

Workload accounts do not receive direct read access to the central bucket by
default. Any audit-reader or recovery access must be explicitly authorized.

### Organizations management account

The management account performs only the Organizations-level bootstrap needed
to register the intended CloudTrail delegated administrator and enable any
required trusted access. It remains the AWS service-level owner of the
organization trail even when Security Tooling later creates or manages the
trail through delegated administration.

The management account should not become the routine operating account for
CloudTrail. Its SCP exclusion and organization-level authority remain distinct
from member-account and Log Archive responsibilities.

## Log Archive storage boundary

The future implementation will create one dedicated S3 bucket in Log Archive
for the organization trail. The bucket name must be supplied by composition or
configuration because S3 names are globally unique. No company-specific name
or account ID belongs in this repository.

The storage baseline is:

- S3 Block Public Access enabled;
- S3 Bucket owner enforced/controlled by Log Archive;
- versioning enabled;
- no public ACL or public policy access;
- CloudTrail access granted only through the required, narrowly scoped bucket
  policy, including `s3:GetBucketAcl` on the destination bucket and
  `s3:PutObject` for delivered trail objects;
- organization-trail objects delivered under the organization path
  `AWSLogs/<organization-id>/*`;
- the bucket policy eventually scoped with `aws:SourceArn` to the organization
  trail;
- no broad wildcard account access; and
- no default direct read access for member workload accounts.

The future bucket policy must preserve the AWS-required ownership and ACL
delivery semantics for CloudTrail while keeping the grant limited to the
required service operations and organization log path. It must not grant broad
account access. The final bucket-policy JSON is intentionally deferred.

The `organization_id` used in `AWSLogs/<organization-id>/*` is a composition
input and must not be hardcoded. The organization trail ARN used in
`aws:SourceArn` conditions contains the Organizations management-account ID
because the organization trail is owned at the AWS service level by that
account. The actual organization and management-account IDs are composition
inputs, not repository constants.

### Encryption

CloudTrail will use SSE-KMS with a customer-managed symmetric KMS key located
in Log Archive. The future key policy must be designed to:

- permit `cloudtrail.amazonaws.com` only for the required cryptographic
  operations;
- scope CloudTrail use with `aws:SourceArn` tied to the organization trail;
- use CloudTrail encryption-context conditions where appropriate;
- permit decryption only to explicitly authorized audit-reader or recovery
  principals;
- avoid general `kms:Decrypt` access for workload accounts; and
- separate key administration from key usage where practical.

The final KMS policy JSON is intentionally not frozen here and no KMS key is
implemented by this gate. If the key is disabled, or its policy no longer
permits the required CloudTrail operations, log delivery can fail.

### Retention, lifecycle, and Object Lock

Lifecycle retention is configuration-driven. This design does not select an
arbitrary number of days and does not claim PCI, SOC 2, ISO, HIPAA, or any
other compliance outcome from retention alone.

S3 Object Lock is not part of v1. It remains a possible future immutability
enhancement that would require deliberate retention and governance-mode
design. S3 versioning alone is not WORM storage.

## Cross-account delivery model

The organization trail is owned by the management account at the AWS service
level. Security Tooling is the intended delegated administrator, while the S3
bucket and KMS key are owned by Log Archive. This split requires carefully
scoped S3 and KMS resource policies.

The future bucket policy must authorize only the required CloudTrail delivery
operations and use the organization trail ARN as the source constraint. The
future KMS policy must similarly scope CloudTrail cryptographic use. These
policies must not become broad account-wide grants.

## Delivery health and validation

A successfully created `aws_cloudtrail` resource does not prove that audit
delivery is functioning. CloudTrail may create an organization trail even when
resource validation fails, including a bad S3 bucket policy, insufficient KMS
permissions, or a CloudWatch Logs delivery failure if that integration is
later enabled.

Implementation-time validation must therefore include CloudTrail logging and
delivery/status checks and, where possible, evidence that both log objects and
digest objects reached the Log Archive bucket. Terraform apply success alone
must never be treated as proof of audit coverage.

## Relationship to existing SCPs

The existing `protect-cloudtrail` SCP is defense in depth for governed
workload accounts. It denies exactly:

- `cloudtrail:StopLogging`;
- `cloudtrail:DeleteTrail`;
- `cloudtrail:UpdateTrail`; and
- `cloudtrail:PutEventSelectors`.

Those denies do not make the organization trail immutable. Ordinary member
accounts already face CloudTrail organization-administration boundaries, and
management-account or delegated-administrator permissions are required for
organization-trail management. The SCP does not replace that service-level
model and does not restrict management-account principals.

The `restrict-regions` SCP and the multi-Region trail solve different
problems. `restrict-regions` attempts to limit governed workload API activity
to `eu-west-1`. The multi-Region trail observes activity across Regions and
provides visibility when permissions, exclusions, misconfiguration, or future
architecture allow activity elsewhere. CloudTrail must not be reduced to a
single-Region trail merely because workloads target `eu-west-1`.

## Failure scenarios

| Scenario | Expected impact | Detection or validation signal | Recovery direction |
| --- | --- | --- | --- |
| S3 bucket policy blocks CloudTrail delivery. | New log and digest objects are not delivered to Log Archive. | CloudTrail delivery/status checks fail, or expected objects are absent from the bucket. | Restore only the required CloudTrail bucket-policy permissions, then verify new log and digest delivery. |
| KMS policy blocks `GenerateDataKey` or another required CloudTrail operation. | SSE-KMS delivery fails even though the trail may still exist. | CloudTrail status/error evidence and missing encrypted objects in Log Archive. | Correct the narrowly scoped key policy and revalidate encryption and delivery. |
| KMS key is disabled. | CloudTrail cannot encrypt and deliver new objects with the customer-managed key. | KMS key state plus CloudTrail delivery/status evidence. | Re-enable or deliberately replace the key according to the approved recovery process, then verify delivery; do not bypass encryption casually. |
| Trail exists but `IsLogging` or delivery status is unhealthy. | The organization is not receiving the expected audit coverage. | CloudTrail logging/status checks and absence or delay of log/digest objects. | Restore logging and the responsible control-plane configuration, then validate object arrival. |
| Log Archive access is granted too broadly. | Unauthorized principals may read, alter, or administer audit storage. | Review S3 bucket policy, Block Public Access, ownership controls, KMS key policy, and access grants. | Remove the excess grant, preserve authorized recovery access, and review affected access history. |
| An authorized central administrator deletes or stops the organization trail. | Organization-wide audit coverage stops or the trail is removed. | CloudTrail/Organizations control-plane review and trail existence/logging status checks. | Restore the approved organization-trail configuration through the authorized control plane and follow SCP rollback/governance review. |
| Lifecycle configuration deletes logs earlier than intended. | Historical audit evidence is unavailable sooner than the configured policy permits. | Compare lifecycle configuration with the approved retention input and inspect object age/deletion behavior. | Correct the configuration-driven lifecycle policy and review whether recovery from another copy is possible. |
| The delegated administrator is removed or replaced. | Security Tooling can no longer operate the intended CloudTrail control plane, or administration moves unexpectedly. | Review Organizations/CloudTrail delegated-administrator configuration and management-account bootstrap state. | Re-register the approved administrator through the management-account bootstrap path and validate trail ownership, access, and delivery. |

These are architecture-level signals and recovery directions. This gate does
not create monitoring, alerting, notification, or recovery infrastructure.

## Future Terraform and state boundaries

The preferred reusable-module decomposition is:

### `modules/log-archive`

Owns:

- the dedicated CloudTrail S3 bucket;
- bucket security controls;
- the CloudTrail bucket policy;
- the Log Archive customer-managed KMS key and key policy; and
- lifecycle configuration.

### `modules/cloudtrail`

Owns:

- the organization CloudTrail trail;
- management-event selectors/configuration;
- log-file validation; and
- optional future CloudWatch Logs or SNS integration only after explicit
  approval.

Organizations delegated-administrator and trusted-access bootstrap resources
remain a separate organization/security composition concern. They should not
be silently hidden inside either module.

The exact root configurations and state names are not frozen by this design.
Terragrunt will compose the account/environment stacks and explicit
dependencies later, with separate state boundaries for the log-storage,
CloudTrail, and bootstrap concerns where the final composition requires them.
The design intentionally avoids one organization-wide logging state and avoids
a giant logging module.

## Deferred implementation questions

Later implementation gates must still define and validate the composition
inputs for the globally unique bucket name, `organization_id`,
management-account ID and organization trail ARN, lifecycle configuration,
approved audit-reader/recovery principals, exact KMS actions and
encryption-context conditions, trusted-access bootstrap sequence, and delivery
health checks.
Those details are implementation contracts to be reviewed against AWS service
behavior; they are not silently decided here.

## Status

This is an approved v1 architecture design only. No organization trail, Log
Archive bucket, KMS key, delegated administrator, CloudWatch Logs delivery, SNS
notification, or real AWS validation exists as a result of this gate.
