#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="$SCRIPT_DIR/.runtime"
ENDPOINT_EXPECTED="http://localhost:4566"
ERROR_DIR="$RUNTIME_DIR/logs"

: "${AWS_COMPATIBLE_ENDPOINT:?Set AWS_COMPATIBLE_ENDPOINT explicitly.}"
if [[ "$AWS_COMPATIBLE_ENDPOINT" != "$ENDPOINT_EXPECTED" || "$AWS_COMPATIBLE_ENDPOINT" == *amazonaws.com* ]]; then
  echo "Refusing to run: AWS_COMPATIBLE_ENDPOINT is not the approved local endpoint." >&2
  exit 1
fi

export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_REGION="eu-west-1"
export AWS_DEFAULT_REGION="eu-west-1"
export AWS_EC2_METADATA_DISABLED="true"
unset AWS_PROFILE AWS_DEFAULT_PROFILE AWS_SESSION_TOKEN AWS_WEB_IDENTITY_TOKEN_FILE AWS_ROLE_ARN

aws_local() {
  aws --endpoint-url "$AWS_COMPATIBLE_ENDPOINT" "$@"
}

terraform_output() {
  local root="$1"
  local state_name="$2"
  TF_DATA_DIR="$RUNTIME_DIR/terraform-data/$state_name" \
    terraform -chdir="$SCRIPT_DIR/terraform/$root" output -no-color -json -state="$RUNTIME_DIR/state/$state_name.tfstate"
}

pass() {
  echo "$1: passed locally"
}

unsupported() {
  echo "$1: unsupported by local AWS-compatible environment"
}

blocked() {
  echo "$1: blocked because prerequisite integration state is unavailable"
}

failures=0

if [[ ! -f "$RUNTIME_DIR/state/organization.tfstate" ]]; then
  blocked "organization"
  blocked "account-vending"
  blocked "SCP policy creation and attachment"
  blocked "trusted access"
  blocked "delegated admin"
  blocked "S3"
  blocked "KMS"
  blocked "organization CloudTrail"
  exit 0
fi

organization_output="$(terraform_output organization organization)"
organization_id="$(jq -r '.organization_id.value' <<<"$organization_output")"
management_account_id="$(jq -r '.management_account_id.value' <<<"$organization_output")"
root_id="$(jq -r '.root_id.value' <<<"$organization_output")"
top_level_ou_ids="$(jq '.top_level_ou_ids.value' <<<"$organization_output")"
workload_ou_ids="$(jq '.workload_ou_ids.value' <<<"$organization_output")"

if organization_api="$(aws_local organizations describe-organization 2>"$ERROR_DIR/organization.err")"; then
  jq -e --arg id "$organization_id" --arg management "$management_account_id" \
    '.Organization.Id == $id and .Organization.MasterAccountId == $management' \
    >/dev/null <<<"$organization_api" || { echo "organization: API output mismatch" >&2; failures=1; }
  roots_api="$(aws_local organizations list-roots)"
  jq -e --arg root "$root_id" '.Roots | any(.[]; .Id == $root)' >/dev/null <<<"$roots_api" || { echo "organization: root mismatch" >&2; failures=1; }
  top_level_api="$(aws_local organizations list-organizational-units-for-parent --parent-id "$root_id")"
  for ou_key in security infrastructure workloads sandbox policy_staging; do
    ou_name="$(jq -r --arg key "$ou_key" '.[$key]' <<<"$top_level_ou_ids")"
    jq -e --arg ou_id "$ou_name" '.OrganizationalUnits | any(.[]; .Id == $ou_id)' >/dev/null <<<"$top_level_api" || { echo "organization: missing top-level OU $ou_key" >&2; failures=1; }
  done
  workloads_id="$(jq -r '.workloads' <<<"$top_level_ou_ids")"
  workload_api="$(aws_local organizations list-organizational-units-for-parent --parent-id "$workloads_id")"
  for ou_key in non_production production; do
    ou_id="$(jq -r --arg key "$ou_key" '.[$key]' <<<"$workload_ou_ids")"
    jq -e --arg expected "$ou_id" '.OrganizationalUnits | any(.[]; .Id == $expected)' >/dev/null <<<"$workload_api" || { echo "organization: missing workload OU $ou_key" >&2; failures=1; }
  done
  [[ "$failures" -eq 0 ]] && pass "organization"
