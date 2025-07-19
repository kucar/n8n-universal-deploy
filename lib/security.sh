#!/bin/bash

# Security functions - password generation and credentials management

generate_secure_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

generate_encryption_key() {
    openssl rand -hex 16
}

setup_credentials() {
    echo -e "\n${BLUE}Setting up credentials${NC}"
    
    # Basic auth
    prompt_user "Enable basic authentication? [Y/n]" "Y" ENABLE_BASIC_AUTH
    
    if [ "$ENABLE_BASIC_AUTH" = "Y" ] || [ "$ENABLE_BASIC_AUTH" = "y" ] || [ -z "$ENABLE_BASIC_AUTH" ]; then
        N8N_BASIC_AUTH_ACTIVE=true
        prompt_user "Basic auth username" "admin" N8N_BASIC_AUTH_USER
        
        log_info "Generating secure password for basic auth..."
        N8N_BASIC_AUTH_PASSWORD=$(generate_secure_password)
        log_warn "Basic auth password: ${GREEN}$N8N_BASIC_AUTH_PASSWORD${NC} (save this!)"
    else
        N8N_BASIC_AUTH_ACTIVE=false
        N8N_BASIC_AUTH_USER=""
        N8N_BASIC_AUTH_PASSWORD=""
    fi
    
    # Database passwords
    log_info "Generating database passwords..."
    POSTGRES_PASSWORD=$(generate_secure_password)
    POSTGRES_NON_ROOT_PASSWORD=$(generate_secure_password)
    
    # Encryption key
    log_info "Generating encryption key..."
    N8N_ENCRYPTION_KEY=$(generate_encryption_key)
    
    # Export all credentials
    export N8N_BASIC_AUTH_ACTIVE
    export N8N_BASIC_AUTH_USER
    export N8N_BASIC_AUTH_PASSWORD
    export POSTGRES_PASSWORD
    export POSTGRES_NON_ROOT_PASSWORD
    export N8N_ENCRYPTION_KEY
}

save_credentials() {
    local access_url=$1
    
    cat > "$PROJECT_DIR/credentials.txt" << EOF
n8n Deployment Credentials
Generated: $(date)
========================

Access URL: $access_url

Basic Auth Username: ${N8N_BASIC_AUTH_USER:-N/A}
Basic Auth Password: ${N8N_BASIC_AUTH_PASSWORD:-N/A}

Database Admin: n8n_admin
Database Admin Password: $POSTGRES_PASSWORD
Database User: n8n_user
Database User Password: $POSTGRES_NON_ROOT_PASSWORD

Encryption Key: $N8N_ENCRYPTION_KEY

SSL Email: ${ACME_EMAIL:-N/A}

Cloud Provider: ${CLOUD_PROVIDER:-unknown}
Instance ID: ${AWS_INSTANCE_ID:-N/A}
EOF
    
    chmod 600 "$PROJECT_DIR/credentials.txt"
    log_info "Credentials saved to: $PROJECT_DIR/credentials.txt"
}

# Function to display credentials summary
display_credentials_summary() {
    echo -e "\n${YELLOW}Important Credentials (SAVE THESE!):${NC}"
    echo -e "───────────────────────────────────────────────"
    
    if [ "$N8N_BASIC_AUTH_ACTIVE" = "true" ]; then
        echo -e "Basic Auth Username: ${GREEN}$N8N_BASIC_AUTH_USER${NC}"
        echo -e "Basic Auth Password: ${GREEN}$N8N_BASIC_AUTH_PASSWORD${NC}"
    fi
    
    echo -e "\nDatabase Admin: ${GREEN}n8n_admin${NC}"
    echo -e "Database Admin Password: ${GREEN}$POSTGRES_PASSWORD${NC}"
    echo -e "Encryption Key: ${GREEN}$N8N_ENCRYPTION_KEY${NC}"
}

export -f generate_secure_password generate_encryption_key setup_credentials save_credentials display_credentials_summary 