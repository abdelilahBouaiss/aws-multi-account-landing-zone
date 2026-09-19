# Log Archive module

## Purpose and responsibility

This reusable Terraform module defines the Log Archive storage foundation for
centralized organization CloudTrail delivery. It owns:

- a dedicated S3 bucket;
- S3 public-access protection, ownership controls, and versioning;
- optional object-expiration lifecycle configuration;
- the CloudTrail bucket policy;
- a customer-managed symmetric KMS key and alias; and
- the KMS key policy for Log Archive account administration and the approved
  CloudTrail use.

It does not create an `aws_cloudtrail` resource, delegated administrator,
Organizations trusted access, CloudWatch Logs, SNS, security services,
identity services, workload infrastructure, or Terragrunt live composition.

The module prepares the destination for a later apply of the separately
composed `modules/cloudtrail` trail. It does not imply that any AWS resource
has been deployed or that log delivery has been validated.

## Ownership model

The S3 bucket and KMS key are intended to reside in the Log Archive account.
The organization trail is owned at the AWS service level by the Organizations
management account, while Security Tooling is the intended CloudTrail
delegated administrator. This module does not implement that delegated
administration or bootstrap.

The management-account ID is supplied explicitly to construct the authorized
organization trail ARN. The module does not infer it from the execution
identity. The current Log Archive account identity is inferred only for the
KMS key's account-root administration statement, because the KMS key belongs
to the account where this module executes.

## Inputs

Required inputs:

- `bucket_name`: caller-supplied, globally unique S3 bucket name. Local
  validation checks practical S3 naming rules but cannot prove global
  uniqueness.
- `organization_id`: AWS Organizations ID used in the organization delivery
  path.
- `management_account_id`: 12-digit management-account ID used in the trail
  ARN.
- `trail_name`: organization trail name used in the trail ARN.

Optional inputs:

- `trail_home_region`: defaults to `eu-west-1` and is fixed to that value by
  the approved v1 architecture.
- `retention_days`: defaults to `null`. Null creates no expiration rule;
  otherwise it must be a positive whole number.
- `tags`: semantic tags applied to the S3 bucket and KMS key.

The future trail ARN is constructed as:

`arn:<partition>:cloudtrail:eu-west-1:<management_account_id>:trail/<trail_name>`

The module derives the AWS partition from `aws_partition` and deliberately
does not use `aws_caller_identity` to infer the management-account ID.

## S3 controls and CloudTrail delivery contract

The bucket has all four S3 Block Public Access protections enabled, uses
`BucketOwnerEnforced` object ownership, and has versioning enabled. It does
not enable `force_destroy`, public access, website hosting, requester-pays,
or logging to another bucket.

Bucket-side encryption uses SSE-KMS with this module's customer-managed KMS
key and leaves S3 Bucket Keys disabled for v1.

The bucket policy contains exactly two CloudTrail service-principal statements:

1. `s3:GetBucketAcl` on the bucket ARN, constrained by the exact organization
   trail `aws:SourceArn`.
2. `s3:PutObject` on `AWSLogs/<organization_id>/*`, constrained by the exact
   organization trail `aws:SourceArn` and
   `s3:x-amz-acl = bucket-owner-full-control`.

The organization path is intentionally `AWSLogs/<organization_id>/*`; the
module does not add an additional management-account path. The policy does not
grant CloudTrail `s3:GetObject`, `s3:ListBucket`, `s3:DeleteObject`, or
`s3:PutBucketPolicy`, and it provides no workload-account read access.
Ownership and ACL delivery semantics are preserved for CloudTrail without
granting broad account access. The final policy remains subject to real AWS
delivery validation.

## KMS design

The module creates a customer-managed symmetric KMS key with rotation enabled
and a 30-day deletion window, plus the stable alias
`alias/cloudtrail-log-archive`.

The key policy grants:

- the Log Archive account root principal the standard account/key
  administration authority;
- `cloudtrail.amazonaws.com` `kms:GenerateDataKey*`, constrained by the exact
  organization trail `aws:SourceArn` and a multi-Region
  `kms:EncryptionContext:aws:cloudtrail:arn` pattern of
  `arn:<partition>:cloudtrail:*:<management_account_id>:trail/*`; and
- `cloudtrail.amazonaws.com` `kms:DescribeKey`, constrained by the exact
  organization trail `aws:SourceArn` without an encryption-context condition.

No generic audit-reader or recovery principal is created, and no workload
account receives `kms:Decrypt`. A disabled key or key policy that blocks the
required CloudTrail operations can stop encrypted log delivery.

The final KMS policy is explicit in the module but remains subject to real AWS
service behavior and delivery validation. The module does not create
CloudTrail delegated administration or centralized root access.

## Lifecycle and retention

When `retention_days` is `null`, no expiration lifecycle resource is created.
When it is configured, one enabled rule expires objects after the supplied
positive whole-number period. The module does not choose a regulatory period,
transition objects to Glacier or Deep Archive, or separately expire noncurrent
versions.

Retention is an operational/compliance input. It is not a compliance claim.
S3 versioning is not WORM storage, and S3 Object Lock is deliberately deferred
to a future architecture decision.

## Outputs

- `bucket_name`
- `bucket_arn`
- `kms_key_id`
- `kms_key_arn`
- `kms_alias_name`
- `cloudtrail_log_prefix`

## Testing and limitations

Run from this module directory:

```text
terraform init -backend=false
terraform validate
terraform test
```

Terraform-native tests use provider mocking and inspect decoded S3 and KMS
policy documents, resource settings, lifecycle behavior, outputs, and input
validation. They do not create real buckets or keys and cannot prove
cross-account CloudTrail delivery, S3/KMS service behavior, IAM authorization,
or audit-object arrival.

Real AWS validation must verify trail status, delivery health, log and digest
object arrival, bucket-policy behavior, KMS authorization, and the eventual
delegated-administrator workflow.
