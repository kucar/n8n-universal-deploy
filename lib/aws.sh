#!/bin/bash

# AWS-specific functions and security group checks

check_aws_security_group() {
    if [ "$CLOUD_PROVIDER" != "aws" ] || [ "$DEPLOYMENT_MODE" != "production" ]; then
        return 0
    fi
    
    log_warn "════════════════════════════════════════════════════════════════════════════════════════════"
    log_warn "AWS EC2 DETECTED - IMPORTANT SECURITY GROUP CONFIGURATION"
    log_warn "════════════════════════════════════════════════════════════════════════════════════════════"
    log_warn ""
    log_warn "Ensure your AWS Security Group has these inbound rules:"
    log_warn "  • Port 80 (HTTP) - Source: 0.0.0.0/0 (Required for Let's Encrypt)"
    log_warn "  • Port 443 (HTTPS) - Source: 0.0.0.0/0"
    log_warn "  • Port 22 (SSH) - Source: Your IP address"
    log_warn ""
    log_warn "Without port 80 open, SSL certificate generation will fail!"
    log_warn "════════════════════════════════════════════════════════════════════════════════════════════"
    
    echo -n "Have you configured the security group correctly? [y/N]: "
    read sg_confirm
    if [ "$sg_confirm" != "y" ] && [ "$sg_confirm" != "Y" ]; then
        log_error "Please configure your AWS Security Group before continuing"
        log_info "You can do this in the AWS Console or using AWS CLI:"
        log_info ""
        log_info "Example AWS CLI commands:"
        log_info "  aws ec2 describe-security-groups --instance-id \$(ec2-metadata --instance-id | cut -d' ' -f2)"
        log_info "  aws ec2 authorize-security-group-ingress --group-id sg-xxxxx --protocol tcp --port 80 --cidr 0.0.0.0/0"
        log_info "  aws ec2 authorize-security-group-ingress --group-id sg-xxxxx --protocol tcp --port 443 --cidr 0.0.0.0/0"
        exit 1
    fi
}

# Get AWS instance metadata
get_aws_metadata() {
    if [ "$CLOUD_PROVIDER" != "aws" ]; then
        return 1
    fi
    
    # Get instance ID
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    
    # Get availability zone
    AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
    
    # Get instance type
    INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
    
    # Get public hostname
    PUBLIC_HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname)
    
    log_info "AWS Instance Details:"
    log_info "  Instance ID: $INSTANCE_ID"
    log_info "  Type: $INSTANCE_TYPE"
    log_info "  AZ: $AZ"
    log_info "  Public Hostname: $PUBLIC_HOSTNAME"
    
    export AWS_INSTANCE_ID=$INSTANCE_ID
    export AWS_AZ=$AZ
    export AWS_INSTANCE_TYPE=$INSTANCE_TYPE
}

# Check if AWS CLI is installed and configured
check_aws_cli() {
    if command_exists aws; then
        log_info "AWS CLI is installed"
        if aws sts get-caller-identity &>/dev/null; then
            log_info "AWS CLI is configured"
            return 0
        else
            log_warn "AWS CLI is not configured. Some features may be limited."
            return 1
        fi
    else
        log_warn "AWS CLI is not installed. Install it for advanced AWS features."
        return 1
    fi
}

# Create AWS-specific troubleshooting commands
create_aws_troubleshooting() {
    cat >> "$PROJECT_DIR/troubleshoot.sh" << 'EOF'

# AWS-specific troubleshooting
if [ "$CLOUD_PROVIDER" = "aws" ]; then
    echo
    echo "=== AWS-specific checks ==="
    
    # Check security groups
    if command -v aws >/dev/null 2>&1; then
        echo "Checking security groups..."
        INSTANCE_ID=$(ec2-metadata --instance-id | cut -d' ' -f2)
        aws ec2 describe-instances --instance-ids $INSTANCE_ID \
            --query 'Reservations[0].Instances[0].SecurityGroups[*].[GroupId,GroupName]' \
            --output table 2>/dev/null || echo "AWS CLI not configured"
    fi
    
    # Check instance metadata
    echo
    echo "Instance metadata:"
    curl -s http://169.254.169.254/latest/meta-data/instance-id && echo
    curl -s http://169.254.169.254/latest/meta-data/public-ipv4 && echo
fi
EOF
}

export -f check_aws_security_group get_aws_metadata check_aws_cli create_aws_troubleshooting 