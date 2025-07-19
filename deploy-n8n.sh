#!/bin/bash

# Universal n8n Deployment Script
# Supports: AWS EC2, DigitalOcean, Azure, GCP, Hetzner, Local installations
# Features: SSL/TLS, PostgreSQL, Firewall configuration, Docker setup

set -e

# Source helper libraries
for lib in common detection validation security aws hetzner; do
    if [ -f "$(dirname "$0")/lib/$lib.sh" ]; then
        source "$(dirname "$0")/lib/$lib.sh"
    else
        # hetzner.sh is optional
        if [ "$lib" != "hetzner" ]; then
            echo "[ERROR] Missing required library: lib/$lib.sh" >&2
            exit 1
        fi
    fi
done

# Script version
SCRIPT_VERSION="$SCRIPT_VERSION"  # from lib/common.sh

# Default values (from lib/common.sh)
# DEFAULT_N8N_PORT, DEFAULT_POSTGRES_DB, DEFAULT_TIMEZONE, PROJECT_DIR

# === Main deployment logic functions ===

setup_deployment_type() {
    echo -e "\n${BLUE}Select deployment type:${NC}"
    echo "1) Production with domain (SSL/TLS enabled)"
    echo "2) Local development (localhost only)"
    echo "3) Internal network (private IP)"
    prompt_user "Enter choice [1-3]" "1" DEPLOYMENT_TYPE
    case $DEPLOYMENT_TYPE in
        1)
            DEPLOYMENT_MODE="production"
            USE_SSL=true
            log_info "Production deployment with SSL/TLS selected"
            ;;
        2)
            DEPLOYMENT_MODE="local"
            USE_SSL=false
            N8N_HOST="localhost"
            log_info "Local development deployment selected"
            ;;
        3)
            DEPLOYMENT_MODE="internal"
            USE_SSL=false
            log_info "Internal network deployment selected"
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
}

setup_domain_config() {
    if [ "$DEPLOYMENT_MODE" = "production" ]; then
        # Get domain
        prompt_user "Enter your domain (e.g., n8n.example.com)" "" DOMAIN
        while ! validate_domain "$DOMAIN"; do
            log_error "Invalid domain format"
            prompt_user "Enter your domain (e.g., n8n.example.com)" "" DOMAIN
        done
        N8N_HOST=$DOMAIN
        # Get email for Let's Encrypt
        prompt_user "Enter email for SSL certificates" "" ACME_EMAIL
        while ! validate_email "$ACME_EMAIL"; do
            log_error "Invalid email format"
            prompt_user "Enter email for SSL certificates" "" ACME_EMAIL
        done
        # Verify DNS
        log_info "Verifying DNS configuration..."
        if detect_public_ip; then
            DNS_IP=$(dig +short $DOMAIN 2>/dev/null | tail -n1)
            if [ "$DNS_IP" = "$PUBLIC_IP" ]; then
                log_info "DNS is correctly configured"
            else
                log_warn "DNS record for $DOMAIN does not match server IP"
                log_warn "Expected: $PUBLIC_IP, Found: $DNS_IP"
                echo -n "Continue anyway? [y/N]: "
                read confirm
                if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                    exit 1
                fi
            fi
        fi
    elif [ "$DEPLOYMENT_MODE" = "internal" ]; then
        # Get internal IP or hostname
        prompt_user "Enter internal IP or hostname" "" N8N_HOST
    fi
}

create_env_file() {
    cat > "$PROJECT_DIR/.env" << EOF
# Deployment Configuration
DEPLOYMENT_MODE=$DEPLOYMENT_MODE

# Domain Configuration
N8N_HOST=$N8N_HOST
EOF
    if [ "$USE_SSL" = true ]; then
        cat >> "$PROJECT_DIR/.env" << EOF
WEBHOOK_URL=https://$N8N_HOST/
N8N_EDITOR_BASE_URL=https://$N8N_HOST
N8N_PROTOCOL=https
# SSL Configuration
ACME_EMAIL=$ACME_EMAIL
EOF
    else
        cat >> "$PROJECT_DIR/.env" << EOF
WEBHOOK_URL=http://$N8N_HOST:$DEFAULT_N8N_PORT/
N8N_EDITOR_BASE_URL=http://$N8N_HOST:$DEFAULT_N8N_PORT
N8N_PROTOCOL=http
EOF
    fi
    cat >> "$PROJECT_DIR/.env" << EOF

# Database Configuration
POSTGRES_USER=n8n_admin
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=$DEFAULT_POSTGRES_DB
POSTGRES_NON_ROOT_USER=n8n_user
POSTGRES_NON_ROOT_PASSWORD=$POSTGRES_NON_ROOT_PASSWORD

# Security Configuration
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY
N8N_BASIC_AUTH_ACTIVE=$N8N_BASIC_AUTH_ACTIVE
N8N_BASIC_AUTH_USER=$N8N_BASIC_AUTH_USER
N8N_BASIC_AUTH_PASSWORD=$N8N_BASIC_AUTH_PASSWORD

# Performance Configuration
EXECUTIONS_TIMEOUT=3600
EXECUTIONS_DATA_MAX_AGE=336
N8N_PAYLOAD_SIZE_MAX=32

# Timezone
GENERIC_TIMEZONE=$DEFAULT_TIMEZONE
TZ=$DEFAULT_TIMEZONE
EOF
    chmod 600 "$PROJECT_DIR/.env"
}

