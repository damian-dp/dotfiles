#!/bin/zsh
# OpenCode + OpenChamber shell helpers

OPENCHAMBER_PORT="${OPENCHAMBER_PORT:-3000}"
OPENCODE_VM_HOST="${OPENCODE_VM_HOST:-dev-vm-team.taild53693.ts.net}"

# oc - OpenChamber web server management
oc() {
  case "${1:-help}" in
    serve|start)
      shift
      local daemon_flag=""
      [[ "$1" == "-d" || "$1" == "--daemon" ]] && daemon_flag="--daemon"
      
      openchamber --port "$OPENCHAMBER_PORT" $daemon_flag &
      
      # Wait for ready, then setup Tailscale
      for i in {1..30}; do
        curl -s "http://localhost:$OPENCHAMBER_PORT" >/dev/null 2>&1 && break
        sleep 1
      done
      
      tailscale serve --bg --https=443 "http://localhost:$OPENCHAMBER_PORT" 2>/dev/null
      echo "OpenChamber: http://localhost:$OPENCHAMBER_PORT"
      echo "Remote:      https://$(tailscale status --self --json 2>/dev/null | jq -r '.Self.DNSName' | sed 's/\.$//')"
      ;;
    stop)
      openchamber stop
      tailscale serve --https=443 off 2>/dev/null
      ;;
    status)
      openchamber status
      ;;
    url)
      echo "https://$(tailscale status --self --json 2>/dev/null | jq -r '.Self.DNSName' | sed 's/\.$//')"
      ;;
    vm)
      open "https://$OPENCODE_VM_HOST" 2>/dev/null || echo "https://$OPENCODE_VM_HOST"
      ;;
    *)
      echo "oc serve    Start OpenChamber + Tailscale"
      echo "oc stop     Stop server"
      echo "oc status   Show status"  
      echo "oc url      Print remote URL"
      echo "oc vm       Open VM web UI"
      ;;
  esac
}
