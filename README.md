# AWS multi-account landing-zone reconstruction

This repository is a clean-room reconstruction of AWS multi-account
landing-zone patterns previously implemented professionally. It is a public
portfolio artifact: the code demonstrates architecture boundaries, security
judgment, Terraform/Terragrunt composition, testing, and operational failure
thinking without claiming a production deployment or real AWS validation.

## The problem and design goals

A multi-account AWS environment needs more than a list of accounts. It needs
clear ownership boundaries for organization administration, security tooling,
audit-log custody, shared services, workloads, and policy testing. The design
also needs controlled rollout paths for restrictive guardrails and state
boundaries that limit blast radius.

The approved v1 design therefore uses:

- AWS Organizations with a minimally used management account;
- dedicated Security Tooling and Log Archive accounts;
- separate production and non-production workload boundaries;
- staged SCP rollout through Policy-Staging, Sandbox where relevant,
  NonProduction, and Production;
- a multi-Region organization CloudTrail trail with centralized S3/KMS
  storage; and
- Terraform modules plus Terragrunt live composition with separate state
  boundaries.

The primary AWS Region for regional provider configuration is `eu-west-1`.
AWS Organizations itself is global.

## At a glance

| Area | Repository status |
| --- | --- |
| Organizations / OUs | Implemented in [Terraform](modules/organization/) |
| Account vending | Implemented in [Terraform](modules/account-vending/); no AWS accounts have been created by this repository |
| SCP definitions | Implemented in [modules/scp](modules/scp/); no live attachment unit or AWS enforcement |
| Centralized CloudTrail | Terraform modules and [Terragrunt composition](docs/terragrunt-composition.md) implemented; AWS deployment and delivery unvalidated |
| Remote state | Deferred |
| AWS deployment validation | Not performed |
| CI | Not implemented |

## Architecture overview

See the detailed [architecture](docs/architecture.md) and
[account model](docs/account-model.md) documents for the approved hierarchy,
responsibilities, and deferred scope.

```mermaid
flowchart TD
    ORG[AWS Organizations]
    ORG --> MGMT[Management account]

    ORG --> SEC[Security OU]
    SEC --> STOOL[Security Tooling]
    SEC --> LOG[Log Archive]

    ORG --> INFRA[Infrastructure OU]
    INFRA --> SHARED[Shared Services]

    ORG --> WORK[Workloads OU]
    WORK --> NONPROD[NonProduction OU]
    NONPROD --> DEV[Development]
    NONPROD --> STAGE[Staging]
    WORK --> PROD[Production OU]
    PROD --> PRODACCT[Production]

    ORG --> SANDBOX[Sandbox OU]
    SANDBOX --> SBOX[Sandbox]
    ORG --> POLICY[Policy-Staging OU]
    POLICY --> POLICYTEST[Policy-Test]
```

The management account remains directly under the organization root and is
not represented as a member-account resource or OU child. Account names in
this diagram are functional labels, not account IDs.

## What is implemented in code

Reusable Terraform modules currently cover:

- the [AWS Organization and approved OU hierarchy](modules/organization/);
- the [eight-account account-vending contract](modules/account-vending/);
- five SCP policy definitions and explicit attachment interfaces in
  [modules/scp](modules/scp/);
- [CloudTrail trusted access](modules/cloudtrail-trusted-access/);
- [CloudTrail delegated-administrator registration](modules/cloudtrail-bootstrap/);
- [Log Archive S3/KMS storage and CloudTrail delivery policies](modules/log-archive/); and
- the [single organization CloudTrail trail definition](modules/cloudtrail/).

The [Terragrunt live composition](live/) currently contains the v1 CloudTrail
chain:

```text
management/organization
    ├── management/accounts
    │       └── management/cloudtrail-bootstrap
    ├── management/cloudtrail-trusted-access
    │       ├── management/cloudtrail-bootstrap
    │       └── management/cloudtrail
    └── log-archive/cloudtrail-storage
            └── management/cloudtrail
```

The live units are source configuration only. No AWS account, SCP, trusted
access relationship, delegated administrator, bucket, key, trail, or log
delivery has been created by this repository.

## Security and governance decisions

SCPs are deny-oriented governance guardrails, not IAM permission grants. The
five approved policy definitions and caller-controlled attachment interfaces
exist in [modules/scp](modules/scp/); no SCP Terragrunt live/state unit exists,
and no real AWS SCP attachment or enforcement has been performed. The policies
protect account membership, regional boundaries, CloudTrail configuration,
security-service configuration, and routine member root-user activity.
Attachments must follow the staged rollout documented in
[docs/scp-rollout.md](docs/scp-rollout.md).

