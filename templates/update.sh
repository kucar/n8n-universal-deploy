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