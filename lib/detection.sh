#!/bin/bash

# Detection functions for OS and cloud providers

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        log_error "Cannot detect OS"
        exit 1
    fi
    
    export OS
    export VER
}

detect_cloud_provider() {
    # Detect if running on a cloud provider
    CLOUD_PROVIDER="unknown"
    
    # AWS EC2
    if curl -s -m 2 http://169.254.169.254/latest/meta-data/instance-id &>/dev/null; then
        CLOUD_PROVIDER="aws"
        INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
        log_info "Detected AWS EC2 instance: $INSTANCE_ID"
    # DigitalOcean
    elif curl -s -m 2 http://169.254.169.254/metadata/v1/id &>/dev/null; then
        CLOUD_PROVIDER="digitalocean"
        log_info "Detected DigitalOcean droplet"
    # Azure
    elif curl -s -m 2 -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2021-02-01" &>/dev/null; then
        CLOUD_PROVIDER="azure"
        log_info "Detected Azure VM"
    # GCP
    elif curl -s -m 2 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/id &>/dev/null; then
        CLOUD_PROVIDER="gcp"
        log_info "Detected Google Cloud instance"
    else
        log_info "Running on local/unknown environment"
    fi
    
    export CLOUD_PROVIDER
}

detect_public_ip() {
    # Try multiple services to get public IP
    for service in "ifconfig.me" "ipinfo.io/ip" "api.ipify.org" "icanhazip.com"; do
        PUBLIC_IP=$(curl -s --max-time 5 $service 2>/dev/null)
        if validate_ip "$PUBLIC_IP"; then
            log_info "Detected public IP: $PUBLIC_IP"
            export PUBLIC_IP
            return 0
        fi
    done
    log_warn "Could not detect public IP automatically"
    return 1
}

# Detect system resources
detect_system_resources() {
    # Get total memory in MB
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        TOTAL_MEM=$(free -m | awk 'NR==2{print $2}')
    else
        TOTAL_MEM=$(free -m | grep Mem | awk '{print $2}')
    fi
    
    # Get CPU count
    CPU_COUNT=$(nproc)
    
    log_info "System resources: ${CPU_COUNT} CPUs, ${TOTAL_MEM}MB RAM"
    
    # Check if resources are sufficient
    if [ "$TOTAL_MEM" -lt 1024 ]; then
        log_warn "System has less than 1GB RAM. n8n may experience performance issues."
    fi
    
    export TOTAL_MEM
    export CPU_COUNT
}

# Check if running in container
detect_container() {
    if [ -f /.dockerenv ]; then
        log_warn "Running inside a Docker container"
        export IN_CONTAINER=true
    elif grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null; then
        log_warn "Running inside a container"
        export IN_CONTAINER=true
    else
        export IN_CONTAINER=false
    fi
}

export -f detect_os detect_cloud_provider detect_public_ip detect_system_resources detect_container 