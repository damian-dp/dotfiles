#!/bin/zsh
# OpenCode wrapper with local/VM mode support
# Manages OpenCode server and OpenCode Manager (web UI)

# Configuration - set VM_HOST in ~/.secrets or here
OPENCODE_VM_HOST="${OPENCODE_VM_HOST:-}"
OPENCODE_MANAGER_DIR="${OPENCODE_MANAGER_DIR:-$HOME/.config/opencode-manager}"
OPENCODE_BIN="$HOME/.opencode/bin/opencode"

opencode() {
  local vm_mode=false
  local args=()
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --vm)
        vm_mode=true
        shift
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done
  
  if [[ ! -x "$OPENCODE_BIN" ]]; then
    echo "OpenCode not found. Installing..."
    curl -fsSL https://opencode.ai/install | bash
    if [[ ! -x "$OPENCODE_BIN" ]]; then
      echo "Failed to install OpenCode"
      return 1
    fi
  fi
  
  if [[ "$vm_mode" == true ]]; then
    if [[ -z "$OPENCODE_VM_HOST" ]]; then
      echo "Error: OPENCODE_VM_HOST not set"
      echo "Add to ~/.secrets: export OPENCODE_VM_HOST='your-vm.tailnet'"
      return 1
    fi
    
    if ! command -v tailscale >/dev/null 2>&1; then
      echo "Error: Tailscale not installed"
      return 1
    fi
    
    if ! tailscale status >/dev/null 2>&1; then
      echo "Error: Tailscale not connected"
      return 1
    fi
    
    echo "Connecting to VM: $OPENCODE_VM_HOST"
    "$OPENCODE_BIN" attach "https://${OPENCODE_VM_HOST}:4096" "${args[@]}"
  else
    "$OPENCODE_BIN" "${args[@]}"
  fi
}

ocm() {
  local cmd="${1:-status}"
  shift 2>/dev/null || true
  local compose_file="$OPENCODE_MANAGER_DIR/docker-compose.yml"
  
  case "$cmd" in
    start)
      if [[ -z "$AUTH_SECRET" ]]; then
        export AUTH_SECRET=$(openssl rand -base64 32)
      fi
      echo "Starting OpenCode Manager (local)..."
      AUTH_SECRET="$AUTH_SECRET" ADMIN_EMAIL="$ADMIN_EMAIL" ADMIN_PASSWORD="$ADMIN_PASSWORD" \
        docker-compose -f "$compose_file" --project-directory "$OPENCODE_MANAGER_DIR" --profile local up -d
      echo "OpenCode Manager: http://localhost:5003"
      ;;
    remote)
      if [[ -z "$TS_AUTHKEY" ]]; then
        echo "Error: TS_AUTHKEY not set"
        echo "Add to ~/.secrets: export TS_AUTHKEY=\$(op read \"op://Employee/Tailscale Auth Key/credential\" 2>/dev/null)"
        return 1
      fi
      if [[ -z "$AUTH_SECRET" ]]; then
        export AUTH_SECRET=$(openssl rand -base64 32)
      fi
      echo "Starting OpenCode Manager (remote with Tailscale)..."
      TS_AUTHKEY="$TS_AUTHKEY" AUTH_SECRET="$AUTH_SECRET" ADMIN_EMAIL="$ADMIN_EMAIL" ADMIN_PASSWORD="$ADMIN_PASSWORD" \
        docker-compose -f "$compose_file" --project-directory "$OPENCODE_MANAGER_DIR" --profile remote up -d
      echo "Waiting for Tailscale to authenticate..."
      sleep 10
      local ts_hostname=$(docker exec opencode-tailscale tailscale status --json 2>/dev/null | jq -r '.Self.DNSName' | sed 's/\.$//')
      if [[ -n "$ts_hostname" ]]; then
        echo "OpenCode Manager: https://$ts_hostname"
      else
        echo "Tailscale still starting. Check: docker logs opencode-tailscale"
      fi
      ;;
    stop)
      echo "Stopping OpenCode Manager..."
      docker-compose -f "$compose_file" --project-directory "$OPENCODE_MANAGER_DIR" --profile local --profile remote down
      ;;
    restart)
      ocm stop
      ocm start
      ;;
    logs)
      docker-compose -f "$compose_file" --project-directory "$OPENCODE_MANAGER_DIR" --profile local --profile remote logs -f
      ;;
    status)
      if docker ps --format '{{.Names}}' | grep -q '^opencode-manager$'; then
        echo "OpenCode Manager: running"
        if docker ps --format '{{.Names}}' | grep -q '^opencode-tailscale$'; then
          local ts_hostname=$(docker exec opencode-tailscale tailscale status --json 2>/dev/null | jq -r '.Self.DNSName' | sed 's/\.$//')
          echo "  Mode: remote (Tailscale)"
          echo "  Web UI: https://$ts_hostname"
        else
          echo "  Mode: local"
          echo "  Web UI: http://localhost:5003"
        fi
        docker ps --filter name=opencode --format 'table {{.Names}}\t{{.Status}}'
      else
        echo "OpenCode Manager: stopped"
        echo "  Run 'ocm start' for local mode"
        echo "  Run 'ocm remote' for Tailscale mode"
      fi
      ;;
    update)
      echo "Updating OpenCode Manager..."
      docker-compose -f "$compose_file" --project-directory "$OPENCODE_MANAGER_DIR" pull
      ocm restart
      ;;
    shell)
      docker exec -it opencode-manager sh
      ;;
    *)
      echo "Usage: ocm <command>"
      echo ""
      echo "Commands:"
      echo "  start    Start locally (http://localhost:5003)"
      echo "  remote   Start with Tailscale (https://hostname.tailnet)"
      echo "  stop     Stop all containers"
      echo "  restart  Restart containers"
      echo "  status   Show status (default)"
      echo "  logs     Follow logs"
      echo "  update   Pull latest image and restart"
      echo "  shell    Open shell in container"
      ;;
  esac
}
