# Local AWS-compatible integration validation

This directory contains a small, isolated integration-validation layer for
selected landing-zone paths. It uses synthetic credentials and explicit
AWS-compatible API endpoints only. It does not change reusable Terraform
modules or normal Terragrunt composition.

## Prerequisite

An AWS-compatible API endpoint must be available at:

```text
http://localhost:4566
```

A non-mutating connectivity check is:

```bash
AWS_ACCESS_KEY_ID=test \
AWS_SECRET_ACCESS_KEY=test \
AWS_DEFAULT_REGION=eu-west-1 \
aws --endpoint-url http://localhost:4566 s3api list-buckets
```

The scripts require `AWS_COMPATIBLE_ENDPOINT` to equal exactly
`http://localhost:4566`. They fail closed for unset, public, or non-HTTP
endpoints. Terraform provider endpoint overrides are present only in the
integration roots under `terraform/`.

## Coverage

The roots follow separate architecture-aligned state boundaries:

1. Organizations and OUs;
2. member-account vending;
3. limited SCP creation and Policy-Staging attachment;
4. CloudTrail trusted access;
5. CloudTrail delegated-administrator registration;
6. Log Archive S3/KMS storage; and
7. the organization CloudTrail definition.

The scripts classify phases as passed locally, unsupported by the local
AWS-compatible environment, blocked by prerequisites, or failed. Policy
creation and attachment do not imply policy enforcement. CloudTrail object
arrival is not required by this harness because it needs real service behavior
and delivery evidence.

Synthetic account owner emails use `example.com`, the bucket defaults to
`portfolio-cloudtrail-integration-validation`, and provider credentials are
the literal local-only values `test`/`test`. No real credentials, account
identifiers, or production bucket names are used.

## Run, verify, and clean up

Run the integration phases without contacting public AWS endpoints:

```bash
export AWS_COMPATIBLE_ENDPOINT=http://localhost:4566
./tests/integration/run.sh
```

The run leaves state, logs, and generated runtime data under the ignored
`tests/integration/.runtime/` directory so failures can be inspected. Verify
again independently with:

```bash
./tests/integration/verify.sh
```

Apply and destroy are intentionally confined to this harness and its approved
local endpoint; they are not real AWS validation.

After inspection, destroy only the integration resources and remove runtime
artifacts with:

```bash
./tests/integration/cleanup.sh
```

Do not use these scripts with real AWS credentials or change the endpoint
contract. Local integration evidence does not constitute real AWS validation.
