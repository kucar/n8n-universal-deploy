#!/bin/bash
# n8n Troubleshooting Script

echo "=== n8n Troubleshooting ==="
echo

echo "1. Checking container status..."
docker compose ps
echo

echo "2. Checking container logs (last 50 lines)..."
echo "--- PostgreSQL logs ---"
docker compose logs postgres --tail=50
echo
echo "--- n8n logs ---"
docker compose logs n8n --tail=50
echo

if [ -f docker-compose.yml ] && grep -q "traefik" docker-compose.yml; then
    echo "--- Traefik logs ---"
    docker compose logs traefik --tail=50
    echo
fi
echo "3. Checking port availability..."
sudo netstat -tlnp | grep -E '(80|443|5678)' || sudo ss -tlnp | grep -E '(80|443|5678)'
echo

echo "4. Checking Docker networks..."
docker network ls
echo

echo "5. Testing n8n health endpoint..."
docker exec n8n wget -O- http://localhost:5678/healthz 2>/dev/null || echo "n8n health check failed"
echo

echo "6. Checking DNS resolution..."
if [ -n "$N8N_HOST" ]; then
    echo "Resolving $N8N_HOST..."
    dig +short $N8N_HOST || nslookup $N8N_HOST
fi
echo

echo "7. Checking SSL certificate (if applicable)..."
if [ -f docker-compose.yml ] && grep -q "traefik" docker-compose.yml; then
    echo "Checking certificate status..."
    docker exec traefik cat /letsencrypt/acme.json 2>/dev/null | grep -q "certificate" && echo "Certificate found" || echo "No certificate found"
    
    # Check if we can connect via HTTPS
    if [ -n "$N8N_HOST" ]; then
        echo "Testing HTTPS connection..."
        curl -I https://$N8N_HOST 2>&1 | head -n 10
    fi
fi
echo

echo "8. System resources..."
echo "Memory usage:"
free -h
echo
echo "Disk usage:"
df -h
echo
echo "Docker disk usage:"
docker system df
echo

echo "9. Environment check..."
if [ -f .env ]; then
    echo "Key environment variables (sensitive values hidden):"
    grep -E "N8N_HOST|DEPLOYMENT_MODE|N8N_PROTOCOL" .env
else
    echo ".env file not found!"
fi
echo

echo "10. Common issues and solutions:"
echo "───────────────────────────────"
echo "• SSL certificate issues: Run './ssl-fix.sh' to force renewal"
echo "• Cannot access n8n: Check firewall rules and security groups"
echo "• Database connection failed: Check PostgreSQL container status"
echo "• Out of memory: Increase Docker memory limits or upgrade instance"
echo

echo "For more help, check the logs above or run:"
echo "  docker compose logs -f    # Follow all logs"
echo "  docker compose restart    # Restart all services" 