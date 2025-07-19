#!/bin/bash

# Validation functions for n8n deployment script

validate_domain() {
    local domain=$1
    if [[ $domain =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

validate_email() {
    local email=$1
    if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Verify DNS configuration
verify_dns() {
    local domain=$1
    local public_ip=$2
    
    log_info "Verifying DNS configuration..."
    DNS_IP=$(dig +short $domain 2>/dev/null | tail -n1)
    
    if [ "$DNS_IP" = "$public_ip" ]; then
        log_info "DNS is correctly configured"
        return 0
    else
        log_warn "DNS record for $domain does not match server IP"
        log_warn "Expected: $public_ip, Found: $DNS_IP"
        echo -n "Continue anyway? [y/N]: "
        read confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            return 1
        fi
    fi
    return 0
}

# Validate deployment configuration
validate_deployment_config() {
    local deployment_mode=$1
    local n8n_host=$2
    local use_ssl=$3
    
    # Check if all required variables are set
    if [ -z "$deployment_mode" ] || [ -z "$n8n_host" ] || [ -z "$use_ssl" ]; then
        log_error "Missing required deployment configuration"
        return 1
    fi
    
    # Validate host based on deployment mode
    case $deployment_mode in
        production)
            if ! validate_domain "$n8n_host"; then
                log_error "Invalid domain format for production deployment"
                return 1
            fi
            ;;
        internal)
            if ! validate_domain "$n8n_host" && ! validate_ip "$n8n_host"; then
                log_error "Invalid host format for internal deployment"
                return 1
            fi
            ;;
        local)
            if [ "$n8n_host" != "localhost" ] && [ "$n8n_host" != "127.0.0.1" ]; then
                log_error "Local deployment should use localhost or 127.0.0.1"
                return 1
            fi
            ;;
    esac
    
    return 0
}

export -f validate_domain validate_email validate_ip verify_dns validate_deployment_config 