Security Tooling is the intended delegated administration boundary for
GuardDuty, Security Hub, and CloudTrail-related security operations where AWS
supports it. Log Archive is a separate audit-custody boundary. IAM Identity
Center is the intended normal human-access model, but its infrastructure is
not implemented in this repository.

## Centralized CloudTrail design

The v1 logging design uses one multi-Region organization trail with:

- `eu-west-1` as the home Region;
- global service events enabled;
- read/write management events;
- log-file validation enabled; and
- no baseline data events, network activity events, Insights, CloudWatch Logs,
  or SNS delivery.

The Log Archive account owns the S3 bucket and customer-managed KMS key.
Security Tooling is the intended delegated administrator, while the
Organizations management account remains the service-level owner and the
initial Terraform execution context for the trail. See
[docs/cloudtrail-logging.md](docs/cloudtrail-logging.md) for ownership,
delivery, and failure details.

## Terraform, Terragrunt, and state boundaries

Terraform modules remain reusable and provider-free. Terragrunt supplies
account/environment composition, generated providers, dependency wiring, and
the live state boundaries. The design separates at least Organization, account
vending, trusted access, delegated administration, Log Archive storage, and
the organization trail. It intentionally avoids one organization-wide state.

Remote state and its backend infrastructure are not implemented. Current local
state is suitable only for static/local development and validation examples;
it is not the production state architecture.

## Validation status

Validation is deliberately separated from AWS deployment claims. Earlier
module implementation gates successfully ran Terraform validation and native
tests locally with mocked providers. The later Gate 6.0 repository-wide rerun
was blocked by a local AWS provider plugin handshake issue. Terragrunt render
was exercised across all live units, but no clean repository-wide Terraform or
Terragrunt validation rerun is claimed. See [docs/validation.md](docs/validation.md)
for the evidence and boundaries.

No AWS credentials are required for the repository's mocked tests. No
`apply` or `destroy` should be used for static/mocked module validation or
normal Terragrunt inspection. Apply/destroy are confined to the isolated
`tests/integration` harness and only against its explicit local AWS-compatible
endpoint. The detailed status matrix is linked above.

Selected landing-zone paths are integration-tested locally against
AWS-compatible APIs using synthetic credentials and an explicit local
endpoint. Current local evidence covers Organizations/OUs, account vending,
SCP creation and limited attachment, trusted-access resource creation, and
Log Archive S3/KMS storage. Delegated-admin registration is unsupported by the
local API, so organization-trail creation and log delivery were not exercised.
This does not constitute real AWS validation. See
[tests/integration/README.md](tests/integration/README.md) for its safety
boundary and current limitations.

## Failure and recovery thinking

The repository treats wrong account context, missing dependency state, account
creation failures, bucket-name collisions, KMS policy errors, CloudTrail
delivery failures, broad SCP attachments, Region restrictions, and partial
state operations as explicit operational risks. See
[docs/failure-scenarios.md](docs/failure-scenarios.md) for symptoms, blast
radius, detection, and safe recovery direction.

## Repository structure

```text
modules/       Reusable Terraform modules and native tests
live/          Terragrunt composition and provider-generation context
docs/          Architecture, operational design, validation, and ADRs
```

There is currently no committed GitHub Actions workflow or `scripts/ci/`
implementation. CI orchestration is an approved future repository concern;
local commands remain the source of the validation evidence documented here.

## Deferred scope and limitations

The following are intentionally design-only or deferred:

- remote-state infrastructure and backend naming;
- real provider authentication, account identity verification, and role
  assumption;
- AWS account creation and account readiness validation;
- SCP attachment and enforcement validation in AWS;
- trusted-access and delegated-administrator behavior in AWS;
- S3/KMS/CloudTrail delivery validation and object-arrival evidence;
- GuardDuty, Security Hub, IAM Identity Center, networking, Transit Gateway,
  workload VPCs, budgets, and AWS Config resources;
- multi-Region workload architecture, Control Tower, IPAM, Network Firewall,
  Kubernetes, application workloads, SIEM platforms, and Service Catalog.

These omissions are scope boundaries, not claims that the capabilities are
unnecessary in every future environment.

## Local inspection

From the repository root, inspect formatting with:

```text
terraform fmt -check -recursive
terragrunt hcl fmt --check
git diff --check
```

For a module, use its established local provider strategy when needed:

```text
terraform init -backend=false
terraform validate
terraform test
```

For live composition, provide only synthetic validation values, use
`terragrunt render` or `terragrunt validate`, and never allow dependency mocks
to reach `apply` or `destroy`.

## License

Apache-2.0. The license text is included in [LICENSE](LICENSE).
