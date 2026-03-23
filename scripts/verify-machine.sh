#!/usr/bin/env bash
set -euo pipefail

role="${1:-auto}"
os="$(uname -s)"

pass_count=0
warn_count=0
fail_count=0

pass() {
  printf '[PASS] %s\n' "$1"
  pass_count=$((pass_count + 1))
}

warn() {
  printf '[WARN] %s\n' "$1"
  warn_count=$((warn_count + 1))
}

fail() {
  printf '[FAIL] %s\n' "$1"
  fail_count=$((fail_count + 1))
}

check_cmd() {
  local cmd="$1"
  local label="${2:-$1}"

  if command -v "$cmd" >/dev/null 2>&1; then
    pass "$label is installed ($(command -v "$cmd"))"
  else
    fail "$label is missing"
  fi
}

check_file() {
  local path="$1"
  local label="${2:-$1}"

  if [[ -e "$path" ]]; then
    pass "$label exists"
  else
    fail "$label is missing"
  fi
}

check_app() {
  local app_name="$1"
  local app_path="/Applications/$app_name"

  if [[ -d "$app_path" ]]; then
    pass "$app_name is installed"
  else
    fail "$app_name is missing from /Applications"
  fi
}

detect_role() {
  if [[ "$role" != "auto" ]]; then
    printf '%s\n' "$role"
    return
  fi

  if [[ "$os" == "Darwin" ]]; then
    printf 'mac\n'
    return
  fi

  if [[ -f "$HOME/.config/systemd/user/opencode.service" ]]; then
    printf 'vm\n'
    return
  fi

  printf 'linux-client\n'
}

check_psql_17() {
  if ! command -v psql >/dev/null 2>&1; then
    fail "psql is missing"
    return
  fi

  local version
  version="$(psql --version 2>/dev/null || true)"
  if [[ "$version" =~ PostgreSQL\ 17(\.|$) ]]; then
    pass "psql is PostgreSQL 17 ($version)"
  else
    fail "psql is not PostgreSQL 17 (${version:-unknown version})"
  fi
}

check_mas_app() {
  local id="$1"
  local name="$2"

  if ! command -v mas >/dev/null 2>&1; then
    warn "mas is not installed; cannot verify $name"
    return
  fi

  if ! mas account >/dev/null 2>&1; then
    warn "App Store account is not signed in; cannot verify $name"
    return
  fi

  if mas list 2>/dev/null | awk '{print $1}' | grep -qx "$id"; then
    pass "$name is installed through the App Store"
  else
    fail "$name is not installed through the App Store"
  fi
}

check_homebrew_cask() {
  local cask="$1"

  if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew is not installed; cannot verify cask $cask"
    return
  fi

  if brew list --cask 2>/dev/null | grep -qx "$cask"; then
    pass "Homebrew cask $cask is installed"
  else
    fail "Homebrew cask $cask is not installed"
  fi
}

check_tailscale() {
  check_cmd tailscale
  if tailscale status >/dev/null 2>&1; then
    pass "Tailscale is connected"
  else
    fail "Tailscale is not connected"
  fi
}

check_ai_clis() {
  for cmd in claude opencode codex bun; do
    if command -v "$cmd" >/dev/null 2>&1; then
      pass "$cmd is installed"
    else
      warn "$cmd is not installed"
    fi
  done

  if command -v vercel >/dev/null 2>&1; then
    pass "vercel is installed"
  else
    warn "vercel is not installed"
  fi
}

check_runtime_configs() {
  check_file "$HOME/.claude/settings.json" "Claude settings"
  check_file "$HOME/.codex/config.toml" "Codex config"
  check_file "$HOME/.config/opencode/opencode.json" "OpenCode config"
}