deploy_n8n() {
    log_info "Deploying n8n..."
    cd "$PROJECT_DIR"
    # Start deployment
    docker compose up -d
    # Wait for services to be ready
    log_info "Waiting for services to start..."
    sleep 15
    # Check status
    docker compose ps
    # Test connectivity
    if [ "$USE_SSL" = true ]; then
        URL="https://$N8N_HOST"
    else
        URL="http://$N8N_HOST:$DEFAULT_N8N_PORT"
    fi
    log_info "Testing n8n connectivity..."
    if curl -s -o /dev/null -w "%{http_code}" "$URL" | grep -q "200\|301\|302\|401"; then
        log_info "n8n is accessible!"
    else
        log_warn "n8n might still be starting up. Check logs with: docker compose logs -f"
        if [ "$USE_SSL" = true ]; then
            log_warn "If SSL is failing, run: cd $PROJECT_DIR && ./ssl-fix.sh"
        fi
    fi
}

print_summary() {
    echo -e "\n${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}            n8n Deployment Completed Successfully!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}\n"
    if [ "$USE_SSL" = true ]; then
        echo -e "Access URL: ${BLUE}https://$N8N_HOST${NC}"
    else
        echo -e "Access URL: ${BLUE}http://$N8N_HOST:$DEFAULT_N8N_PORT${NC}"
    fi
    echo -e "\n${YELLOW}Important Credentials (SAVE THESE!):${NC}"
    echo -e "─────────────────────────────────────"
    if [ "$N8N_BASIC_AUTH_ACTIVE" = "true" ]; then
        echo -e "Basic Auth Username: ${GREEN}$N8N_BASIC_AUTH_USER${NC}"
        echo -e "Basic Auth Password: ${GREEN}$N8N_BASIC_AUTH_PASSWORD${NC}"
    fi
    echo -e "\nDatabase Admin: ${GREEN}n8n_admin${NC}"
    echo -e "Database Admin Password: ${GREEN}$POSTGRES_PASSWORD${NC}"
    echo -e "Encryption Key: ${GREEN}$N8N_ENCRYPTION_KEY${NC}"
    echo -e "\n${YELLOW}Useful Commands:${NC}"
    echo -e "─────────────────────────────────────"
    echo -e "View logs:        ${BLUE}cd $PROJECT_DIR && docker compose logs -f${NC}"
    echo -e "Stop n8n:         ${BLUE}cd $PROJECT_DIR && docker compose down${NC}"
    echo -e "Start n8n:        ${BLUE}cd $PROJECT_DIR && docker compose up -d${NC}"
    echo -e "Backup n8n:       ${BLUE}cd $PROJECT_DIR && ./backup.sh${NC}"
    echo -e "Update n8n:       ${BLUE}cd $PROJECT_DIR && ./update.sh${NC}"
    echo -e "Troubleshoot:     ${BLUE}cd $PROJECT_DIR && ./troubleshoot.sh${NC}"
    
    if [ "$USE_SSL" = true ]; then
        echo -e "Fix SSL issues:   ${BLUE}cd $PROJECT_DIR && ./ssl-fix.sh${NC}"
    fi
    
    echo -e "\n${YELLOW}Configuration Files:${NC}"
    echo -e "─────────────────────────────────────"
    echo -e "Project directory: ${BLUE}$PROJECT_DIR${NC}"
    echo -e "Environment file:  ${BLUE}$PROJECT_DIR/.env${NC}"
    echo -e "Docker Compose:    ${BLUE}$PROJECT_DIR/docker-compose.yml${NC}"
    echo -e "\n${GREEN}Deployment complete! Your n8n instance should be accessible shortly.${NC}"
    
    # Save credentials to file
    cat > "$PROJECT_DIR/credentials.txt" << EOF
n8n Deployment Credentials
Generated: $(date)
========================

Access URL: $([ "$USE_SSL" = true ] && echo "https://$N8N_HOST" || echo "http://$N8N_HOST:$DEFAULT_N8N_PORT")

Basic Auth Username: $N8N_BASIC_AUTH_USER
Basic Auth Password: $N8N_BASIC_AUTH_PASSWORD

Database Admin: n8n_admin
Database Admin Password: $POSTGRES_PASSWORD
Database User: n8n_user
Database User Password: $POSTGRES_NON_ROOT_PASSWORD

Encryption Key: $N8N_ENCRYPTION_KEY

SSL Email: ${ACME_EMAIL:-N/A}
EOF
    chmod 600 "$PROJECT_DIR/credentials.txt"
    echo -e "\n${YELLOW}Credentials saved to: ${BLUE}$PROJECT_DIR/credentials.txt${NC}"
}

