#!/bin/bash
# =====================================================
# Muallimus Soniy — First-Time Server Setup Script
# Target: Ubuntu 22.04
# Path: /var/www/ikkinchimuallim/
# =====================================================

set -euo pipefail

PROJECT_DIR="/var/www/ikkinchimuallim"
DOMAIN="ikkinchimuallim.codingtech.uz"
API_DOMAIN="api.ikkinchimuallim.codingtech.uz"
EMAIL="admin@codingtech.uz"

echo "==========================================="
echo " Muallimus Soniy — Server Setup"
echo "==========================================="

# 1. Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo ">>> Installing Docker..."
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    echo "Docker installed ✅"
else
    echo "Docker already installed ✅"
fi

# 2. Create project directory
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# 3. Create certbot directories
mkdir -p /var/www/certbot
mkdir -p "$PROJECT_DIR/deploy/nginx/ssl"

# 4. Create placeholder web directory (Flutter build will go here)
mkdir -p "$PROJECT_DIR/frontend/build/web"
cat > "$PROJECT_DIR/frontend/build/web/index.html" << 'PLACEHOLDER'
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>Muallimus Soniy</title>
<style>body{font-family:Inter,sans-serif;background:#0f1117;color:#e8eaed;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;}
.c{text-align:center}.e{font-size:48px;margin-bottom:16px}h1{font-size:24px;margin:0}p{color:#9aa0a6;margin-top:8px}</style>
</head>
<body><div class="c"><div class="e">📖</div><h1>Muallimus Soniy</h1><p>Ilova tez orada ishga tushadi...</p></div></body>
</html>
PLACEHOLDER

echo ">>> Directories created ✅"

# 5. Build and start services
echo ">>> Building Docker images..."
docker compose build

echo ">>> Starting services (HTTP mode)..."
docker compose up -d

# Wait for services to be healthy
echo ">>> Waiting for services to start..."
sleep 15

# 6. Run database migrations
echo ">>> Running database migrations..."
docker compose exec -T api alembic upgrade head || echo "Migration may need manual review"

# 7. Test health check
echo ">>> Testing health endpoint..."
if curl -sf http://localhost/health > /dev/null 2>&1; then
    echo "Health check passed ✅"
else
    echo "Health check via nginx failed, trying API directly..."
    curl -sf http://localhost:8000/health && echo " API health OK ✅" || echo "⚠️  API not responding yet"
fi

# 8. Obtain SSL certificates
echo ""
echo ">>> Obtaining SSL certificates..."
echo "Stopping nginx temporarily..."
docker compose stop nginx

# Get certs via standalone method
if command -v certbot &> /dev/null; then
    echo "Using existing certbot..."
else
    apt-get install -y certbot
fi

certbot certonly --standalone \
    -d "$DOMAIN" \
    -d "$API_DOMAIN" \
    --email "$EMAIL" \
    --agree-tos \
    --non-interactive \
    || echo "⚠️  Certbot failed — DNS may not be pointing to this server yet"

# 9. Switch to SSL Nginx configs if certs exist
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo ">>> Switching to SSL Nginx config..."

    # Mount letsencrypt certs to nginx
    # Replace the HTTP configs with SSL configs
    cp "$PROJECT_DIR/deploy/nginx/sites-ssl/all.conf" "$PROJECT_DIR/deploy/nginx/sites/web.conf"
    # Remove api.conf since all.conf has both
    rm -f "$PROJECT_DIR/deploy/nginx/sites/api.conf"

    echo "SSL configs applied ✅"
else
    echo "⚠️  SSL certs not found, staying in HTTP mode"
fi

# Restart nginx
docker compose up -d nginx

# 10. Set up auto-renewal cron
(crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet && docker compose -f $PROJECT_DIR/docker-compose.yml restart nginx") | sort -u | crontab -

echo ""
echo "==========================================="
echo " Setup Complete! 🎉"
echo "==========================================="
echo ""
echo " Web:   http://$DOMAIN"
echo " API:   http://$API_DOMAIN"
echo " Admin: http://$DOMAIN/admin/"
echo " Docs:  http://$API_DOMAIN/docs"
echo ""
echo " Default admin: admin / (check .env ADMIN_PASSWORD)"
echo ""
echo " Next steps:"
echo "   1. Verify DNS A records point to this server"
echo "   2. Re-run certbot if SSL failed: certbot certonly --standalone -d $DOMAIN -d $API_DOMAIN"
echo "   3. Build Flutter web and replace frontend/build/web/"
echo ""
