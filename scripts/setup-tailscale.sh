#!/usr/bin/env bash
#
# setup-tailscale.sh - Configure Tailscale on a new machine
#
# This script handles Tailscale setup for non-NixOS Linux systems where
# home-manager can't manage system services. For NixOS, use the native
# services.tailscale module instead.
#
# Authentication is via Google OAuth - the script will provide a URL to
# open in your browser for login.
#
# Usage:
#   ./scripts/setup-tailscale.sh              # Standard setup
#   ./scripts/setup-tailscale.sh --ssh        # Enable Tailscale SSH
#
# Options:
#   --hostname NAME   Override hostname (default: system hostname)
#   --ssh             Enable Tailscale SSH
#   --accept-routes   Accept routes from other nodes
#   --exit-node       Advertise as exit node
#   --help            Show this help message
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

HOSTNAME=""
ENABLE_SSH=false
ACCEPT_ROUTES=false
EXIT_NODE=false

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

show_help() {
    sed -n '2,/^$/p' "$0" | sed 's/^# //' | sed 's/^#//'
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --hostname)
                HOSTNAME="$2"
                shift 2
                ;;
            --ssh)
                ENABLE_SSH=true
                shift
                ;;
            --accept-routes)
                ACCEPT_ROUTES=true
                shift
                ;;
            --exit-node)
                EXIT_NODE=true
                shift
                ;;
            --help|-h)
                show_help
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "${ID:-linux}"
    else
        echo "linux"
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &> /dev/null; then
            SUDO="sudo"
        else
            log_error "This script requires root privileges. Please run with sudo."
            exit 1
        fi
    else
        SUDO=""
    fi
}

install_tailscale() {
    local os="$1"
    
    log_info "Checking if Tailscale is installed..."
    
    if command -v tailscale &> /dev/null; then
        log_success "Tailscale is already installed: $(tailscale version | head -1)"
        return 0
    fi
    
    log_info "Installing Tailscale for $os..."
    
    case "$os" in
        macos)
            if command -v brew &> /dev/null; then
                brew install --cask tailscale
            else
                log_error "Homebrew not found. Please install Tailscale from https://tailscale.com/download"
                exit 1
            fi
            ;;
        ubuntu|debian|pop)
            curl -fsSL https://tailscale.com/install.sh | $SUDO sh
            ;;
        fedora|centos|rhel)
            curl -fsSL https://tailscale.com/install.sh | $SUDO sh
            ;;
        arch|manjaro)
            $SUDO pacman -S --noconfirm tailscale
            $SUDO systemctl enable --now tailscaled
            ;;
        *)
            log_warn "Unknown OS. Attempting generic install script..."
            curl -fsSL https://tailscale.com/install.sh | $SUDO sh
            ;;
    esac
    
    log_success "Tailscale installed successfully"
}

start_daemon() {
    local os="$1"
    
    log_info "Ensuring Tailscale daemon is running..."
    
    case "$os" in
        macos)
            # macOS uses launchd, Tailscale.app handles this
            if ! pgrep -x "Tailscale" > /dev/null; then
                log_warn "Please open Tailscale.app from Applications"
            fi
            ;;
        *)
            # Linux uses systemd
            if command -v systemctl &> /dev/null; then
                $SUDO systemctl enable tailscaled 2>/dev/null || true
                $SUDO systemctl start tailscaled 2>/dev/null || true
                
                # Wait for daemon to be ready
                sleep 2
                
                if systemctl is-active --quiet tailscaled; then
                    log_success "Tailscale daemon is running"
                else
                    log_error "Failed to start Tailscale daemon"
                    exit 1
                fi
            else
                log_warn "systemd not found. Please start tailscaled manually."
            fi
            ;;
    esac
}

check_status() {
    log_info "Checking Tailscale status..."
    
    local status
    status=$(tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null || echo "Unknown")
    
    case "$status" in
        Running)
            log_success "Tailscale is already connected!"
            tailscale status
            return 0
            ;;
        NeedsLogin|Stopped)
            log_info "Tailscale needs authentication"
            return 1
            ;;
        *)
            log_info "Tailscale status: $status"
            return 1
            ;;
    esac
}

authenticate() {
    local up_args=()
    
    if [[ -n "$HOSTNAME" ]]; then
        up_args+=("--hostname=$HOSTNAME")
    fi
    
    if [[ "$ENABLE_SSH" == true ]]; then
        up_args+=("--ssh")
    fi
    
    if [[ "$ACCEPT_ROUTES" == true ]]; then
        up_args+=("--accept-routes")
    fi
    
    if [[ "$EXIT_NODE" == true ]]; then
        up_args+=("--advertise-exit-node")
    fi
    
    log_info "Connecting to Tailscale..."
    log_info "A URL will be displayed - open it in your browser to authenticate with Google"
    echo ""
    
    $SUDO tailscale up "${up_args[@]}"
    
    log_success "Successfully connected to Tailscale!"
}

show_info() {
    echo ""
    log_info "Tailscale connection info:"
    echo "----------------------------------------"
    tailscale ip -4 2>/dev/null && echo "  IPv4: $(tailscale ip -4)"
    tailscale ip -6 2>/dev/null && echo "  IPv6: $(tailscale ip -6)" || true
    echo "  Hostname: $(tailscale status --json | jq -r '.Self.DNSName' | sed 's/\.$//')"
    echo "----------------------------------------"
    echo ""
    log_info "You can now access this machine via Tailscale!"
    
    if [[ "$ENABLE_SSH" == true ]]; then
        log_info "Tailscale SSH is enabled. Connect with: ssh $(tailscale status --json | jq -r '.Self.DNSName' | sed 's/\.$//')"
    fi
}

main() {
    parse_args "$@"
    
    echo ""
    echo "========================================"
    echo "  Tailscale Setup Script"
    echo "========================================"
    echo ""
    
    local os
    os=$(detect_os)
    log_info "Detected OS: $os"
    
    check_root
    install_tailscale "$os"
    start_daemon "$os"
    
    if check_status; then
        show_info
        exit 0
    fi
    
    authenticate
    show_info
}

main "$@"
