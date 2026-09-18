# Account-vending module

## Purpose

This reusable Terraform module creates the approved AWS Organizations member
accounts and assigns each account to a caller-supplied parent OU. It implements
the account-creation foundation for the landing-zone reconstruction; it does
not configure the services or workload baseline inside those accounts.

## Responsibility boundary

The module owns:

- `aws_organizations_account` resources for the eight approved account roles;
- account name, owner email, and target parent metadata supplied by the caller;
- common and per-account tag merging; and
- structured account ID and ARN outputs.

The caller must obtain and supply the target OU IDs, normally from the existing
organization module or an equivalent composition layer. This module does not
create the AWS Organization or OUs and does not infer placement from account
names.

The module deliberately does not own SCPs or attachments, delegated
administrators, GuardDuty, Security Hub, CloudTrail, IAM Identity Center,
networking, budgets, AWS Config, workload infrastructure, or Terragrunt live
configuration.

## Approved account keys and OU placement

The `accounts` map must contain exactly these stable logical keys:

| Logical key | Approved parent OU |
| --- | --- |
| `security_tooling` | Security |
| `log_archive` | Security |
| `shared_services` | Infrastructure |
| `development` | NonProduction |
| `staging` | NonProduction |
| `production` | Production |
| `sandbox` | Sandbox |
| `policy_test` | Policy-Staging |

The module validates the exact key set. Extra accounts and missing approved
accounts are rejected in v1 because these account boundaries are part of the
approved architecture.

## Inputs

### `accounts`

`accounts` is a required `map(object(...))` keyed by the logical account roles.
Each object contains:

| Attribute | Type | Requirement |
| --- | --- | --- |
| `name` | `string` | Required, non-empty, without boundary whitespace, and no longer than 50 characters. |
| `email` | `string` | Required, 6-64 ASCII characters with no boundary whitespace, exactly one `@`, an AWS-compatible local part, a dotted domain using only letters, numbers, hyphens, and dots, and unique within the map. |
| `parent_id` | `string` | Required and must match an AWS Organizations OU ID shape; supplied explicitly by the caller. |
| `tags` | `map(string)` | Optional; account-specific tags. |

The module does not provide default owner emails, derive emails from names, or
include company-specific domains. AWS must authoritatively verify that each
owner email is not already associated with another AWS account; local
validation does not prove global AWS email availability. The local part rejects
whitespace and the AWS-documented forbidden characters, while the domain is
checked for the practical character and boundary constraints described above.

Every account must target an OU rather than the organization root. The caller
remains responsible for supplying the correct existing OU ID for each logical
account; this module validates the ID shape but does not infer or prove the
OU's existence or architectural placement.

### `common_tags`

`common_tags` is an optional `map(string)` that defaults to `{}`. It is merged
before each account's `tags`, so account-specific values deliberately override
common values with the same key. Tags are not forced to include `Environment`:
roles such as Log Archive and Security Tooling do not necessarily have a
meaningful environment value.

## Outputs

- `account_ids`: map from logical account key to AWS account ID.
- `account_arns`: map from logical account key to AWS account ARN.

Emails are intentionally not exposed because later phases do not need them as
module outputs.

## Account creation behavior

Each account resource sets `close_on_deletion = false`. Destroying the
Terraform resource therefore does not request automatic closure of the AWS
account. The module does not set a custom `role_name`; AWS Organizations may
create its default `OrganizationAccountAccessRole` according to the provider
and Organizations behavior.

AWS Organizations account creation is asynchronous on the AWS side. Terraform
manages the account resource lifecycle, but readiness for every downstream
service must not be assumed merely because the account resource exists. Later
composition phases must establish and validate any required baseline before
using the account for security, logging, identity, networking, or workloads.

## Testing

From this module directory:

```text
terraform init -backend=false
terraform test
```

The native tests use provider mocking and validate the exact key invariant,
resource arguments, tag merging, `close_on_deletion`, structured outputs, and
input validation failures. They do not create real AWS accounts and do not
constitute AWS integration validation.

The module intentionally does not contain a module-local dependency lock file;
deployable root configurations own dependency lock files later.
