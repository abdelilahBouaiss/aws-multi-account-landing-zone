# CloudTrail module

## Purpose and responsibility

This reusable Terraform module defines exactly one AWS Organizations CloudTrail
trail for the approved v1 architecture. It owns only the trail and its
management-event selector:

- organization-trail scope;
- multi-Region coverage;
- global service events;
- log-file validation; and
- read/write management events.

It does not create or manage the Log Archive S3 bucket, bucket policy, KMS key,
KMS key policy, delegated-administrator registration, Organizations trusted
access, service-linked roles, CloudWatch Logs, SNS, security services, IAM
Identity Center, SCPs, accounts, networking, or Terragrunt composition.

## Execution and ownership model

The architecture intends for Security Tooling to become the CloudTrail
delegated administrator. Registering that delegated administrator is a
prerequisite and is outside this module. V1 live composition uses the
management-account provider context because the selected Terraform provider
execution path has not been validated from a delegated-administrator context.
The module does not infer or register the relationship and does not contain
provider aliases.

The Organizations management account remains the service-level owner of the
organization trail even when Security Tooling manages it through delegated
administration. The actual trail home Region comes from the AWS provider
context. `home_region` records the approved architecture and is fixed to
`eu-west-1`; a resource precondition fails if the provider Region differs.
Composition must therefore pass a provider configured for `eu-west-1`; the v1
composition currently supplies the management-account provider.

Real organization-trail creation can involve AWS-managed Organizations and
CloudTrail integration, trusted access, and service-linked-role behavior. Those
control-plane prerequisites are not modeled here. A successful mocked plan or
test does not prove that the delegated-administrator prerequisite exists.

## Approved v1 configuration

The module encodes one trail with:

- `eu-west-1` as the fixed home Region;
- multi-Region coverage enabled;
- global service events enabled;
- organization-trail scope enabled;
- log-file validation enabled;
- management events enabled for both reads and writes;
- no baseline data events;
- no network activity events;
- no CloudTrail Insights;
- no CloudWatch Logs; and
- no SNS delivery notifications.

The single management-event selector is explicit and uses
`read_write_type = "All"`. No data resources, advanced event selectors, S3
key prefix, or additional trail are configured.

## Inputs

- `trail_name`: required practical CloudTrail trail name.
- `s3_bucket_name`: required externally managed Log Archive bucket name. The
  module validates shape but does not check that the bucket exists.
- `kms_key_arn`: required customer-managed KMS key ARN from the Log Archive
  composition. Key ARNs are accepted; alias ARNs are rejected.
- `home_region`: defaults to and is validated as `eu-west-1`; it must match the
  actual provider Region used for the module.
- `tags`: optional semantic trail tags.

The S3 bucket and KMS key are expected to come from the separately composed
`modules/log-archive` stack. This module receives their values as inputs and
does not discover or create them.

## Outputs

- `trail_id`
- `trail_arn`
- `trail_name`
- `trail_home_region`: the actual Region reported by the AWS provider context.
- `is_organization_trail`

## Testing and limitations

Run from this module directory:

```text
terraform init -backend=false
terraform validate
terraform test
```

Terraform-native tests use provider mocking and inspect the actual
`aws_cloudtrail` resource, its management-event selector, omitted optional
features, inputs, outputs, and validation rules. They do not create a real
trail or prove delegated-administrator registration, Organizations integration,
service-linked-role behavior, S3/KMS policy compatibility, CloudTrail delivery,
or arrival of log and digest objects in Log Archive.

Creating the trail successfully is not evidence that log delivery is healthy.
Real AWS validation must separately verify trail status, logging status,
delivery health, bucket-policy behavior, KMS authorization, and object arrival.
