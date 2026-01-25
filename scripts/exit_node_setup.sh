#!/usr/bin/env bash
#
# exit_node_setup.sh - Configure a Linux server as a Tailscale exit node
#
# This script configures all the kernel and network settings needed to run
# a Tailscale exit node with optimal performance. Run this after Tailscale
# is installed and authenticated.
#
# What it does:
#   1. Enables IPv4 and IPv6 forwarding (required for exit node)
#   2. Configures UDP GRO for better throughput (Linux 6.2+)
#   3. Makes all settings persistent across reboots
#   4. Advertises the node as a Tailscale exit node
#
# After running, approve the exit node in the Tailscale admin console:
#   https://login.tailscale.com/admin/machines
#
# Usage:
#   ./scripts/exit_node_setup.sh
#
# Requirements:
#   - Linux with systemd
#   - Tailscale installed and authenticated
#   - Root/sudo access
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &> /dev/null; then
            SUDO="sudo"
        else
            log_error "This script requires root privileges"
            exit 1
        fi
    else
        SUDO=""
    fi
}

check_tailscale() {
    if ! command -v tailscale &> /dev/null; then
        log_error "Tailscale is not installed. Run setup-tailscale.sh first."
        exit 1
    fi
    
    local status
    status=$(tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null || echo "Unknown")
    
    if [[ "$status" != "Running" ]]; then
        log_error "Tailscale is not connected. Run 'tailscale up' first."
        exit 1
    fi
    
    log_success "Tailscale is connected"
}

enable_ip_forwarding() {
    log_info "Enabling IP forwarding..."
    
    local sysctl_file="/etc/sysctl.d/99-tailscale.conf"
    
    $SUDO tee "$sysctl_file" > /dev/null << 'EOF'
# Enable IP forwarding for Tailscale exit node
# See: https://tailscale.com/kb/1103/exit-nodes

net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
    
    $SUDO sysctl -p "$sysctl_file" > /dev/null
    
    log_success "IP forwarding enabled and persisted"
}

configure_udp_gro() {
    log_info "Configuring UDP GRO for optimal throughput..."
    
    # Get the primary network interface
    local netdev
    netdev=$(ip -o route get 8.8.8.8 | cut -f 5 -d " ")
    
    if [[ -z "$netdev" ]]; then
        log_warn "Could not detect primary network interface, skipping UDP GRO"
        return
    fi
    
    log_info "Primary interface: $netdev"
    
    # Check if ethtool is available
    if ! command -v ethtool &> /dev/null; then
        log_warn "ethtool not installed, skipping UDP GRO optimization"
        log_info "Install with: apt install ethtool"
        return
    fi
    
    # Apply UDP GRO settings
    $SUDO ethtool -K "$netdev" rx-udp-gro-forwarding on rx-gro-list off 2>/dev/null || {
        log_warn "Could not set UDP GRO (may require Linux 6.2+)"
        return
    }
    
    log_success "UDP GRO forwarding enabled on $netdev"
    
    # Make persistent via networkd-dispatcher if available
    if systemctl is-enabled networkd-dispatcher &>/dev/null; then
        local script_path="/etc/networkd-dispatcher/routable.d/50-tailscale"
        
        $SUDO tee "$script_path" > /dev/null << EOF
#!/bin/sh
# Tailscale exit node UDP GRO optimization
# See: https://tailscale.com/kb/1320/performance-best-practices

ethtool -K $netdev rx-udp-gro-forwarding on rx-gro-list off
EOF
        
        $SUDO chmod 755 "$script_path"
        log_success "UDP GRO settings will persist across reboots"
    else
        log_warn "networkd-dispatcher not available - UDP GRO won't persist after reboot"
        log_info "Add to /etc/rc.local: ethtool -K $netdev rx-udp-gro-forwarding on rx-gro-list off"
    fi
}

advertise_exit_node() {
    log_info "Advertising as Tailscale exit node..."
    
    $SUDO tailscale up --advertise-exit-node
    
    log_success "Exit node advertised"
}

show_status() {
    echo ""
    echo "========================================"
    echo "  Exit Node Configuration Complete"
    echo "========================================"
    echo ""
    
    local ip4
    ip4=$(tailscale ip -4 2>/dev/null || echo "N/A")
    
    echo "  Tailscale IP: $ip4"
    echo "  Hostname: $(tailscale status --json | jq -r '.Self.DNSName' | sed 's/\.$//')"
    echo ""
    
    log_warn "IMPORTANT: Approve this exit node in the Tailscale admin console:"
    echo "  https://login.tailscale.com/admin/machines"
    echo ""
    log_info "To use this exit node from another device:"
    echo "  tailscale up --exit-node=$ip4"
    echo ""
}

main() {
    echo ""
    echo "========================================"
    echo "  Tailscale Exit Node Setup"
    echo "========================================"
    echo ""
    
    check_root
    check_tailscale
    enable_ip_forwarding
    configure_udp_gro
    advertise_exit_node
    show_status
}

main "$@"