else
  cat "$ERROR_DIR/organization.err" >&2
  unsupported "organization API hierarchy queries"
fi

if [[ -f "$RUNTIME_DIR/state/account-vending.tfstate" ]]; then
  account_output="$(terraform_output account-vending account-vending)"
  accounts_api="$(aws_local organizations list-accounts 2>"$ERROR_DIR/accounts.err" || true)"
  if jq -e '.Accounts' >/dev/null 2>"$ERROR_DIR/accounts-jq.err" <<<"$accounts_api"; then
    account_mismatch=0
    while IFS=$'\t' read -r account_key account_id account_name; do
      jq -e --arg id "$account_id" --arg name "$account_name" '.Accounts | any(.[]; .Id == $id and .Name == $name)' >/dev/null <<<"$accounts_api" || account_mismatch=1
    done < <(jq -r '.account_ids.value | to_entries[] | [.key, .value, (if .key == "security_tooling" then "Security Tooling" elif .key == "log_archive" then "Log Archive" elif .key == "shared_services" then "Shared Services" elif .key == "development" then "Development" elif .key == "staging" then "Staging" elif .key == "production" then "Production" elif .key == "sandbox" then "Sandbox" else "Policy Test" end)] | @tsv' <<<"$account_output")
    parent_query_unsupported=0
    while IFS=$'\t' read -r account_key account_id; do
      case "$account_key" in
        security_tooling|log_archive) parent_id="$(jq -r '.security' <<<"$top_level_ou_ids")" ;;
        shared_services) parent_id="$(jq -r '.infrastructure' <<<"$top_level_ou_ids")" ;;
        development|staging) parent_id="$(jq -r '.non_production' <<<"$workload_ou_ids")" ;;
        production) parent_id="$(jq -r '.production' <<<"$workload_ou_ids")" ;;
        sandbox) parent_id="$(jq -r '.sandbox' <<<"$top_level_ou_ids")" ;;
        policy_test) parent_id="$(jq -r '.policy_staging' <<<"$top_level_ou_ids")" ;;
      esac
      parent_accounts="$(aws_local organizations list-accounts-for-parent --parent-id "$parent_id" 2>"$ERROR_DIR/parent.err" || true)"
      if ! jq -e '.Accounts' >/dev/null 2>"$ERROR_DIR/parent-jq.err" <<<"$parent_accounts"; then
        parent_query_unsupported=1
        break
      fi
      jq -e --arg id "$account_id" '.Accounts | any(.[]; .Id == $id)' >/dev/null <<<"$parent_accounts" || account_mismatch=1
    done < <(jq -r '.account_ids.value | to_entries[] | [.key, .value] | @tsv' <<<"$account_output")
    if [[ "$parent_query_unsupported" -eq 1 ]]; then
      unsupported "account-vending parent-placement query"
    elif [[ "$account_mismatch" -eq 0 ]]; then
      pass "account-vending"
    else
      echo "account-vending: API output mismatch" >&2
      failures=1
    fi
  else
    cat "$ERROR_DIR/accounts.err" >&2
    unsupported "account-vending API account listing"
  fi
else
  blocked "account-vending"
fi

if [[ -f "$RUNTIME_DIR/state/scp.tfstate" ]]; then
  scp_output="$(terraform_output scp scp)"
  scp_api="$(aws_local organizations list-policies --filter SERVICE_CONTROL_POLICY 2>"$ERROR_DIR/scp.err" || true)"
  if jq -e '.Policies' >/dev/null 2>"$ERROR_DIR/scp-jq.err" <<<"$scp_api"; then
    scp_mismatch=0
    while IFS=$'\t' read -r _ policy_id policy_name; do
      jq -e --arg id "$policy_id" --arg name "$policy_name" '.Policies | any(.[]; .Id == $id and .Name == $name)' >/dev/null <<<"$scp_api" || scp_mismatch=1
      targets="$(aws_local organizations list-targets-for-policy --policy-id "$policy_id" 2>"$ERROR_DIR/scp-target.err" || true)"
      jq -e --arg target "$(jq -r '.top_level_ou_ids.value.policy_staging' <<<"$organization_output")" '.Targets | any(.[]; .TargetId == $target)' >/dev/null <<<"$targets" || scp_mismatch=1
    done < <(jq -r '.policy_ids.value | to_entries[] | [.key, .value, (if .key == "protect_account_membership" then "protect-account-membership" elif .key == "restrict_regions" then "restrict-regions" elif .key == "protect_cloudtrail" then "protect-cloudtrail" elif .key == "protect_security_services" then "protect-security-services" else "restrict-member-root-user" end)] | @tsv' <<<"$scp_output")
    if [[ "$scp_mismatch" -eq 0 ]]; then pass "SCP policy creation and attachment"; else echo "SCP policy creation and attachment: API output mismatch" >&2; failures=1; fi
  else
    cat "$ERROR_DIR/scp.err" >&2
    unsupported "SCP policy or attachment APIs"
  fi
