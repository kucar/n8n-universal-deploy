#!/bin/bash

# Common functions and variables for n8n deployment script

# Color codes for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

# Script version
export SCRIPT_VERSION="1.1.0"

# Default values
export DEFAULT_N8N_PORT=5678
export DEFAULT_POSTGRES_DB="n8n_production"
export DEFAULT_TIMEZONE="UTC"
export PROJECT_DIR="${HOME}/n8n-production"

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_banner() {
    echo -e "${BLUE}"
    echo "═════════════════════════════════════════════════════════════════════════════════════════════"
    echo "║           Universal n8n Deployment Script v${SCRIPT_VERSION}          ║"
    echo "║   Automated deployment for cloud and local environments   ║"
    echo "═════════════════════════════════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
}

# User input function
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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure script is not run as root
check_not_root() {
    if [ "$EUID" -eq 0 ]; then
        log_error "Please run this script as a normal user (not root)"
        exit 1
    fi
}

# Create directory structure
create_project_structure() {
    log_info "Creating project directory: $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"/{local-files,backups,logs}
}

# Export functions for use in other scripts
export -f log_info log_warn log_error prompt_user command_exists 

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
export -f install_docker 

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
export -f configure_firewall 