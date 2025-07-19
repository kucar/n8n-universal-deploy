# Universal n8n Deployment Script

A comprehensive, platform-generic script for deploying n8n workflow automation platform on various cloud providers and local environments.

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

```bash
# Download the script
wget https://raw.githubusercontent.com/your-repo/n8n-deploy/main/deploy-n8n.sh
# Or
curl -O https://raw.githubusercontent.com/your-repo/n8n-deploy/main/deploy-n8n.sh

# Make it executable
chmod +x deploy-n8n.sh

# Run the script
./deploy-n8n.sh
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
   ```
   ~/n8n-production/
   ├── docker-compose.yml
   ├── .env
   ├── init-data.sh
   ├── backup.sh
   ├── update.sh
   ├── credentials.txt
   ├── local-files/
   └── backups/
   ```
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

### `.env` File
Contains all environment variables:
- Domain configuration
- Database credentials
- Security settings
- Performance tuning

### `docker-compose.yml`
Docker Compose configuration tailored to your deployment mode

### `backup.sh`
Automated backup script for database and n8n data

### `update.sh`
Safe update script with automatic backup

## Post-Installation

### Access n8n

After successful deployment:
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

# View stored credentials
cat ~/n8n-production/credentials.txt
```

## Troubleshooting

### SSL Certificate Issues

If you see "dangerous site" warnings:
1. Check DNS propagation: `dig your-domain.com`
2. View Traefik logs: `docker compose logs traefik`
3. Ensure ports 80/443 are open
4. Check Let's Encrypt rate limits

### Connection Issues

1. Verify all containers are running: `docker compose ps`
2. Check n8n logs: `docker compose logs n8n`
3. Ensure firewall rules are correct: `sudo ufw status` or `sudo firewall-cmd --list-all`

### Database Connection

1. Check PostgreSQL logs: `docker compose logs postgres`
2. Verify environment variables: `docker compose config`
3. Test database connection: 
   ```bash
   docker compose exec postgres psql -U n8n_admin -d n8n_production -c "\l"
   ```

## Security Considerations

1. **Change default passwords** immediately after installation
2. **Enable 2FA** in n8n user settings
3. **Regular backups** using the provided backup script
4. **Keep system updated**: Run `./update.sh` periodically
5. **Monitor logs** for suspicious activity
6. **Use strong passwords** for all accounts

## Advanced Configuration

### Custom PostgreSQL Settings

Edit the PostgreSQL service in `docker-compose.yml`:
```yaml
postgres:
  command: 
    - "postgres"
    - "-c"
    - "max_connections=200"
    - "-c"
    - "shared_buffers=256MB"
```

### Performance Tuning

Modify n8n environment variables in `.env`:
```bash
EXECUTIONS_TIMEOUT=7200  # 2 hours
EXECUTIONS_DATA_MAX_AGE=168  # 7 days
N8N_PAYLOAD_SIZE_MAX=64  # 64MB
```

### External Database

To use an external database, modify the `.env` file:
```bash
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=your-external-db.com
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8n_user
DB_POSTGRESDB_PASSWORD=your_password
DB_POSTGRESDB_SSL_ENABLED=true
```

## Backup and Recovery

### Automated Backups

Set up a cron job:
```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * cd /home/ubuntu/n8n-production && ./backup.sh
```

### Manual Recovery

```bash
# Restore database
docker exec -i postgres psql -U n8n_admin n8n_production < backups/n8n-db-20250718-021000.sql

# Restore n8n data
docker run --rm -v n8n-production_n8n_data:/data -v $PWD/backups:/backup alpine tar xzf /backup/n8n-data-20250718-021000.tar.gz -C /data
```

## Support

For issues specific to:
- **This script**: Open an issue on GitHub
- **n8n**: Visit [n8n Community](https://community.n8n.io/)
- **Docker**: Check [Docker Documentation](https://docs.docker.com/)

## License

This deployment script is provided as-is under the MIT License.