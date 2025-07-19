#!/bin/bash

# Hetzner VPS Detection and Setup Helper
# This file provides Hetzner-specific functions

detect_hetzner() {
    # Check if running on Hetzner by looking for specific markers
    if [ -f /etc/hetzner-build-info ] || grep -q "Hetzner" /sys/class/dmi/id/sys_vendor 2>/dev/null || grep -q "hetzner" /etc/hostname 2>/dev/null; then
        export IS_HETZNER=true
        log_info "Detected Hetzner VPS environment"
        return 0
    fi
    
    # Check for Hetzner IP ranges (common Hetzner subnets)
    local ip=$(curl -s ifconfig.me 2>/dev/null)
    if [[ $ip =~ ^(5\.9\.|78\.46\.|88\.198\.|136\.243\.|138\.201\.|144\.76\.|148\.251\.|176\.9\.|188\.40\.|213\.239\.) ]]; then
        export IS_HETZNER=true
        log_info "Detected Hetzner VPS environment (by IP range)"
        return 0
    fi
    
    export IS_HETZNER=false
    return 1
}

# Hetzner-specific setup recommendations
hetzner_setup_info() {
    if [ "$IS_HETZNER" = "true" ] && [ "$EUID" -eq 0 ]; then
        log_info "═══════════════════════════════════════════════════════════════════"
        log_info "Hetzner VPS Detected - Special Instructions"
        log_info "═══════════════════════════════════════════════════════════════════"
        log_info ""
        log_info "Hetzner VPS typically comes with:"
        log_info "• Root access only by default"
        log_info "• No sudo user configured"
        log_info "• Minimal firewall configuration"
        log_info ""
        log_info "This script will help you:"
        log_info "1. Create a new sudo user"
        log_info "2. Configure firewall rules"
        log_info "3. Deploy n8n securely"
        log_info "═══════════════════════════════════════════════════════════════════"
        echo
    fi
}

# Configure Hetzner firewall if using Hetzner Cloud
configure_hetzner_firewall() {
    if [ "$IS_HETZNER" = "true" ]; then
        log_info "Configuring firewall for Hetzner VPS..."
        
        # Hetzner often uses UFW on Ubuntu or firewalld on CentOS
        # The standard configure_firewall function should work
        configure_firewall
        
        # Additional Hetzner-specific recommendations
        log_info ""
        log_info "IMPORTANT: Hetzner Cloud Firewall"
        log_info "═════════════════════════════════════════════"
        log_info "If using Hetzner Cloud Firewall (via Cloud Console):"
        log_info "1. Allow inbound TCP port 22 (SSH)"
        log_info "2. Allow inbound TCP port 80 (HTTP)"
        log_info "3. Allow inbound TCP port 443 (HTTPS)"
        log_info ""
        log_info "Configure via: https://console.hetzner.cloud/"
        log_info "═════════════════════════════════════════════"
        echo
    fi
}

export -f detect_hetzner hetzner_setup_info configure_hetzner_firewall