check_vm_firewall() {
  local ufw_status=""

  if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    ufw_status="$(sudo ufw status 2>/dev/null || true)"
  elif command -v ufw >/dev/null 2>&1; then
    ufw_status="$(ufw status 2>/dev/null || true)"
  fi

  if [[ -z "$ufw_status" ]]; then
    warn "Could not read ufw status"
    return
  fi

  if grep -q "Status: active" <<<"$ufw_status"; then
    pass "ufw is active"
  else
    fail "ufw is not active"
  fi

  if grep -Eq '4096/tcp[[:space:]]+DENY' <<<"$ufw_status"; then
    pass "Public TCP access to port 4096 is denied"
  else
    fail "Missing deny rule for public TCP access to port 4096"
  fi

  if grep -Eq '4096/tcp \(v6\)[[:space:]]+DENY' <<<"$ufw_status"; then
    pass "Public IPv6 TCP access to port 4096 is denied"
  else
    warn "Missing IPv6 deny rule for port 4096"
  fi

  if grep -Eq '4096/tcp[[:space:]]+ALLOW IN[[:space:]]+Anywhere on tailscale0' <<<"$ufw_status"; then
    pass "Port 4096 is allowed on tailscale0"
  else
    fail "Missing tailscale0 allow rule for port 4096"
  fi
}

check_opencode_service() {
  if ! command -v systemctl >/dev/null 2>&1; then
    fail "systemctl is missing"
    return
  fi

  if systemctl --user is-enabled opencode >/dev/null 2>&1; then
    pass "opencode user service is enabled"
  else
    fail "opencode user service is not enabled"
  fi

  if systemctl --user is-active opencode >/dev/null 2>&1; then
    pass "opencode user service is active"
  else
    fail "opencode user service is not active"
  fi

  if command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq '(^|:)4096$'; then
    pass "OpenCode is listening on TCP port 4096"
  else
    fail "Nothing is listening on TCP port 4096"
  fi
}

check_mac() {
  printf 'Role: mac\n'
  check_cmd op "1Password CLI"
  check_psql_17
  check_tailscale
  check_ai_clis
  check_runtime_configs
  check_file "$HOME/Library/Application Support/Cursor/User/settings.json" "Cursor settings"

  for cask in 1password ghostty tailscale-app zed cursor orbstack gitkraken arc google-chrome raycast lm-studio; do
    check_homebrew_cask "$cask"
  done

  for app in \
    "1Password.app" \
    "Ghostty.app" \
    "Tailscale.app" \
    "Zed.app" \
    "Cursor.app" \
    "OrbStack.app" \
    "GitKraken.app" \
    "Arc.app" \
    "Google Chrome.app" \
    "Raycast.app" \
    "LM Studio.app"
  do
    check_app "$app"
  done

  check_mas_app 985367838 "Microsoft Outlook"
  check_mas_app 1113153706 "Microsoft Teams"
}

check_linux_common() {
  printf 'Role: %s\n' "$1"
  check_cmd op "1Password CLI"
  check_tailscale
  check_ai_clis
  check_runtime_configs
  check_file "$HOME/.config/op/service-account-token" "1Password service account token file"
  check_file "$HOME/.ssh/id_ed25519_signing" "VM SSH private key"
  check_file "$HOME/.ssh/id_ed25519_signing.pub" "VM SSH public key"

  if [[ -x "$HOME/.local/bin/pnpm" ]]; then
    pass "pnpm wrapper is installed"
  else
    warn "pnpm wrapper is not installed"
  fi

  if [[ -x "$HOME/.local/bin/vercel" ]]; then
    pass "vercel wrapper is installed"
  else
    warn "vercel wrapper is not installed"
  fi
}

target_role="$(detect_role)"

case "$target_role" in
  mac)
    check_mac
    ;;
  vm)
    check_linux_common "vm"
    check_opencode_service
    check_vm_firewall
    ;;
  linux-client)
    check_linux_common "linux-client"
    ;;
  *)
    printf 'Unknown role: %s\n' "$target_role" >&2
    exit 2
    ;;
esac

printf '\nSummary: %d passed, %d warnings, %d failed\n' "$pass_count" "$warn_count" "$fail_count"

if (( fail_count > 0 )); then
  exit 1
fi
