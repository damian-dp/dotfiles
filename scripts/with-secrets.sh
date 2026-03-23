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

env_files=("$REPO_ROOT/secrets/refs/common.env")
case "$resolved_context" in
  mac)
    env_files+=("$REPO_ROOT/secrets/refs/mac.env")
    op_cmd=(op --account my)
    ;;
  vm)
    env_files+=("$REPO_ROOT/secrets/refs/vm.env")
    op_cmd=(op)
    ;;
  linux-client)
    op_cmd=(op)
    ;;
  *)
    echo "Unknown secret context: $resolved_context" >&2
    exit 2
    ;;
esac

op_run_args=(run)
if $no_masking; then
  op_run_args+=(--no-masking)
fi

for env_file in "${env_files[@]}"; do
  if [[ -f "$env_file" ]]; then
    op_run_args+=("--env-file=$env_file")
  fi
done

exec "${op_cmd[@]}" "${op_run_args[@]}" -- "$@"