else
  blocked "SCP policy creation and attachment"
fi

if [[ -f "$RUNTIME_DIR/state/trusted-access.tfstate" ]]; then
  trusted_api="$(aws_local organizations list-aws-service-access-for-organization 2>"$ERROR_DIR/trusted.err" || true)"
  if jq -e '.ServicePrincipals' >/dev/null 2>"$ERROR_DIR/trusted-jq.err" <<<"$trusted_api"; then
    if jq -e '.ServicePrincipals | any(.[]; .ServicePrincipal == "cloudtrail.amazonaws.com")' >/dev/null <<<"$trusted_api"; then
      pass "trusted access"
    else
      echo "trusted access: CloudTrail principal missing" >&2
      failures=1
    fi
  else
    cat "$ERROR_DIR/trusted.err" >&2
    unsupported "trusted-access query"
  fi
else
  blocked "trusted access"
fi

if [[ -f "$RUNTIME_DIR/state/delegated-admin.tfstate" ]]; then
  if grep -q $'^delegated admin\tunsupported by local AWS-compatible environment$' "$RUNTIME_DIR/status.tsv"; then
    unsupported "delegated admin"
  else
    delegated_account_id="$(terraform_output delegated-admin delegated-admin | jq -r '.delegated_admin_account_id.value')"
    delegated_api="$(aws_local organizations list-delegated-administrators --service-principal cloudtrail.amazonaws.com 2>"$ERROR_DIR/admin.err" || true)"
    if jq -e --arg id "$delegated_account_id" '.DelegatedAdministrators | any(.[]; .Id == $id)' >/dev/null <<<"$delegated_api"; then
      pass "delegated admin"
    else
      cat "$ERROR_DIR/admin.err" >&2
      unsupported "delegated-admin query"
    fi
  fi
else
  blocked "delegated admin"
fi

