# Universal n8n Deployment Script

A comprehensive, modular, platform-generic solution for deploying the n8n workflow automation platform on various cloud providers and local environments.

## ✨ New in v1.1.0

- 🏗️ **Modular Architecture**: Script split into manageable modules for easier maintenance
- 🔍 **Cloud Provider Detection**: Automatic detection for AWS, Azure, GCP, DigitalOcean
- 🛡️ **AWS Security Group Warnings**: Specific checks and guidance for AWS EC2 deployments
- 🛠️ **Enhanced Troubleshooting**: New `troubleshoot.sh` script with comprehensive diagnostics
- 🔒 **SSL Certificate Fix Tool**: Easy SSL certificate renewal with `ssl-fix.sh`
- 🚀 **Improved Docker Installation**: Docker check moved to the beginning to avoid script restart
- 📊 **Better Error Messages**: More informative error handling and recovery suggestions

## Features

- 🚀 **Multi-Platform Support**: AWS EC2, DigitalOcean, Azure, GCP, and local installations
- 🔒 **SSL/TLS Support**: Automatic Let's Encrypt certificate generation with Traefik
- 🗄️ **PostgreSQL Database**: Production-ready database setup with proper user separation
- 🛡️ **Security First**: Firewall configuration, secure password generation, encryption keys
- 🔧 **Multiple Deployment Modes**:
  - Production with domain (SSL enabled)
  - Local development (localhost)
  - Internal network (private IP)
- 📦 **Docker Installation**: Checks for Docker early and installs if needed
- 🔄 **Maintenance Scripts**: Backup, update, troubleshoot, and SSL fix utilities
- 🎯 **Smart Validation**: Domain, email, and IP validation with DNS verification

## Prerequisites

- Ubuntu 20.04+ / Debian 10+ / CentOS 8+ / RHEL 8+ / Fedora 33+
- Non-root user with sudo privileges
- For production: A domain pointing to your server's IP
- For AWS: Security group with ports 80, 443, and 22 open

## Quick Start

### Clone the Repository (Recommended)

```bash
git clone https://github.com/kucar/n8n-universal-deploy.git
cd n8n-universal-deploy
chmod +x deploy-n8n.sh
./deploy-n8n.sh
```

## Directory Structure

```
n8n-universal-deploy/
├── deploy-n8n.sh         # Main deployment script
├── lib/                  # Modular library functions
│   ├── common.sh         # Common functions, logging, Docker install
│   ├── detection.sh      # OS and cloud provider detection
│   ├── validation.sh     # Input validation functions
│   ├── security.sh       # Password generation, credentials
│   └── aws.sh           # AWS-specific checks and functions
├── templates/            # Template files
│   ├── docker-compose-ssl.yml     # Production Docker Compose
│   ├── docker-compose-local.yml   # Local/dev Docker Compose
│   ├── init-data.sh              # PostgreSQL initialization
│   ├── backup.sh                 # Backup script
│   ├── update.sh                 # Update script
│   ├── troubleshoot.sh           # Diagnostics script
│   └── ssl-fix.sh                # SSL certificate renewal
└── README.md
```

## Deployment Process

1. **Docker Check**: Verifies Docker installation (installs if needed)
2. **Cloud Detection**: Identifies if running on AWS/Azure/GCP/DigitalOcean
3. **Deployment Mode**: Choose production, local, or internal network
4. **Configuration**: Domain setup, SSL certificates, credentials
5. **Security**: Firewall rules, AWS security group checks
6. **Deployment**: Creates containers and starts services

## Deployment Modes

### 1. Production with Domain (Recommended for cloud)
- Full SSL/TLS encryption with Let's Encrypt
- Automatic HTTPS redirect
- Traefik reverse proxy
- Security headers enabled

Requirements:
- Valid domain name
- Domain DNS A record pointing to server IP
- Ports 80 and 443 open

### 2. Local Development
- HTTP only (no SSL)
- Accessible at `http://localhost:5678`
- Simplified setup for testing
- No Traefik required

### 3. Internal Network
- HTTP only
- Custom IP or hostname
- For private networks
- Firewall configuration optional

## Post-Installation

### Access n8n
- **Production**: `https://your-domain.com`
- **Local**: `http://localhost:5678`
- **Internal**: `http://your-ip-or-hostname:5678`

### Default Credentials
All credentials are:
1. Displayed in the terminal after installation
2. Saved to `~/n8n-production/credentials.txt` (chmod 600)

### Useful Commands

```bash
# View logs
cd ~/n8n-production && docker compose logs -f

# Stop n8n
cd ~/n8n-production && docker compose down

# Start n8n
cd ~/n8n-production && docker compose up -d

# Backup data
cd ~/n8n-production && ./backup.sh

# Update n8n
cd ~/n8n-production && ./update.sh

# Troubleshoot issues
cd ~/n8n-production && ./troubleshoot.sh

# Fix SSL certificate (production only)
cd ~/n8n-production && ./ssl-fix.sh
```

## AWS EC2 Specific Notes

### Security Group Configuration

The script will detect AWS EC2 instances and warn about security group configuration. You **must** ensure these inbound rules:

- **Port 80 (HTTP)**: Required for Let's Encrypt certificate validation
- **Port 443 (HTTPS)**: For secure access to n8n
- **Port 22 (SSH)**: For remote access (restrict to your IP)

⚠️ **Important**: Without port 80 open, SSL certificate generation will fail!

### Troubleshooting SSL on AWS

If SSL certificate generation fails:

1. Verify security group allows port 80 from 0.0.0.0/0
2. Check DNS propagation: `dig your-domain.com`
3. Run the SSL fix script: `./ssl-fix.sh`
4. Monitor Traefik logs: `docker logs -f traefik`

## Security Considerations

- Change default passwords immediately after installation
- Enable 2FA in n8n user settings
- Regular backups using `./backup.sh`
- Keep system updated with `./update.sh`
- Monitor logs for suspicious activity
- Use strong passwords for all accounts

## Advanced Configuration

### Custom PostgreSQL Settings
Edit `docker-compose.yml` to modify PostgreSQL parameters.

### Performance Tuning
Modify environment variables in `.env`:
- `EXECUTIONS_TIMEOUT`: Maximum execution time
- `EXECUTIONS_DATA_MAX_AGE`: How long to keep execution data
- `N8N_PAYLOAD_SIZE_MAX`: Maximum payload size

### External Database
Edit `.env` to connect to an external PostgreSQL database.

## Troubleshooting

### Common Issues

1. **"Docker not found"**
   - The script will offer to install Docker
   - After installation, log out and back in, then run the script again

2. **"Connection refused" on AWS**
   - Check security group rules
   - Ensure ports 80 and 443 are open

3. **SSL Certificate Errors**
   - Run `./ssl-fix.sh` to force renewal
   - Check DNS is pointing to correct IP
   - Verify port 80 is accessible

4. **n8n not accessible**
   - Run `./troubleshoot.sh` for diagnostics
   - Check `docker compose logs n8n`
   - Verify all containers are running: `docker compose ps`

## Support

- **This script**: [Open an issue](https://github.com/kucar/n8n-universal-deploy/issues)
- **n8n**: [n8n Community](https://community.n8n.io/)
- **Docker**: [Docker Documentation](https://docs.docker.com/)

## License

This deployment script is provided as-is under the MIT License.
