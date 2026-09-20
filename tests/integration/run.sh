#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="$SCRIPT_DIR/.runtime"
ENDPOINT_EXPECTED="http://localhost:4566"

require_safe_endpoint() {
  : "${AWS_COMPATIBLE_ENDPOINT:?Set AWS_COMPATIBLE_ENDPOINT explicitly.}"

  if [[ "$AWS_COMPATIBLE_ENDPOINT" != "$ENDPOINT_EXPECTED" ]]; then
    echo "Refusing to run: AWS_COMPATIBLE_ENDPOINT must be $ENDPOINT_EXPECTED." >&2
    exit 1
  fi

  if [[ "$AWS_COMPATIBLE_ENDPOINT" == *amazonaws.com* || "$AWS_COMPATIBLE_ENDPOINT" != http://* ]]; then
    echo "Refusing to run: endpoint is not an approved local HTTP endpoint." >&2
    exit 1
  fi
}

require_safe_endpoint

for command_name in aws jq terraform; do
  command -v "$command_name" >/dev/null || {
    echo "Required command not found: $command_name" >&2
    exit 1
  }
done

if [[ -e "$RUNTIME_DIR" ]]; then
  echo "Runtime directory already exists: $RUNTIME_DIR" >&2
  echo "Inspect it or run cleanup.sh before starting another run." >&2
  exit 1
fi

export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_REGION="eu-west-1"
export AWS_DEFAULT_REGION="eu-west-1"
export AWS_EC2_METADATA_DISABLED="true"
unset AWS_PROFILE AWS_DEFAULT_PROFILE AWS_SESSION_TOKEN AWS_WEB_IDENTITY_TOKEN_FILE AWS_ROLE_ARN

mkdir -p "$RUNTIME_DIR"/logs "$RUNTIME_DIR"/state "$RUNTIME_DIR"/vars "$RUNTIME_DIR"/terraform-data
mkdir -p "$RUNTIME_DIR/plugin-cache"
export TF_PLUGIN_CACHE_DIR="$RUNTIME_DIR/plugin-cache"
: >"$RUNTIME_DIR/status.tsv"

aws_local() {
  aws --endpoint-url "$AWS_COMPATIBLE_ENDPOINT" "$@"
}

record_status() {
  printf '%s\t%s\n' "$1" "$2" >>"$RUNTIME_DIR/status.tsv"
}

mark_blocked() {
  record_status "$1" "blocked: $2"
  echo "$1: blocked: $2"
}

classify_failure() {
  local log_file="$1"

  if grep -Eiq 'not implemented|unsupported|unknown operation|not supported|InvalidAction' "$log_file"; then
    return 0
  fi

  return 1
}

run_phase() {
  local name="$1"
  local root="$SCRIPT_DIR/terraform/$2"
  local vars_file="$3"
  local state_file="$RUNTIME_DIR/state/$4.tfstate"
  local data_dir="$RUNTIME_DIR/terraform-data/$4"
  local log_file="$RUNTIME_DIR/logs/$4.log"

  mkdir -p "$data_dir"
  echo "Running $name..."

  if TF_DATA_DIR="$data_dir" terraform -chdir="$root" init -backend=false -input=false -no-color >"$log_file" 2>&1 \
    && TF_DATA_DIR="$data_dir" terraform -chdir="$root" apply -auto-approve -input=false -no-color -state="$state_file" -var-file="$vars_file" >>"$log_file" 2>&1; then
    record_status "$name" "passed locally"
    echo "$name: passed locally"
    return 0
  fi

  cat "$log_file" >&2
  if classify_failure "$log_file"; then
    record_status "$name" "unsupported by local AWS-compatible environment"
    echo "$name: unsupported by local AWS-compatible environment"
    return 2
  fi

  record_status "$name" "failed"
  echo "$name: failed"
  return 1
}

tf_output() {
  local root="$SCRIPT_DIR/terraform/$1"
  local state_file="$RUNTIME_DIR/state/$2.tfstate"
  local data_dir="$RUNTIME_DIR/terraform-data/$2"

  TF_DATA_DIR="$data_dir" terraform -chdir="$root" output -no-color -json -state="$state_file"
}

echo "Checking explicit local AWS-compatible endpoint..."
aws_local s3api list-buckets >/dev/null
if aws_local organizations list-roots >/dev/null 2>"$RUNTIME_DIR/logs/organizations-connectivity.log"; then
  organization_connectivity="ready"
elif grep -q "AWSOrganizationsNotInUseException" "$RUNTIME_DIR/logs/organizations-connectivity.log"; then
  organization_connectivity="reachable but not initialized"
else
  cat "$RUNTIME_DIR/logs/organizations-connectivity.log" >&2
  echo "Organizations connectivity check failed." >&2
  exit 1
fi
aws_local kms list-keys >/dev/null
aws_local cloudtrail describe-trails >/dev/null
record_status "connectivity" "passed locally ($organization_connectivity)"
echo "connectivity: passed locally ($organization_connectivity)"

jq -n --arg endpoint "$AWS_COMPATIBLE_ENDPOINT" '{endpoint: $endpoint}' \
  >"$RUNTIME_DIR/vars/organization.tfvars.json"

hard_failure=0
organization_ok=0
if run_phase "organization" "organization" "$RUNTIME_DIR/vars/organization.tfvars.json" "organization"; then
  organization_ok=1
else
  phase_result=$?
  if [[ "$phase_result" -eq 1 ]]; then hard_failure=1; fi
fi

accounts_ok=0
trusted_access_ok=0
bootstrap_ok=0
storage_ok=0

if [[ "$organization_ok" -eq 1 ]]; then
  if ! organization_output="$(tf_output organization organization)"; then
    record_status "organization" "failed: outputs unavailable"
    echo "organization: failed: outputs unavailable" >&2
    hard_failure=1
    organization_ok=0
  else
    jq -e '.organization_id.value and .management_account_id.value and .top_level_ou_ids.value and .workload_ou_ids.value' \
      >/dev/null <<<"$organization_output"

    jq -n \
      --arg endpoint "$AWS_COMPATIBLE_ENDPOINT" \
      --argjson top_level_ou_ids "$(jq '.top_level_ou_ids.value' <<<"$organization_output")" \
      --argjson workload_ou_ids "$(jq '.workload_ou_ids.value' <<<"$organization_output")" \
      '{endpoint: $endpoint, top_level_ou_ids: $top_level_ou_ids, workload_ou_ids: $workload_ou_ids}' \
      >"$RUNTIME_DIR/vars/account-vending.tfvars.json"

    jq -n \
      --arg endpoint "$AWS_COMPATIBLE_ENDPOINT" \
      --arg policy_staging_ou_id "$(jq -r '.top_level_ou_ids.value.policy_staging' <<<"$organization_output")" \
      '{endpoint: $endpoint, policy_staging_ou_id: $policy_staging_ou_id}' \
      >"$RUNTIME_DIR/vars/scp.tfvars.json"

    jq -n --arg endpoint "$AWS_COMPATIBLE_ENDPOINT" '{endpoint: $endpoint}' \
      >"$RUNTIME_DIR/vars/trusted-access.tfvars.json"

    jq -n \
      --arg endpoint "$AWS_COMPATIBLE_ENDPOINT" \
      --arg organization_id "$(jq -r '.organization_id.value' <<<"$organization_output")" \
      --arg management_account_id "$(jq -r '.management_account_id.value' <<<"$organization_output")" \
      --arg bucket_name "${AWS_CLOUDTRAIL_LOG_BUCKET_NAME:-portfolio-cloudtrail-integration-validation}" \
      '{endpoint: $endpoint, organization_id: $organization_id, management_account_id: $management_account_id, bucket_name: $bucket_name, trail_name: "org-audit-trail", trail_home_region: "eu-west-1"}' \
      >"$RUNTIME_DIR/vars/log-archive.tfvars.json"

    if run_phase "account-vending" "account-vending" "$RUNTIME_DIR/vars/account-vending.tfvars.json" "account-vending"; then
      accounts_ok=1
    else
      phase_result=$?
      if [[ "$phase_result" -eq 1 ]]; then hard_failure=1; fi
    fi

    if run_phase "SCP policy creation and attachment" "scp" "$RUNTIME_DIR/vars/scp.tfvars.json" "scp"; then
      :
    else
      phase_result=$?
      if [[ "$phase_result" -eq 1 ]]; then hard_failure=1; fi
    fi

    if run_phase "trusted access" "trusted-access" "$RUNTIME_DIR/vars/trusted-access.tfvars.json" "trusted-access"; then
      trusted_access_ok=1
    else
      phase_result=$?
      if [[ "$phase_result" -eq 1 ]]; then hard_failure=1; fi
    fi

    if [[ "$accounts_ok" -eq 1 && "$trusted_access_ok" -eq 1 ]]; then
      account_output="$(tf_output account-vending account-vending)"
      jq -n \
        --arg endpoint "$AWS_COMPATIBLE_ENDPOINT" \
        --arg security_tooling_account_id "$(jq -r '.account_ids.value.security_tooling' <<<"$account_output")" \
        '{endpoint: $endpoint, security_tooling_account_id: $security_tooling_account_id}' \
        >"$RUNTIME_DIR/vars/delegated-admin.tfvars.json"

      if run_phase "delegated admin" "delegated-admin" "$RUNTIME_DIR/vars/delegated-admin.tfvars.json" "delegated-admin"; then
        bootstrap_ok=1
      else
        phase_result=$?
        if [[ "$phase_result" -eq 1 ]]; then hard_failure=1; fi
      fi
    else
      mark_blocked "delegated admin" "account-vending and trusted access must pass first"
    fi

    if run_phase "Log Archive S3/KMS storage" "log-archive" "$RUNTIME_DIR/vars/log-archive.tfvars.json" "log-archive"; then
      storage_ok=1
    else
      phase_result=$?
      if [[ "$phase_result" -eq 1 ]]; then hard_failure=1; fi
    fi
  fi
else
  mark_blocked "account-vending" "organization phase did not pass"
  mark_blocked "SCP policy creation and attachment" "organization phase did not pass"
  mark_blocked "trusted access" "organization phase did not pass"
  mark_blocked "delegated admin" "organization/account prerequisites did not pass"
  mark_blocked "Log Archive S3/KMS storage" "organization phase did not pass"
fi

if [[ "$trusted_access_ok" -eq 1 && "$bootstrap_ok" -eq 1 && "$storage_ok" -eq 1 ]]; then
  log_archive_output="$(tf_output log-archive log-archive)"
  jq -n \
    --arg endpoint "$AWS_COMPATIBLE_ENDPOINT" \
    --arg bucket_name "$(jq -r '.bucket_name.value' <<<"$log_archive_output")" \
    --arg kms_key_arn "$(jq -r '.kms_key_arn.value' <<<"$log_archive_output")" \
    '{endpoint: $endpoint, bucket_name: $bucket_name, kms_key_arn: $kms_key_arn}' \
    >"$RUNTIME_DIR/vars/cloudtrail.tfvars.json"

  if run_phase "organization CloudTrail" "cloudtrail" "$RUNTIME_DIR/vars/cloudtrail.tfvars.json" "cloudtrail"; then
    :
  else
    phase_result=$?
    if [[ "$phase_result" -eq 1 ]]; then hard_failure=1; fi
  fi
else
  mark_blocked "organization CloudTrail" "trusted access, delegated admin, and storage must pass first"
fi

record_status "CloudTrail log delivery" "not exercised; object arrival requires real service behavior"
echo "CloudTrail log delivery: not exercised; object arrival requires real service behavior"

if [[ "$organization_ok" -eq 1 ]]; then
  if ! "$SCRIPT_DIR/verify.sh"; then
    hard_failure=1
  fi
else
  echo "Verification: blocked because organization state is unavailable."
fi

echo
echo "Integration phase summary:"
column -t -s $'\t' "$RUNTIME_DIR/status.tsv" 2>/dev/null || cat "$RUNTIME_DIR/status.tsv"

if [[ "$hard_failure" -ne 0 ]]; then
  echo "Integration run finished with failures; inspect $RUNTIME_DIR." >&2
  exit 1
fi

echo "Integration run finished without a classified mismatch. Inspect $RUNTIME_DIR before cleanup."
