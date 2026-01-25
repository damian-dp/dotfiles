#!/bin/zsh

OPENCHAMBER_PORT="${OPENCHAMBER_PORT:-3000}"
OPENCODE_VM_HOST="${OPENCODE_VM_HOST:-dev-vm-team.taild53693.ts.net}"
OPENCODE_BIN="$HOME/.opencode/bin/opencode"

_oc_is_running() {
  curl -s "http://localhost:$OPENCHAMBER_PORT" >/dev/null 2>&1
}

_oc_start_daemon() {
  openchamber --port "$OPENCHAMBER_PORT" --daemon >/dev/null 2>&1
  for i in {1..30}; do
    _oc_is_running && break
    sleep 1
  done
  tailscale serve --bg --https=443 "http://localhost:$OPENCHAMBER_PORT" 2>/dev/null
}

_oc_stop() {
  openchamber stop 2>/dev/null
  tailscale serve --https=443 off 2>/dev/null
}

opencode() {
  if [[ ! -x "$OPENCODE_BIN" ]]; then
    echo "Installing OpenCode..."
    curl -fsSL https://opencode.ai/install | bash
  fi

  if ! _oc_is_running; then
    echo "Starting OpenChamber..."
    _oc_start_daemon
    echo "Web: http://localhost:$OPENCHAMBER_PORT"
    echo "Remote: $(oc url 2>/dev/null)"
    echo ""
  fi

  "$OPENCODE_BIN" "$@"
}

oc() {
  case "${1:-help}" in
    serve|start)
      if _oc_is_running; then
        echo "Already running on port $OPENCHAMBER_PORT"
        oc status
      else
        _oc_start_daemon
        echo "OpenChamber: http://localhost:$OPENCHAMBER_PORT"
        echo "Remote:      $(oc url 2>/dev/null)"
      fi
      ;;
    stop)
      _oc_stop
      echo "Stopped."
      ;;
    status)
      if _oc_is_running; then
        echo "Running: http://localhost:$OPENCHAMBER_PORT"
        echo "Remote:  $(oc url 2>/dev/null)"
      else
        echo "Not running"
      fi
      ;;
    url)
      tailscale status --self --json 2>/dev/null | jq -r '"https://" + (.Self.DNSName | rtrimstr("."))'
      ;;
    vm)
      open "https://$OPENCODE_VM_HOST" 2>/dev/null || echo "https://$OPENCODE_VM_HOST"
      ;;
    *)
      echo "oc serve   Start OpenChamber + Tailscale"
      echo "oc stop    Stop server"
      echo "oc status  Show status"
      echo "oc url     Print remote URL"
      echo "oc vm      Open VM web UI"
      ;;
  esac
}
