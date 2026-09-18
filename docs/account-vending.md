# Account-vending design

## Responsibility

Account vending creates the approved AWS Organizations member accounts and
places them in their caller-supplied parent OUs. The reusable implementation is
the `modules/account-vending` Terraform module.

The module creates accounts only. It does not create the Organization or OUs,
and it does not configure account baselines such as SCPs, delegated security
services, centralized logging, IAM Identity Center, networking, budgets, AWS
Config, or workloads.

## Logical account catalog

The module accepts exactly these logical account keys:

| Logical key | Approved OU | Responsibility |
| --- | --- | --- |
| `security_tooling` | Security | Delegated security administration and central security configuration. |
| `log_archive` | Security | Centralized organization audit logging and log retention. |
| `shared_services` | Infrastructure | Approved shared platform services. |
| `development` | NonProduction | Development workloads and development-focused testing. |
| `staging` | NonProduction | Staging workloads and pre-production validation. |
| `production` | Production | Production workloads and production-specific resources. |
| `sandbox` | Sandbox | Isolated experimentation and controlled evaluation. |
| `policy_test` | Policy-Staging | Controlled target for staged SCP validation. |

The management account remains directly under the Organization root and is not
created by this module or represented as a member-account resource.

## Caller and module responsibilities

The caller or composition layer supplies one `accounts` map keyed by the eight
logical roles. Each object supplies:

- `name`;
- `email`;
- `parent_id`, normally sourced from the organization module outputs; and
- optional account-specific `tags`.

The module also accepts optional `common_tags`. These are merged first, and
account-specific tags override matching common keys. Tags remain semantic: the
module does not require an `Environment` value for accounts such as Security
Tooling or Log Archive.

The module validates exact account keys, non-empty names, OU-shaped parent IDs,
and account emails using practical AWS Organizations constraints: 6-64 ASCII
characters, no boundary whitespace, exactly one `@`, a local part that does not
begin with a dot or contain AWS-documented forbidden characters, and a dotted
domain containing only letters, numbers, hyphens, and dots without a leading or
trailing hyphen or dot. Email uniqueness is checked case-insensitively within
the supplied map. It does not attempt to prove global AWS email availability;
AWS requires the account-owner email not already be associated with another AWS
account and is the authority for that check. The caller remains responsible for
mapping each logical account to the correct existing OU; the module does not
infer placement or validate that an OU ID exists in AWS.

No real account emails, account IDs, or company-specific domains belong in this
repository. Callers must provide operational emails outside the example
configuration and secret-management boundaries.

## Account creation lifecycle

AWS Organizations account creation is asynchronous on the AWS side. Terraform
manages the lifecycle of each `aws_organizations_account` resource, but the
existence of that resource must not be treated as proof that every downstream
service is ready or that all account baseline work is complete.

The module sets `close_on_deletion = false` and does not set a custom
`role_name`, leaving the default `OrganizationAccountAccessRole` behavior to
AWS Organizations and the provider. The module does not attempt to configure
account services during creation.

Later phases can establish account baselines and controls, including staged
SCPs, delegated security administration, centralized logging, human access,
networking, and workload infrastructure. Those phases remain separate so
account creation is not coupled to unrelated service configuration.

## Validation limits

Terraform-native tests use provider mocking to validate module contracts,
account key invariants, resource arguments, tag merging, outputs, and input
validation failures. They do not create real AWS accounts and do not prove AWS
email availability, asynchronous account readiness, Organizations behavior, or
downstream service integration.
