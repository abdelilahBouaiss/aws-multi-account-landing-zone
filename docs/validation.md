# Repository validation matrix

This matrix records repository validation, not deployment or AWS integration
results. No validation described here requires or implies an AWS apply.

| Area | Status | Evidence or method | Boundary |
| --- | --- | --- | --- |
| Terraform formatting | Passed locally | `terraform fmt -check -recursive` | Checks syntax formatting only. |
| Terraform validation | Previously passed at module implementation gates; Gate 6.0 repository-wide rerun blocked | Earlier module gates passed `terraform validate` with local provider strategies. The later all-module rerun failed before schema loading because the AWS provider returned `Unrecognized remote plugin message`. | Historical local success does not prove AWS authorization, account context, or service behavior; no clean Gate 6.0 repository-wide rerun is claimed. |
| Terraform native tests | Previously passed at module implementation gates; Gate 6.0 repository-wide rerun blocked | Earlier module gates passed `terraform test` with mocked provider data. The later all-module rerun failed before test runs because of the same local provider plugin handshake. | Historical mocked success does not prove AWS behavior; no clean Gate 6.0 repository-wide rerun is claimed. |
| Terragrunt HCL formatting | Passed locally for exercised live units | `terragrunt hcl fmt --check` | Does not validate provider authentication or dependency state. |
| Terragrunt rendering | Passed locally | `terragrunt render` succeeded for all six live units with synthetic bucket, account-email, and dependency values. | Unapplied upstream state can cause mock-output warnings or fallback behavior. |
| Terragrunt validation | Blocked in the current environment | `terragrunt validate` was attempted for the live units, but Terraform could not resolve the AWS provider from the available mirror during the Terragrunt-initialized runs. | No claim of a repository-wide clean Terragrunt validation run. |
| Local AWS provider mirror | Used for selected validation | Terraform AWS provider 6.65.0 was supplied from a local filesystem mirror/cache. | The mirror/cache distributes the provider only; it does not validate AWS authentication or service behavior. |
| Local AWS-compatible integration | Partially exercised locally | `tests/integration/run.sh` and `verify.sh` passed locally for connectivity, Organizations/OUs, account vending and parent placement, SCP creation plus limited attachment, trusted-access resource creation, and Log Archive S3/KMS storage. Delegated-admin registration was unsupported by the local API; the organization trail was blocked by that prerequisite and log delivery was not exercised. | Integration-tested locally against AWS-compatible APIs does not prove AWS service behavior, account semantics, delivery, production readiness, or real AWS compatibility. |
| Real AWS validation | Not performed | No real AWS credentials were used and no AWS service mutations were performed. | Account creation, policy enforcement, delegated administration, delivery, and cross-account behavior remain unverified. |

## Safe validation policy

Use synthetic IDs, example.com email values, and validation-only bucket/KMS
values. Dependency mocks are permitted only for non-mutating validation and are
not evidence that upstream infrastructure exists. Do not run `apply` or
`destroy` as part of this repository-level validation workflow.
