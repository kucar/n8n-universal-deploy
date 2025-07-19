#!/bin/bash

# Universal n8n Deployment Script
# Supports: AWS EC2, DigitalOcean, Azure, GCP, Local installations
# Features: SSL/TLS, PostgreSQL, Firewall configuration, Docker setup

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script version
SCRIPT_VERSION="1.0.0"

# Default values
DEFAULT_N8N_PORT=5678
DEFAULT_POSTGRES_DB="n8n_production"
DEFAULT_TIMEZONE="UTC"
PROJECT_DIR="${HOME}/n8n-production"

# Functions
print_banner() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║           Universal n8n Deployment Script v${SCRIPT_VERSION}          ║"
    echo "║   Automated deployment for cloud and local environments   ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

prompt_user() {
    local prompt=$1
    local default=$2
    local var_name=$3
    local is_password=$4
    
    if [ -n "$default" ]; then
        prompt="$prompt [$default]"
    fi
    
    echo -n "$prompt: "
    
    if [ "$is_password" = "true" ]; then
        read -s value
        echo
    else
        read value
    fi
    
    if [ -z "$value" ] && [ -n "$default" ]; then
        value=$default
    fi
    
    eval "$var_name='$value'"
}

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

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        log_error "Cannot detect OS"
        exit 1
    fi
}

detect_public_ip() {
    # Try multiple services to get public IP
    for service in "ifconfig.me" "ipinfo.io/ip" "api.ipify.org" "icanhazip.com"; do
        PUBLIC_IP=$(curl -s --max-time 5 $service 2>/dev/null)
        if validate_ip "$PUBLIC_IP"; then
            log_info "Detected public IP: $PUBLIC_IP"
            return 0
        fi
    done
    log_warn "Could not detect public IP automatically"
    return 1
}

install_docker() {
    log_info "Installing Docker..."
    
    case $OS in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y \
                ca-certificates \
                curl \
                gnupg \
                lsb-release
            
            # Add Docker's official GPG key
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            
            # Set up repository
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
                $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        centos|rhel|fedora)
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        *)
            log_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add current user to docker group
    sudo usermod -aG docker $USER
    
    log_info "Docker installed successfully"
}

configure_firewall() {
    log_info "Configuring firewall..."
    
    case $OS in
        ubuntu|debian)
            if ! command -v ufw &> /dev/null; then
                sudo apt-get install -y ufw
            fi
            
            sudo ufw --force enable
            sudo ufw allow 22/tcp
            sudo ufw allow 80/tcp
            sudo ufw allow 443/tcp
            
            # Block direct n8n port access
            sudo ufw deny $DEFAULT_N8N_PORT/tcp
            
            log_info "UFW firewall configured"
            ;;
        centos|rhel|fedora)
            if ! command -v firewall-cmd &> /dev/null; then
                sudo yum install -y firewalld
                sudo systemctl start firewalld
                sudo systemctl enable firewalld
            fi
            
            sudo firewall-cmd --permanent --add-service=ssh
            sudo firewall-cmd --permanent --add-service=http
            sudo firewall-cmd --permanent --add-service=https
            sudo firewall-cmd --permanent --remove-port=$DEFAULT_N8N_PORT/tcp 2>/dev/null || true
            sudo firewall-cmd --reload
            
            log_info "Firewalld configured"
            ;;
    esac
}

generate_secure_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

generate_encryption_key() {
    openssl rand -hex 16
}

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
    fi
    
    # Database passwords
    log_info "Generating database passwords..."
    POSTGRES_PASSWORD=$(generate_secure_password)
    POSTGRES_NON_ROOT_PASSWORD=$(generate_secure_password)
    
    # Encryption key
    log_info "Generating encryption key..."
    N8N_ENCRYPTION_KEY=$(generate_encryption_key)
}

create_init_script() {
    cat > "$PROJECT_DIR/init-data.sh" << 'EOF'
#!/bin/bash
set -e;

if [ -n "${POSTGRES_NON_ROOT_USER:-}" ] && [ -n "${POSTGRES_NON_ROOT_PASSWORD:-}" ]; then
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        CREATE USER ${POSTGRES_NON_ROOT_USER} WITH PASSWORD '${POSTGRES_NON_ROOT_PASSWORD}';
        GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_NON_ROOT_USER};
        GRANT ALL ON SCHEMA public TO ${POSTGRES_NON_ROOT_USER};
EOSQL
else
    echo "SETUP INFO: No Environment variables given!"
fi
EOF
    chmod +x "$PROJECT_DIR/init-data.sh"
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

create_docker_compose() {
    if [ "$USE_SSL" = true ]; then
        create_docker_compose_ssl
    else
        create_docker_compose_local
    fi
}

