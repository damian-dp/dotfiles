#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

context="auto"
if [[ "${1:-}" =~ ^(auto|mac|vm|linux-client)$ ]]; then
  context="$1"
  shift
fi

no_masking=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-masking)
      no_masking=true
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Usage: $0 [auto|mac|vm|linux-client] [--no-masking] -- <command> [args...]" >&2
      exit 2
      ;;
  esac
done

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 [auto|mac|vm|linux-client] [--no-masking] -- <command> [args...]" >&2
  exit 2
fi

resolve_context() {
  case "$context" in
    auto)
      if [[ "$(uname -s)" == "Darwin" ]]; then
        printf 'mac\n'
      elif [[ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" || -f "$HOME/.config/op/service-account-token" ]]; then
        printf 'vm\n'
      else
        printf 'linux-client\n'
      fi
      ;;
    *)
      printf '%s\n' "$context"
      ;;
  esac
}

resolved_context="$(resolve_context)"

if ! command -v op >/dev/null 2>&1; then
  echo "op is required to resolve secret references." >&2
  exit 1
fi

if [[ "$resolved_context" == "vm" && -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" && -f "$HOME/.config/op/service-account-token" ]]; then
  export OP_SERVICE_ACCOUNT_TOKEN
  OP_SERVICE_ACCOUNT_TOKEN="$(cat "$HOME/.config/op/service-account-token")"
fi

masking_flag=()
if $no_masking; then
  masking_flag=(--no-masking)
fi

# Resolve a single env file with op, printing KEY=VALUE lines to stdout.
resolve_env_file() {
  local env_file="$1"
  local account="${2:-}"
  local acct_flag=()
  if [[ -n "$account" ]]; then
    acct_flag=(--account "$account")
  fi
  op "${acct_flag[@]}" run "${masking_flag[@]}" --env-file="$env_file" -- env
}

case "$resolved_context" in
  mac)
    # On macOS, secrets span two 1Password accounts:
    #   common.env → personal account (my.1password.com)
    #   mac.env    → work account (tiltlegal.1password.com)
    # Resolve each with the correct account, then merge and exec.
    common_env="$REPO_ROOT/secrets/refs/common.env"
    mac_env="$REPO_ROOT/secrets/refs/mac.env"

    resolved_vars=""
    if [[ -f "$common_env" ]]; then
      resolved_vars+="$(resolve_env_file "$common_env" my)"$'\n'
    fi
    if [[ -f "$mac_env" ]]; then
      resolved_vars+="$(resolve_env_file "$mac_env" tiltlegal)"$'\n'
    fi

    # Extract only the keys defined in our env files and export them.
    wanted_keys=()
    for env_file in "$common_env" "$mac_env"; do
      if [[ -f "$env_file" ]]; then
        while IFS= read -r line; do
          [[ "$line" =~ ^[[:space:]]*# ]] && continue
          [[ -z "$line" ]] && continue
          wanted_keys+=("${line%%=*}")
        done < "$env_file"
      fi
    done

    for key in "${wanted_keys[@]}"; do
      value="$(grep "^${key}=" <<< "$resolved_vars" | tail -1 | cut -d= -f2-)"
      if [[ -n "$value" ]]; then
        export "$key=$value"
      fi
    done

    exec "$@"
    ;;

  vm)
    env_files=("$REPO_ROOT/secrets/refs/common.env" "$REPO_ROOT/secrets/refs/vm.env")
    op_run_args=(run "${masking_flag[@]}")
    for env_file in "${env_files[@]}"; do
      if [[ -f "$env_file" ]]; then
        op_run_args+=("--env-file=$env_file")
      fi
    done
    exec op "${op_run_args[@]}" -- "$@"
    ;;

  linux-client)
    op_run_args=(run "${masking_flag[@]}")
    env_file="$REPO_ROOT/secrets/refs/common.env"
    if [[ -f "$env_file" ]]; then
      op_run_args+=("--env-file=$env_file")
    fi
    exec op "${op_run_args[@]}" -- "$@"
    ;;

  *)
    echo "Unknown secret context: $resolved_context" >&2
    exit 2
    ;;
esac
