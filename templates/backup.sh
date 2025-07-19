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