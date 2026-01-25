#!/bin/zsh
# OpenCode wrapper with remote access via Tailscale
# Single server, multiple projects, accessible from anywhere

OPENCODE_BIN="$HOME/.opencode/bin/opencode"
OPENCODE_PORT="${OPENCODE_PORT:-5551}"
OPENCODE_PID_FILE="$HOME/.opencode/server.pid"
OPENCODE_LOG_FILE="$HOME/.opencode/server.log"

opencode() {
  if [[ ! -x "$OPENCODE_BIN" ]]; then
    echo "OpenCode not found. Installing..."
    curl -fsSL https://opencode.ai/install | bash
    if [[ ! -x "$OPENCODE_BIN" ]]; then
      echo "Failed to install OpenCode"
      return 1
    fi
  fi
  "$OPENCODE_BIN" "$@"
}

oc() {
  local cmd="${1:-status}"
  shift 2>/dev/null || true
  
  case "$cmd" in
    serve|start)
      _oc_start "$@"
      ;;
    stop)
      _oc_stop
      ;;
    restart)
      _oc_stop
      sleep 1
      _oc_start "$@"
      ;;
    attach)
      _oc_attach "$@"
      ;;
    status)
      _oc_status
      ;;
    logs)
      if [[ -f "$OPENCODE_LOG_FILE" ]]; then
        tail -f "$OPENCODE_LOG_FILE"
      else
        echo "No log file found"
      fi
      ;;
    url)
      _oc_url
      ;;
    *)
      echo "Usage: oc <command>"
      echo ""
      echo "Commands:"
      echo "  serve    Start opencode web server with Tailscale"
      echo "  stop     Stop server and remove Tailscale serve"
      echo "  restart  Restart server"
      echo "  attach   Attach terminal to running server"
      echo "  status   Show server status (default)"
      echo "  logs     Follow server logs"
      echo "  url      Print remote URL"
      ;;
  esac
}

_oc_start() {
  if _oc_is_running; then
    echo "OpenCode server already running (PID: $(cat "$OPENCODE_PID_FILE"))"
    _oc_status
    return 0
  fi
  
  echo "Starting OpenCode web server on port $OPENCODE_PORT..."
  mkdir -p "$(dirname "$OPENCODE_LOG_FILE")"
  
  nohup "$OPENCODE_BIN" web \
    --hostname 0.0.0.0 \
    --port "$OPENCODE_PORT" \
    > "$OPENCODE_LOG_FILE" 2>&1 &
  
  local pid=$!
  echo $pid > "$OPENCODE_PID_FILE"
  
  echo "Waiting for server to start..."
  local max_attempts=30
  local attempt=0
  while [[ $attempt -lt $max_attempts ]]; do
    if curl -s "http://localhost:$OPENCODE_PORT" > /dev/null 2>&1; then
      break
    fi
    sleep 1
    ((attempt++))
  done
  
  if ! curl -s "http://localhost:$OPENCODE_PORT" > /dev/null 2>&1; then
    echo "Failed to start server. Check logs: $OPENCODE_LOG_FILE"
    return 1
  fi
  
  echo "Configuring Tailscale serve..."
  tailscale serve --bg --https=443 "http://localhost:$OPENCODE_PORT" 2>/dev/null
  
  echo ""
  _oc_status
}

_oc_stop() {
  echo "Removing Tailscale serve..."
  tailscale serve --https=443 off 2>/dev/null || true
  
  if [[ -f "$OPENCODE_PID_FILE" ]]; then
    local pid=$(cat "$OPENCODE_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      echo "Stopping OpenCode server (PID: $pid)..."
      kill "$pid" 2>/dev/null
      local max_attempts=10
      local attempt=0
      while kill -0 "$pid" 2>/dev/null && [[ $attempt -lt $max_attempts ]]; do
        sleep 1
        ((attempt++))
      done
      if kill -0 "$pid" 2>/dev/null; then
        echo "Force killing..."
        kill -9 "$pid" 2>/dev/null
      fi
    fi
    rm -f "$OPENCODE_PID_FILE"
  fi
  
  echo "Stopped."
}

_oc_attach() {
  if ! _oc_is_running; then
    echo "OpenCode server not running. Start with: oc serve"
    return 1
  fi
  
  local dir="${1:-.}"
  echo "Attaching to OpenCode server..."
  "$OPENCODE_BIN" attach "http://localhost:$OPENCODE_PORT" --dir "$dir"
}

_oc_status() {
  if _oc_is_running; then
    local pid=$(cat "$OPENCODE_PID_FILE")
    echo "OpenCode server: running (PID: $pid)"
    echo "  Local:  http://localhost:$OPENCODE_PORT"
    
    local ts_status=$(tailscale serve status 2>/dev/null)
    if [[ -n "$ts_status" && "$ts_status" != "No serve config" ]]; then
      local hostname=$(tailscale status --self --json 2>/dev/null | jq -r '.Self.DNSName' | sed 's/\.$//')
      echo "  Remote: https://$hostname"
    else
      echo "  Remote: not configured (run 'oc serve' to enable)"
    fi
  else
    echo "OpenCode server: stopped"
    echo "  Run 'oc serve' to start"
  fi
}

_oc_url() {
  local hostname=$(tailscale status --self --json 2>/dev/null | jq -r '.Self.DNSName' | sed 's/\.$//')
  if [[ -n "$hostname" ]]; then
    echo "https://$hostname"
  else
    echo "Tailscale not configured"
    return 1
  fi
}

_oc_is_running() {
  if [[ -f "$OPENCODE_PID_FILE" ]]; then
    local pid=$(cat "$OPENCODE_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}