create_docker_compose_ssl() {
    cat > "$PROJECT_DIR/docker-compose.yml" << 'EOF'
services:
  traefik:
    image: traefik:v3.1
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    command:
      - --api=true
      - --api.insecure=true
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.mytlschallenge.acme.tlschallenge=true
      - --certificatesresolvers.mytlschallenge.acme.email=${ACME_EMAIL}
      - --certificatesresolvers.mytlschallenge.acme.storage=/letsencrypt/acme.json
      - --entrypoints.web.http.redirections.entrypoint.to=websecure
      - --entrypoints.web.http.redirections.entrypoint.scheme=https
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik_data:/letsencrypt
    networks:
      - n8n_network

  postgres:
    image: postgres:16
    container_name: postgres
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_NON_ROOT_USER=${POSTGRES_NON_ROOT_USER}
      - POSTGRES_NON_ROOT_PASSWORD=${POSTGRES_NON_ROOT_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-data.sh:/docker-entrypoint-initdb.d/init-data.sh
    networks:
      - n8n_network
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -h localhost -U ${POSTGRES_USER} -d ${POSTGRES_DB}']
      interval: 5s
      timeout: 5s
      retries: 10

  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    user: "1000:1000"
    environment:
      # Core Configuration
      - N8N_HOST=${N8N_HOST}
      - N8N_PORT=5678
      - N8N_PROTOCOL=${N8N_PROTOCOL}
      - N8N_EDITOR_BASE_URL=${N8N_EDITOR_BASE_URL}
      - WEBHOOK_URL=${WEBHOOK_URL}
      - NODE_ENV=production
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
      - N8N_RUNNERS_ENABLED=true
      
      # Database Configuration
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_USER=${POSTGRES_NON_ROOT_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_NON_ROOT_PASSWORD}
      - DB_POSTGRESDB_SSL_ENABLED=false
      
      # Security
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - N8N_BASIC_AUTH_ACTIVE=${N8N_BASIC_AUTH_ACTIVE}
      - N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
      
      # Performance
      - EXECUTIONS_TIMEOUT=${EXECUTIONS_TIMEOUT}
      - EXECUTIONS_DATA_PRUNE=true
      - EXECUTIONS_DATA_MAX_AGE=${EXECUTIONS_DATA_MAX_AGE}
      - N8N_PAYLOAD_SIZE_MAX=${N8N_PAYLOAD_SIZE_MAX}
      
      # Logging and Monitoring
      - N8N_LOG_LEVEL=info
      - N8N_LOG_OUTPUT=console
      - N8N_METRICS=true
      - N8N_METRICS_INCLUDE_DEFAULT_METRICS=true
      
      # Timezone
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
      - TZ=${TZ}
      
    labels:
      - traefik.enable=true
      - traefik.docker.network=n8n_network
      - traefik.http.routers.n8n.rule=Host(`${N8N_HOST}`)
      - traefik.http.routers.n8n.entrypoints=websecure
      - traefik.http.routers.n8n.tls=true
      - traefik.http.routers.n8n.tls.certresolver=mytlschallenge
      - traefik.http.services.n8n.loadbalancer.server.port=5678
      
      # Security Headers
      - traefik.http.middlewares.n8n.headers.SSLRedirect=true
      - traefik.http.middlewares.n8n.headers.STSSeconds=31536000
      - traefik.http.middlewares.n8n.headers.browserXSSFilter=true
      - traefik.http.middlewares.n8n.headers.contentTypeNosniff=true
      - traefik.http.middlewares.n8n.headers.forceSTSHeader=true
      - traefik.http.middlewares.n8n.headers.SSLHost=${N8N_HOST}
      - traefik.http.middlewares.n8n.headers.STSIncludeSubdomains=true
      - traefik.http.middlewares.n8n.headers.STSPreload=true
      - traefik.http.routers.n8n.middlewares=n8n@docker
      
    volumes:
      - n8n_data:/home/node/.n8n
      - ./local-files:/files
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - n8n_network
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '1.0'
          memory: 2G

volumes:
  n8n_data:
  postgres_data:
  traefik_data:

networks:
  n8n_network:
    driver: bridge
EOF
}

create_docker_compose_local() {
    cat > "$PROJECT_DIR/docker-compose.yml" << 'EOF'
services:
  postgres:
    image: postgres:16
    container_name: postgres
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_NON_ROOT_USER=${POSTGRES_NON_ROOT_USER}
      - POSTGRES_NON_ROOT_PASSWORD=${POSTGRES_NON_ROOT_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-data.sh:/docker-entrypoint-initdb.d/init-data.sh
    networks:
      - n8n_network
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -h localhost -U ${POSTGRES_USER} -d ${POSTGRES_DB}']
      interval: 5s
      timeout: 5s
      retries: 10

  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    user: "1000:1000"
    ports:
      - "${N8N_PORT:-5678}:5678"
    environment:
      # Core Configuration
      - N8N_HOST=${N8N_HOST}
      - N8N_PORT=5678
      - N8N_PROTOCOL=${N8N_PROTOCOL}
      - N8N_EDITOR_BASE_URL=${N8N_EDITOR_BASE_URL}
      - WEBHOOK_URL=${WEBHOOK_URL}
      - NODE_ENV=production
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
      - N8N_RUNNERS_ENABLED=true
      
      # Database Configuration
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_USER=${POSTGRES_NON_ROOT_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_NON_ROOT_PASSWORD}
      - DB_POSTGRESDB_SSL_ENABLED=false
      
      # Security
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - N8N_BASIC_AUTH_ACTIVE=${N8N_BASIC_AUTH_ACTIVE}
      - N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
      
      # Performance
      - EXECUTIONS_TIMEOUT=${EXECUTIONS_TIMEOUT}
      - EXECUTIONS_DATA_PRUNE=true
      - EXECUTIONS_DATA_MAX_AGE=${EXECUTIONS_DATA_MAX_AGE}
      - N8N_PAYLOAD_SIZE_MAX=${N8N_PAYLOAD_SIZE_MAX}
      
      # Logging
      - N8N_LOG_LEVEL=info
      - N8N_LOG_OUTPUT=console
      
      # Timezone
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
      - TZ=${TZ}
      
    volumes:
      - n8n_data:/home/node/.n8n
      - ./local-files:/files
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - n8n_network

volumes:
  n8n_data:
  postgres_data:

networks:
  n8n_network:
    driver: bridge
EOF
}

create_backup_script() {
    cat > "$PROJECT_DIR/backup.sh" << 'EOF'
#!/bin/bash
# n8n Backup Script

DATE=$(date +"%Y%m%d-%H%M%S")
BACKUP_DIR="./backups"

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Load environment variables
source .env

# Create database dump
echo "Creating database backup..."
docker exec postgres pg_dump -U $POSTGRES_USER $POSTGRES_DB > $BACKUP_DIR/n8n-db-$DATE.sql

# Backup n8n data
echo "Creating n8n data backup..."
docker run --rm -v n8n-production_n8n_data:/data -v $PWD/$BACKUP_DIR:/backup alpine tar czf /backup/n8n-data-$DATE.tar.gz -C /data .

echo "Backup completed: $BACKUP_DIR/n8n-db-$DATE.sql and $BACKUP_DIR/n8n-data-$DATE.tar.gz"

# Optional: Remove backups older than 7 days
find $BACKUP_DIR -type f -mtime +7 -delete
EOF
    chmod +x "$PROJECT_DIR/backup.sh"
}

create_update_script() {
    cat > "$PROJECT_DIR/update.sh" << 'EOF'
#!/bin/bash
# n8n Update Script

echo "Pulling latest images..."
docker compose pull

echo "Creating backup before update..."
./backup.sh

echo "Updating containers..."
docker compose up -d

echo "Update completed!"
echo "Check logs with: docker compose logs -f"
EOF
    chmod +x "$PROJECT_DIR/update.sh"
}

deploy_n8n() {
    log_info "Deploying n8n..."
    
    cd "$PROJECT_DIR"
    
    # Start deployment
    docker compose up -d
    
    # Wait for services to be ready
    log_info "Waiting for services to start..."
    sleep 10
    
    # Check status
    docker compose ps
    
    # Test connectivity
    if [ "$USE_SSL" = true ]; then
        URL="https://$N8N_HOST"
    else
        URL="http://$N8N_HOST:$DEFAULT_N8N_PORT"
    fi
    
    log_info "Testing n8n connectivity..."
    if curl -s -o /dev/null -w "%{http_code}" "$URL" | grep -q "200\|301\|302"; then
        log_info "n8n is accessible!"
    else
        log_warn "n8n might still be starting up. Check logs with: docker compose logs -f"
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
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        log_error "Please run this script as a normal user (not root)"
        exit 1
    fi
    
    # Detect OS
    detect_os
    log_info "Detected OS: $OS $VER"
    
    # Setup deployment type
    setup_deployment_type
    
    # Configure domain/host
    setup_domain_config
    
    # Check Docker installation
    if ! command -v docker &> /dev/null; then
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
    fi
    
    # Configure firewall
    if [ "$DEPLOYMENT_MODE" != "local" ]; then
        echo -n "Configure firewall? [Y/n]: "
        read configure_fw
        if [ "$configure_fw" != "n" ] && [ "$configure_fw" != "N" ]; then
            configure_firewall
        fi
    fi
    
    # Create project directory
    log_info "Creating project directory: $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"/{local-files,backups}
    
    # Setup credentials
    setup_credentials
    
    # Create configuration files
    log_info "Creating configuration files..."
    create_init_script
    create_env_file
    create_docker_compose
    create_backup_script
    create_update_script
    
    # Deploy n8n
    echo -e "\n${YELLOW}Ready to deploy n8n with the following configuration:${NC}"
    echo "Deployment mode: $DEPLOYMENT_MODE"
    echo "Host: $N8N_HOST"
    echo "SSL enabled: $USE_SSL"
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