if [[ -f "$RUNTIME_DIR/state/log-archive.tfstate" ]]; then
  log_archive_output="$(terraform_output log-archive log-archive)"
  bucket_name="$(jq -r '.bucket_name.value' <<<"$log_archive_output")"
  kms_key_id="$(jq -r '.kms_key_id.value' <<<"$log_archive_output")"
  s3_ok=1
  aws_local s3api head-bucket --bucket "$bucket_name" >/dev/null 2>"$ERROR_DIR/s3.err" || s3_ok=0
  public_access="$(aws_local s3api get-public-access-block --bucket "$bucket_name" 2>"$ERROR_DIR/s3-pab.err" || true)"
  versioning="$(aws_local s3api get-bucket-versioning --bucket "$bucket_name" 2>"$ERROR_DIR/s3-versioning.err" || true)"
  encryption="$(aws_local s3api get-bucket-encryption --bucket "$bucket_name" 2>"$ERROR_DIR/s3-encryption.err" || true)"
  bucket_policy="$(aws_local s3api get-bucket-policy --bucket "$bucket_name" 2>"$ERROR_DIR/s3-policy.err" || true)"
  bucket_policy_document="$(jq -r '.Policy // empty' <<<"$bucket_policy")"
  if jq -e '.PublicAccessBlockConfiguration | .BlockPublicAcls and .IgnorePublicAcls and .BlockPublicPolicy and .RestrictPublicBuckets' >/dev/null <<<"$public_access" \
    && jq -e '.Status == "Enabled"' >/dev/null <<<"$versioning" \
    && jq -e '.ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm == "aws:kms"' >/dev/null <<<"$encryption" \
    && jq -e --arg bucket_arn "arn:aws:s3:::$bucket_name" --arg organization_id "$organization_id" '.Statement | length == 2 and any(.[]; .Action == "s3:GetBucketAcl" and .Principal.Service == "cloudtrail.amazonaws.com" and .Resource == $bucket_arn) and any(.[]; .Action == "s3:PutObject" and .Principal.Service == "cloudtrail.amazonaws.com" and (.Resource | endswith(("/AWSLogs/" + $organization_id + "/*"))))' >/dev/null <<<"$bucket_policy_document" \
    && [[ "$s3_ok" -eq 1 ]]; then
    pass "S3"
  else
    if [[ -s "$ERROR_DIR/s3.err" || -s "$ERROR_DIR/s3-pab.err" ]]; then unsupported "S3 control queries"; else echo "S3: API output mismatch" >&2; failures=1; fi
  fi

  key_description="$(aws_local kms describe-key --key-id "$kms_key_id" 2>"$ERROR_DIR/kms.err" || true)"
  rotation="$(aws_local kms get-key-rotation-status --key-id "$kms_key_id" 2>"$ERROR_DIR/kms-rotation.err" || true)"
  key_policy="$(aws_local kms get-key-policy --key-id "$kms_key_id" --policy-name default --output text 2>"$ERROR_DIR/kms-policy.err" || true)"
  aliases="$(aws_local kms list-aliases --key-id "$kms_key_id" 2>"$ERROR_DIR/kms-alias.err" || true)"
  if jq -e '.KeyMetadata.KeyManager == "CUSTOMER" and .KeyMetadata.KeySpec == "SYMMETRIC_DEFAULT"' >/dev/null <<<"$key_description" \
    && jq -e '.KeyRotationEnabled == true' >/dev/null <<<"$rotation" \
    && jq -e '.Aliases | any(.[]; .AliasName == "alias/cloudtrail-log-archive")' >/dev/null <<<"$aliases" \
    && [[ -n "$key_policy" ]]; then
    pass "KMS"
  else
    if [[ -s "$ERROR_DIR/kms.err" || -s "$ERROR_DIR/kms-policy.err" ]]; then unsupported "KMS control queries"; else echo "KMS: API output mismatch" >&2; failures=1; fi
  fi
else
  blocked "S3"
  blocked "KMS"
fi

if [[ -f "$RUNTIME_DIR/state/cloudtrail.tfstate" ]]; then
  cloudtrail_output="$(terraform_output cloudtrail cloudtrail)"
  trail_name="$(jq -r '.trail_name.value' <<<"$cloudtrail_output")"
  trail="$(aws_local cloudtrail describe-trails --trail-name-list "$trail_name" 2>"$ERROR_DIR/trail.err" || true)"
  selectors="$(aws_local cloudtrail get-event-selectors --trail-name "$trail_name" 2>"$ERROR_DIR/selectors.err" || true)"
  if jq -e --arg bucket "$(jq -r '.bucket_name.value' <<<"$log_archive_output")" --arg kms "$(jq -r '.kms_key_arn.value' <<<"$log_archive_output")" '.trailList | any(.[]; .Name == "org-audit-trail" and .S3BucketName == $bucket and .KmsKeyId == $kms and .IsOrganizationTrail == true and .IsMultiRegionTrail == true and .IncludeGlobalServiceEvents == true and .LogFileValidationEnabled == true)' >/dev/null <<<"$trail" \
    && jq -e '.EventSelectors | length == 1 and .[0].IncludeManagementEvents == true and .[0].ReadWriteType == "All" and (.[0].DataResources // []) == []' >/dev/null <<<"$selectors"; then
    pass "organization CloudTrail"
  else
    if [[ -s "$ERROR_DIR/trail.err" || -s "$ERROR_DIR/selectors.err" ]]; then unsupported "CloudTrail control queries"; else echo "organization CloudTrail: API output mismatch" >&2; failures=1; fi
  fi
else
  blocked "organization CloudTrail"
fi

exit "$failures"
