# Universal n8n Deployment Script

A comprehensive, platform-generic solution for deploying the n8n workflow automation platform on various cloud providers and local environments.

## Features

- 🚀 **Multi-Platform Support**: AWS EC2, DigitalOcean, Azure, GCP, and local installations
- 🔒 **SSL/TLS Support**: Automatic Let's Encrypt certificate generation with Traefik
- 🗄️ **PostgreSQL Database**: Production-ready database setup with proper user separation
- 🛡️ **Security First**: Firewall configuration, secure password generation, encryption keys
- 🔧 **Multiple Deployment Modes**:
  - Production with domain (SSL enabled)
  - Local development (localhost)
  - Internal network (private IP)
- 📦 **Complete Docker Setup**: Automated Docker and Docker Compose installation
- 🔄 **Backup & Update Scripts**: Included utilities for maintenance
- 🎯 **Smart Validation**: Domain, email, and IP validation with DNS verification

## Prerequisites

- Ubuntu 20.04+ / Debian 10+ / CentOS 8+ / RHEL 8+ / Fedora 33+
- Non-root user with sudo privileges
- For production: A domain pointing to your server's IP

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
├── lib/                  # Helper scripts (sourced by main script)
│   ├── common.sh
│   ├── detection.sh
│   ├── validation.sh
│   ├── security.sh
│   └── aws.sh
├── templates/            # Static templates for compose, backup, etc.
│   ├── backup.sh
│   ├── docker-compose-local.yml
│   ├── docker-compose-ssl.yml
│   ├── init-data.sh
│   ├── ssl-fix.sh
│   ├── troubleshoot.sh
│   └── update.sh
└── README.md
```

## Deployment Modes

### 1. Production with Domain (Recommended for cloud)
- Full SSL/TLS encryption with Let's Encrypt
- Automatic HTTPS redirect
- Traefik reverse proxy
- Security headers enabled

Requirements:
- Valid domain name
- Domain DNS A record pointing to server IP
- Port 80 and 443 open

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

## What the Script Does

1. **OS Detection**: Automatically detects your operating system
2. **Docker Installation**: Installs Docker if not present
3. **Firewall Setup**: Configures UFW (Ubuntu/Debian) or firewalld (RHEL/CentOS)
4. **Project Structure Creation**:
5. **Security Configuration**:
   - Generates secure passwords
   - Creates encryption keys
   - Sets up basic authentication
   - Configures PostgreSQL users
6. **Service Deployment**:
   - PostgreSQL database
   - n8n workflow engine
   - Traefik (for SSL deployments)

## Configuration Files

- `.env`: All environment variables (domain, database, security, performance)
- `docker-compose.yml`: Docker Compose configuration (mode-specific)
- `backup.sh`: Automated backup script
- `update.sh`: Safe update script

## Post-Installation

### Access n8n
- **Production**: `https://your-domain.com`
- **Local**: `http://localhost:5678`
- **Internal**: `http://your-ip-or-hostname:5678`

### Credentials
- Displayed in the terminal after installation
- Saved to `~/n8n-production/credentials.txt` (chmod 600)

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

# View stored credentials
cat ~/n8n-production/credentials.txt
```

## Security Considerations

- Change default passwords immediately
- Enable 2FA in n8n user settings
- Regular backups
- Keep system updated (`./update.sh`)
- Monitor logs
- Use strong passwords

## Advanced Configuration

- **Custom PostgreSQL Settings**: Edit `docker-compose.yml`
- **Performance Tuning**: Edit `.env` (timeouts, payload size, etc.)
- **External Database**: Edit `.env` for external DB connection

## Backup and Recovery

- **Automated Backups**: Use cron to run `backup.sh`
- **Manual Recovery**: Use provided commands to restore database and data

## Support

- **This script**: Open an issue on GitHub
- **n8n**: [n8n Community](https://community.n8n.io/)
- **Docker**: [Docker Documentation](https://docs.docker.com/)

## License

This deployment script is provided as-is under the MIT License.

## AWS EC2 Notes & SSL Troubleshooting

### AWS EC2 Security Group

If you are deploying on AWS EC2, you **must** update your instance's Security Group after the script finishes:

- **Inbound:** Allow TCP ports 22 (SSH), 80 (HTTP), and 443 (HTTPS) from 0.0.0.0/0 (or restrict as needed).
- **Outbound:** Allow all traffic (default is usually open, but verify).
- If you have issues connecting, you can temporarily allow all traffic in/out for troubleshooting, but restrict to only required ports for production.

### SSL Certificate Issues (Let's Encrypt / Traefik)

If SSL certificate generation fails or you see browser warnings:

1. **Stop services:**
   ```bash
   cd ~/n8n-production
   docker compose down
   ```
2. **Remove old certificate data:**
   ```bash
   docker volume rm n8n-production_traefik_data
   ```
3. **Restart services:**
   ```bash
   docker compose up -d
   ```
4. **Monitor Traefik logs for certificate generation:**
   ```bash
   docker logs -f traefik
   ```
5. **Check your DNS:** Ensure your domain's A record points to your EC2 public IP.
6. **Check Security Group:** Ports 80 and 443 must be open to the world for Let's Encrypt to validate your domain.

If you continue to have issues, check for:
- DNS propagation delays
- Let's Encrypt rate limits
- Firewall or cloud provider network restrictions

For more help, see the [n8n Community](https://community.n8n.io/) or open an issue on GitHub.