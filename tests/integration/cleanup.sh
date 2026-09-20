#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="$SCRIPT_DIR/.runtime"
ENDPOINT_EXPECTED="http://localhost:4566"

: "${AWS_COMPATIBLE_ENDPOINT:?Set AWS_COMPATIBLE_ENDPOINT explicitly.}"
if [[ "$AWS_COMPATIBLE_ENDPOINT" != "$ENDPOINT_EXPECTED" || "$AWS_COMPATIBLE_ENDPOINT" == *amazonaws.com* ]]; then
  echo "Refusing cleanup: AWS_COMPATIBLE_ENDPOINT is not the approved local endpoint." >&2
  exit 1
fi

if [[ ! -d "$RUNTIME_DIR" ]]; then
  echo "No integration runtime directory exists; nothing to clean."
  exit 0
fi

export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_REGION="eu-west-1"
export AWS_DEFAULT_REGION="eu-west-1"
export AWS_EC2_METADATA_DISABLED="true"
unset AWS_PROFILE AWS_DEFAULT_PROFILE AWS_SESSION_TOKEN AWS_WEB_IDENTITY_TOKEN_FILE AWS_ROLE_ARN

destroy_phase() {
  local name="$1"
  local root="$SCRIPT_DIR/terraform/$2"
  local vars_file="$RUNTIME_DIR/vars/$3.tfvars.json"
  local state_file="$RUNTIME_DIR/state/$4.tfstate"
  local data_dir="$RUNTIME_DIR/terraform-data/$4"

  [[ -f "$state_file" && -f "$vars_file" ]] || return 0
  echo "Destroying $name..."
  TF_DATA_DIR="$data_dir" terraform -chdir="$root" destroy -auto-approve -input=false -no-color -state="$state_file" -var-file="$vars_file"
}

cleanup_failed=0
failed_phases=()

if ! destroy_phase "organization CloudTrail" cloudtrail cloudtrail cloudtrail; then
  cleanup_failed=1
  failed_phases+=("organization CloudTrail")
fi
if ! destroy_phase "delegated admin" delegated-admin delegated-admin delegated-admin; then
  cleanup_failed=1
  failed_phases+=("delegated admin")
fi
if ! destroy_phase "trusted access" trusted-access trusted-access trusted-access; then
  cleanup_failed=1
  failed_phases+=("trusted access")
fi
if ! destroy_phase "SCP policy creation and attachment" scp scp scp; then
  cleanup_failed=1
  failed_phases+=("SCP policy creation and attachment")
fi
if ! destroy_phase "Log Archive S3/KMS storage" log-archive log-archive log-archive; then
  cleanup_failed=1
  failed_phases+=("Log Archive S3/KMS storage")
fi
if ! destroy_phase "account vending" account-vending account-vending account-vending; then
  cleanup_failed=1
  failed_phases+=("account vending")
fi
if ! destroy_phase "organization" organization organization organization; then
  cleanup_failed=1
  failed_phases+=("organization")
fi

if [[ "$cleanup_failed" -ne 0 ]]; then
  printf 'Cleanup failed for: %s\n' "${failed_phases[*]}" >&2
  echo "Preserving $RUNTIME_DIR for inspection and retry." >&2
  exit 1
fi

find "$SCRIPT_DIR/terraform" -type d -name .terraform -prune -exec rm -rf {} +
find "$SCRIPT_DIR/terraform" -type f -name .terraform.lock.hcl -delete
rm -rf "$RUNTIME_DIR"
echo "Integration runtime and local resources cleaned up."