# Main execution
main() {
    print_banner
    
    # Handle root user FIRST - this will create a new user if needed
    check_not_root
    
    # Detect OS
    detect_os
    log_info "Detected OS: $OS $VER"
    
    # Detect cloud provider
    detect_cloud_provider
    
    # Detect Hetzner if the library exists
    if command_exists detect_hetzner; then
        detect_hetzner
        # Show Hetzner-specific info if applicable
        if [ "$IS_HETZNER" = "true" ]; then
            hetzner_setup_info
        fi
    fi
    
    # Check Docker installation EARLY - before any configuration
    if ! command_exists docker; then
        log_warn "Docker not found"
        echo -n "Install Docker? [Y/n]: "
        read install_docker_confirm
        if [ "$install_docker_confirm" != "n" ] && [ "$install_docker_confirm" != "N" ]; then
            install_docker
            log_warn "Please log out and log back in for Docker group changes to take effect"
            log_warn "Then run this script again"
            exit 0
        else
            log_error "Docker is required for n8n deployment"
            exit 1
        fi
    else
        log_info "Docker is already installed"
    fi
    
    # Check Docker Compose
    if ! docker compose version &>/dev/null && ! docker-compose version &>/dev/null; then
        log_error "Docker Compose is not installed or not working properly"
        exit 1
    fi
    
    # Now continue with configuration
    setup_deployment_type
    setup_domain_config
    
    # AWS-specific checks
    if [ "$CLOUD_PROVIDER" = "aws" ] && [ "$DEPLOYMENT_MODE" = "production" ]; then
        check_aws_security_group
    fi
    
    # Configure firewall
    if [ "$DEPLOYMENT_MODE" != "local" ]; then
        echo -n "Configure firewall? [Y/n]: "
        read configure_fw
        if [ "$configure_fw" != "n" ] && [ "$configure_fw" != "N" ]; then
            # Use Hetzner-specific firewall config if on Hetzner
            if [ "$IS_HETZNER" = "true" ] && command_exists configure_hetzner_firewall; then
                configure_hetzner_firewall
            else
                configure_firewall
            fi
        fi
    fi
    
    # Create project directory
    log_info "Creating project directory: $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"/{local-files,backups,logs}
    
    # Setup credentials
    setup_credentials
    
    # Create .env file
    log_info "Creating .env configuration file..."
    create_env_file
    
    # Copy templates
    log_info "Copying template files..."
    if [ "$USE_SSL" = true ]; then
        cp "$(dirname "$0")/templates/docker-compose-ssl.yml" "$PROJECT_DIR/docker-compose.yml"
    else
        cp "$(dirname "$0")/templates/docker-compose-local.yml" "$PROJECT_DIR/docker-compose.yml"
    fi
    cp "$(dirname "$0")/templates/backup.sh" "$PROJECT_DIR/backup.sh"
    cp "$(dirname "$0")/templates/update.sh" "$PROJECT_DIR/update.sh"
    cp "$(dirname "$0")/templates/init-data.sh" "$PROJECT_DIR/init-data.sh"
    cp "$(dirname "$0")/templates/ssl-fix.sh" "$PROJECT_DIR/ssl-fix.sh"
    cp "$(dirname "$0")/templates/troubleshoot.sh" "$PROJECT_DIR/troubleshoot.sh"
    chmod +x "$PROJECT_DIR/backup.sh" "$PROJECT_DIR/update.sh" "$PROJECT_DIR/init-data.sh" "$PROJECT_DIR/ssl-fix.sh" "$PROJECT_DIR/troubleshoot.sh"
    
    # Deploy n8n
    echo -e "\n${YELLOW}Ready to deploy n8n with the following configuration:${NC}"
    echo "Deployment mode: $DEPLOYMENT_MODE"
    echo "Host: $N8N_HOST"
    echo "SSL enabled: $USE_SSL"
    echo "Cloud provider: ${CLOUD_PROVIDER:-none}"
    if [ "$IS_HETZNER" = "true" ]; then
        echo "VPS provider: Hetzner"
    fi
    echo -n -e "\n${YELLOW}Proceed with deployment? [Y/n]: ${NC}"
    read deploy_confirm
    if [ "$deploy_confirm" != "n" ] && [ "$deploy_confirm" != "N" ]; then
        deploy_n8n
        print_summary
    else
        log_info "Deployment cancelled. Configuration files created at: $PROJECT_DIR"
    fi
}

# Run main function
main "$@"
