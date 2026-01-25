opencode() {
  local host="127.0.0.1"
  local port="4096"
  local op_bin="/opt/homebrew/bin/opencode"

  if [[ ! -x "$op_bin" ]]; then
    echo "Couldn't execute $op_bin"
    return 127
  fi

  if ! command -v tailscale >/dev/null 2>&1; then
    echo "tailscale CLI not found."
    return 127
  fi
  if ! tailscale status >/dev/null 2>&1; then
    echo "Tailscale doesn't look connected. Turn it on first."
    return 1
  fi

  # Ensure Serve is enabled at ROOT (tailnet-only HTTPS)
  tailscale serve --bg --yes "$port" >/dev/null 2>&1 || true

  local local_url="http://127.0.0.1:${port}/"
  local base_url=""
  base_url="$(tailscale serve status 2>/dev/null | /usr/bin/sed -nE 's/^[[:space:]]*(https:\/\/[^[:space:]]+).*/\1/p' | /usr/bin/head -n 1)"
  local phone_url="${base_url}/"

  # macOS notification (click opens local UI)
  if command -v terminal-notifier >/dev/null 2>&1; then
    terminal-notifier \
      -title "OpenCode" \
      -message "Click to open local UI" \
      -open "$local_url" \
      >/dev/null 2>&1 || true
  fi

  # iPhone push via Bark (tap opens tailnet UI) — uses OpenCode repo icon (raw PNG)
  if [[ -n "${BARK_KEY:-}" && -n "$base_url" ]]; then
    local icon_url="https://pbs.twimg.com/profile_images/1973794620233433088/nBn75BTm_400x400.png"

    # URL-encode params (Ruby is available on macOS)
    local enc_open enc_icon
    enc_open="$(/usr/bin/ruby -ruri -e 'puts URI.encode_www_form_component(ARGV[0])' "$phone_url" 2>/dev/null)"
    enc_icon="$(/usr/bin/ruby -ruri -e 'puts URI.encode_www_form_component(ARGV[0])' "$icon_url" 2>/dev/null)"

    # Title/Body in the path; everything else in query params
    /usr/bin/curl -fsS \
      "https://api.day.app/${BARK_KEY}/OpenCode/Open%20session%20ready?url=${enc_open}&icon=${enc_icon}&group=opencode&level=active&sound=minuet&badge=0&autoCopy=1&copy=${enc_open}&isArchive=1" \
      >/dev/null 2>&1 || true
  fi

  # Prevent sleep while this TUI is open
  local caf_pid=""
  if command -v caffeinate >/dev/null 2>&1; then
    caffeinate -dimsu >/dev/null 2>&1 &
    caf_pid=$!
  fi
  trap 'if [[ -n "'"$caf_pid"'" ]]; then kill "'"$caf_pid"'" >/dev/null 2>&1 || true; fi' EXIT INT TERM

  # If server already running on 4096, attach; otherwise start
  if command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    "$op_bin" attach "http://127.0.0.1:${port}" "$@"
  else
    "$op_bin" --hostname "$host" --port "$port" "$@"
  fi
}
