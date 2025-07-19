#!/bin/bash
# SSL Certificate Fix Script for n8n

echo "=== SSL Certificate Force Renewal ==="
echo

# Load environment
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found!"
    exit 1
fi

if [ "$DEPLOYMENT_MODE" != "production" ]; then
    echo "SSL certificates are only used in production mode."
    echo "Current mode: $DEPLOYMENT_MODE"
    exit 0
fi

echo "This will force renewal of SSL certificates for: $N8N_HOST"
echo "WARNING: This will cause a brief downtime!"
echo
read -p "Continue? [y/N]: " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

echo
echo "1. Stopping services..."
docker compose down

echo
echo "2. Removing old certificate data..."
docker volume rm n8n-production_traefik_data 2>/dev/null || echo "No existing certificate data found"

echo
echo "3. Starting services..."
docker compose up -d

echo
echo "4. Monitoring certificate generation..."
echo "Waiting for Traefik to start..."
sleep 10

echo
echo "5. Checking certificate status..."
timeout 60 docker compose logs -f traefik | grep -E "(certificate|Certificate|acme|ACME)" &

echo
echo "Waiting for certificate generation (this may take up to 60 seconds)..."
sleep 30

echo
echo "6. Testing HTTPS connection..."
if curl -I https://$N8N_HOST 2>&1 | grep -q "200 OK\|302 Found\|301 Moved"; then
    echo "✅ SSL certificate successfully renewed!"
    echo "You can now access n8n at: https://$N8N_HOST"
else
    echo "⚠️  HTTPS test failed. Checking logs..."
    docker compose logs traefik --tail=50 | grep -i error
    echo
    echo "Troubleshooting tips:"
    echo "• Ensure port 80 is open in your firewall/security group"
    echo "• Verify DNS is pointing to this server"
    echo "• Check Traefik logs: docker compose logs traefik -f"
    echo "• Wait a few more minutes and try again"
fi 