#!/bin/zsh
# OpenCode + OpenChamber helpers
# OpenChamber provides the web UI, OpenCode CLI for terminal
# Both accessible locally and remotely via Tailscale

OPENCODE_BIN="$HOME/.opencode/bin/opencode"
OPENCHAMBER_PORT="${OPENCHAMBER_PORT:-3000}"
OPENCODE_VM_HOST="${OPENCODE_VM_HOST:-dev-vm-team.taild53693.ts.net}"

# Ensure OpenCode CLI is installed
_ensure_opencode() {
  if [[ ! -x "$OPENCODE_BIN" ]]; then
    echo "OpenCode CLI not found. Installing..."
    curl -fsSL https://opencode.ai/install | bash
    if [[ ! -x "$OPENCODE_BIN" ]]; then
      echo "Failed to install OpenCode CLI"
      return 1
    fi
  fi
}

# Main opencode command - for TUI usage
opencode() {
  _ensure_opencode || return 1
  
  # Connect to VM
  if [[ "$1" == "--vm" ]]; then
    shift
    echo "Connecting to VM: https://$OPENCODE_VM_HOST"
    open "https://$OPENCODE_VM_HOST" 2>/dev/null || echo "Open in browser: https://$OPENCODE_VM_HOST"
    return
  fi
  
  # Pass through to opencode CLI
  "$OPENCODE_BIN" "$@"
}

# OpenChamber web UI commands
oc() {
  local cmd="${1:-status}"
  shift 2>/dev/null || true
  
  case "$cmd" in
    serve|start)
      _oc_start "$@"
      ;;
    stop)
      openchamber stop
      tailscale serve --https=443 off 2>/dev/null || true
      echo "Stopped."
      ;;
    restart)
      openchamber restart "$@"
      ;;
    status)
      openchamber status
      _oc_tailscale_status
      ;;
    url)
      _oc_url
      ;;
    logs)
      # OpenChamber logs to stdout in non-daemon mode
      echo "OpenChamber runs in foreground by default."
      echo "Use 'oc serve --daemon' for background mode."
      ;;
    web)
      # Open web UI in browser
      local url="http://localhost:$OPENCHAMBER_PORT"
      echo "Opening: $url"
      open "$url" 2>/dev/null || echo "Open in browser: $url"
      ;;
    *)
      echo "Usage: oc <command>"
      echo ""
      echo "Commands:"
      echo "  serve    Start OpenChamber web server with Tailscale"
      echo "  stop     Stop server and remove Tailscale serve"
      echo "  restart  Restart server"
      echo "  status   Show server status"
      echo "  url      Print remote URL"
      echo "  web      Open web UI in browser"
      echo ""
      echo "For TUI: use 'opencode' directly"
      ;;
  esac
}

_oc_start() {
  local daemon_flag=""
  if [[ "$1" == "-d" ]] || [[ "$1" == "--daemon" ]]; then
    daemon_flag="--daemon"
    shift
  fi
  
  echo "Starting OpenChamber on port $OPENCHAMBER_PORT..."
  openchamber --port "$OPENCHAMBER_PORT" $daemon_flag &
  local pid=$!
  
  # Wait for server to be ready
  local max_attempts=30
  local attempt=0
  while [[ $attempt -lt $max_attempts ]]; do
    if curl -s "http://localhost:$OPENCHAMBER_PORT" > /dev/null 2>&1; then
      break
    fi
    sleep 1
    ((attempt++))
  done
  
  if curl -s "http://localhost:$OPENCHAMBER_PORT" > /dev/null 2>&1; then
    # Setup Tailscale serve for remote access
    tailscale serve --bg --https=443 "http://localhost:$OPENCHAMBER_PORT" 2>/dev/null
    echo ""
    _oc_status_info
  else
    echo "Failed to start server."
    return 1
  fi
}

_oc_tailscale_status() {
  local ts_status=$(tailscale serve status 2>/dev/null)
  if [[ -n "$ts_status" && "$ts_status" != "No serve config" ]]; then
    local hostname=$(tailscale status --self --json 2>/dev/null | jq -r '.Self.DNSName' | sed 's/\.$//')
    echo "Remote: https://$hostname"
  fi
}

_oc_status_info() {
  echo "OpenChamber running:"
  echo "  Local:  http://localhost:$OPENCHAMBER_PORT"
  _oc_tailscale_status
}

_oc_url() {
  local hostname=$(tailscale status --self --json 2>/dev/null | jq -r '.Self.DNSName' | sed 's/\.$//')
  if [[ -n "$hostname" && "$hostname" != "null" ]]; then
    echo "https://$hostname"
  else
    echo "Tailscale not configured"
    return 1
  fi
}
