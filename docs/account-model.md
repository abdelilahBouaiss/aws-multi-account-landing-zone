# AWS account and organizational-unit model

The primary AWS region is `eu-west-1`. The following hierarchy is the approved
v1 account model. Account names are functional labels, not real account IDs.

## Management account

**Responsibility:** Perform AWS Organizations functions that require the
management account, including organization administration and account
governance.

**Should not contain:** Normal workload resources, routine security tooling,
centralized audit logs, or shared services that can operate from a member
account.

The AWS Organizations management account remains directly under the organization
root. It is not placed inside an OU used for member accounts and is therefore
treated differently from the governed member-account hierarchy.

## Security OU

The Security OU contains the dedicated security and logging accounts. Security
operations and log storage remain separate responsibilities.

**Should not contain:** Workload accounts, application resources, general
shared services, or the Organizations management account.

### Security Tooling account

**Responsibility:** Host delegated security administration and central security
configuration, including Security Hub central configuration and GuardDuty
delegated administration.

**Should not contain:** Application workloads, the organization-wide log
archive, or unrelated shared platform services.

### Log Archive account

**Responsibility:** Provide the dedicated destination for centralized
organization audit logging and related log-retention responsibilities.

**Should not contain:** Security administration control planes, application
workloads, or general shared services.

## Infrastructure OU

### Shared Services account

**Responsibility:** Host intentionally shared infrastructure services that are
common to multiple accounts and approved for this boundary.

**Should not contain:** Production or non-production application workloads,
central security administration, or the centralized log archive.

The Infrastructure OU is the organizational boundary for the Shared Services
account.

**Should not contain:** Workload accounts, the Security Tooling account, the
Log Archive account, or the Organizations management account.

## Workloads OU

The Workloads OU separates non-production and production organizational
boundaries. This separation supports different governance, access, change, and
blast-radius expectations. It does not imply that connectivity between the
boundaries is allowed; production and non-production network paths must be
explicitly designed and authorized.

**Should not contain:** Organization administration, centralized security
administration, centralized audit logging, or accounts that are not workload
boundaries.

### NonProduction OU

Contains development and staging workload accounts. It is the boundary for
pre-production workloads and validation activities.

**Should not contain:** Production workloads, organization-wide control-plane
responsibilities, centralized security administration, or centralized audit
log storage.

#### Development account

**Responsibility:** Host development workloads and development-focused testing
within the non-production boundary.

**Should not contain:** Production workloads, central security services,
centralized logs, or organization administration.

#### Staging account

**Responsibility:** Host staging workloads and pre-production validation within
the non-production boundary.

**Should not contain:** Production workloads, central security services,
centralized logs, or organization administration.

### Production OU

Contains the production workload boundary and is intentionally separate from
NonProduction.

**Should not contain:** Development or staging accounts, organization
administration, centralized security administration, or centralized audit
logging.

#### Production account

**Responsibility:** Host production workloads and their production-specific
resources.

**Should not contain:** Development or staging workloads, organization
administration, central security administration, or the centralized log
archive.

## Sandbox OU

### Sandbox account

**Responsibility:** Provide an isolated account for experimentation and
controlled evaluation, including relevant policy testing where appropriate.

**Should not contain:** Production workloads or data, organization-wide
control-plane functions, central security administration, or the centralized
log archive.

The Sandbox OU is the organizational boundary for the Sandbox account.

**Should not contain:** Production or normal non-production workload accounts,
central security or logging accounts, or organization administration.

## Policy-Staging OU

### Policy-Test account

**Responsibility:** Provide a controlled target for staged SCP validation before
policies are considered for broader attachment. Restrictive SCPs follow the
sequence of static validation, Policy-Staging, Sandbox where relevant,
NonProduction, and Production.

**Should not contain:** Production workloads, general application hosting, or
organization-wide security and logging responsibilities.

The Policy-Staging OU is the organizational boundary for staged policy
validation.

**Should not contain:** Production workload accounts, general workload
accounts, or central security and logging accounts.

## Account creation and implementation boundary

Member accounts are initially intended to be created by Terraform as part of
account-vending functionality. Terraform modules remain reusable and
environment-agnostic; account and environment composition is handled outside
those modules through the approved Terragrunt boundary.

This model documents approved responsibilities and exclusions. It does not
claim that these accounts, controls, or network paths currently exist in AWS.
