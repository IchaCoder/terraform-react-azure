#!/bin/bash

set -e

# ==============================
# Configuration
# ==============================

REPO_URL="https://github.com/pravinmishraaws/my-react-app.git"
APP_DIR="/opt/my-react-app"
WEB_ROOT="/var/www/html"

echo "========================================"
echo "Starting React Application Deployment"
echo "========================================"

# ==============================
# 1. Update system packages
# ==============================

echo "[1/10] Updating system packages..."

sudo apt-get update -y
sudo apt-get upgrade -y


# ==============================
# 2. Install Node.js and npm
# ==============================

echo "[2/10] Installing Node.js and npm..."

sudo apt-get install -y nodejs npm

echo "Node.js version:"
node --version

echo "npm version:"
npm --version


# ==============================
# 3. Install and enable Nginx
# ==============================

echo "[3/10] Installing Nginx..."

sudo apt-get install -y nginx

sudo systemctl enable nginx
sudo systemctl start nginx

echo "Nginx status:"
sudo systemctl is-active nginx


# ==============================
# 4. Clone React application
# ==============================

echo "[4/10] Cloning React application..."

# Remove previous deployment if it exists
sudo rm -rf "$APP_DIR"

sudo mkdir -p "$APP_DIR"
sudo chown "$USER:$USER" "$APP_DIR"

git clone "$REPO_URL" "$APP_DIR"

cd "$APP_DIR"


# ==============================
# 5. Install dependencies
# ==============================

echo "[5/10] Installing application dependencies..."

npm install


# ==============================
# 6. Build React application
# ==============================

echo "[6/10] Building React application..."

npm run build

if [ ! -d "$APP_DIR/build" ]; then
    echo "ERROR: React build directory was not created."
    exit 1
fi


# ==============================
# 7. Deploy build files
# ==============================

echo "[7/10] Deploying React build to Nginx..."

sudo rm -rf "$WEB_ROOT"/*

sudo cp -r "$APP_DIR/build/"* "$WEB_ROOT/"

sudo chown -R www-data:www-data "$WEB_ROOT"
sudo chmod -R 755 "$WEB_ROOT"


# ==============================
# 8. Configure Nginx
# ==============================

echo "[8/10] Configuring Nginx..."

sudo tee /etc/nginx/sites-available/default > /dev/null <<'NGINX'
server {
    listen 80;
    listen [::]:80;

    server_name _;

    root /var/www/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    error_page 404 /index.html;
}
NGINX


# ==============================
# 9. Test Nginx configuration
# ==============================

echo "[9/10] Testing Nginx configuration..."

sudo nginx -t


# ==============================
# 10. Restart Nginx
# ==============================

echo "[10/10] Restarting Nginx..."

sudo systemctl restart nginx

sudo systemctl enable nginx


# ==============================
# Final verification
# ==============================

echo ""
echo "========================================"
echo "Deployment completed successfully!"
echo "========================================"

echo ""
echo "Nginx status:"
sudo systemctl is-active nginx

echo ""
echo "Testing HTTP response..."

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)

if [ "$HTTP_STATUS" = "200" ]; then
    echo "HTTP test successful: $HTTP_STATUS"
else
    echo "WARNING: HTTP test returned: $HTTP_STATUS"
fi

echo ""
echo "React application is available at:"
echo "http://$(curl -s ifconfig.me)"
echo ""