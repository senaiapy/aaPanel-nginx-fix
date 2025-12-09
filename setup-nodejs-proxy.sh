#!/bin/bash

#########################################################
# Node.js Nginx Proxy Setup Script
#
# Configures nginx to reverse proxy to Node.js applications
# Works with aaPanel + Traefik setup
#
# Usage: ./setup-nodejs-proxy.sh DOMAIN PORT [APP_PATH]
#########################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() { echo -e "${CYAN}========================================${NC}"; echo -e "${CYAN}$1${NC}"; echo -e "${CYAN}========================================${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

show_usage() {
    cat << EOF
${CYAN}Usage:${NC}
  $0 DOMAIN PORT [APP_PATH]

${CYAN}Description:${NC}
  Configures nginx to reverse proxy to a Node.js application running on a specific port.
  Creates nginx configuration with WebSocket support and proper headers.

${CYAN}Arguments:${NC}
  DOMAIN              Domain name for the application (e.g., api.example.com)
  PORT                Port where Node.js app runs (e.g., 3000, 5000)
  APP_PATH            Optional: Path to Node.js app for systemd service

${CYAN}Examples:${NC}
  # Basic setup (manual Node.js management)
  $0 api.example.com 3000

  # With app path (creates systemd service)
  $0 api.example.com 3000 /var/www/myapp

  # Next.js application
  $0 nextapp.com 3000 /var/www/nextjs-app

  # Express API
  $0 api.example.com 5000 /var/www/express-api

${CYAN}What This Script Does:${NC}
  1. Creates nginx reverse proxy configuration
  2. Configures WebSocket support
  3. Sets up proper proxy headers
  4. Optionally creates systemd service for Node.js app
  5. Tests nginx configuration
  6. Reloads nginx

${CYAN}Prerequisites:${NC}
  - Domain created in aaPanel (or run this script to create config)
  - Node.js application ready to run on specified port
  - Port fix applied (run fix-site-port.sh if needed)

${CYAN}After Running This Script:${NC}
  - Run: generate-ssl-cert.sh DOMAIN (to get SSL certificate)
  - Start your Node.js app on the specified port
  - Access via: https://DOMAIN

EOF
    exit 0
}

# Check arguments
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
fi

if [ -z "$1" ] || [ -z "$2" ]; then
    print_error "Missing required arguments"
    echo ""
    echo "Usage: $0 DOMAIN PORT [APP_PATH]"
    echo "Use -h or --help for more information"
    exit 1
fi

DOMAIN="$1"
NODE_PORT="$2"
APP_PATH="${3:-}"
NGINX_CONF="/www/server/panel/vhost/nginx/${DOMAIN}.conf"
NGINX_PORT=8080

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root"
    exit 1
fi

print_header "Node.js Nginx Proxy Setup"
echo "Domain:    $DOMAIN"
echo "Node Port: $NODE_PORT"
echo "Nginx Port: $NGINX_PORT"
if [ -n "$APP_PATH" ]; then
    echo "App Path:  $APP_PATH"
fi
echo ""

# Validate port
if ! [[ "$NODE_PORT" =~ ^[0-9]+$ ]] || [ "$NODE_PORT" -lt 1 ] || [ "$NODE_PORT" -gt 65535 ]; then
    print_error "Invalid port number: $NODE_PORT"
    exit 1
fi

# Create nginx configuration
print_header "Creating Nginx Configuration"

# Backup existing config if it exists
if [ -f "$NGINX_CONF" ]; then
    print_warning "Configuration already exists: $NGINX_CONF"
    cp "$NGINX_CONF" "${NGINX_CONF}.backup-$(date +%Y%m%d-%H%M%S)"
    print_success "Created backup"
fi

# Create nginx config directory if it doesn't exist
mkdir -p /www/server/panel/vhost/nginx/
mkdir -p /www/wwwroot/${DOMAIN}

cat > "$NGINX_CONF" << EOF
# Nginx reverse proxy configuration for Node.js application
# Domain: ${DOMAIN}
# Node.js Port: ${NODE_PORT}
# Generated: $(date)

upstream nodejs_${DOMAIN//[.-]/_} {
    server 127.0.0.1:${NODE_PORT};
    keepalive 64;
}

server {
    listen ${NGINX_PORT};
    server_name ${DOMAIN};

    # Logs
    access_log /www/wwwlogs/${DOMAIN}.log;
    error_log /www/wwwlogs/${DOMAIN}.error.log;

    # Client settings
    client_max_body_size 50M;
    client_body_timeout 60s;

    # Proxy settings
    location / {
        proxy_pass http://nodejs_${DOMAIN//[.-]/_};
        proxy_http_version 1.1;

        # Proxy headers
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;

        # WebSocket support
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;

        # Buffering
        proxy_buffering off;
        proxy_request_buffering off;

        # Keep alive
        proxy_set_header Connection "";
    }

    # Health check endpoint (optional)
    location /health {
        proxy_pass http://nodejs_${DOMAIN//[.-]/_}/health;
        access_log off;
    }

    # Static files optimization (if your app serves static files)
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        proxy_pass http://nodejs_${DOMAIN//[.-]/_};
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF

print_success "Created nginx configuration: $NGINX_CONF"

# Test nginx configuration
print_header "Testing Nginx Configuration"
if nginx -t 2>&1 | grep -q "successful"; then
    print_success "Nginx configuration is valid"
else
    print_error "Nginx configuration test failed"
    echo ""
    nginx -t
    exit 1
fi

# Reload nginx
print_info "Reloading nginx..."
systemctl reload nginx
print_success "Nginx reloaded"

# Create systemd service if app path provided
if [ -n "$APP_PATH" ]; then
    print_header "Creating Systemd Service"

    if [ ! -d "$APP_PATH" ]; then
        print_warning "App path does not exist: $APP_PATH"
        print_info "Skipping systemd service creation"
        print_info "Create the directory and run this script again to create the service"
    else
        SERVICE_NAME="nodejs-${DOMAIN//[.]/-}"
        SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

        # Detect package manager and start script
        START_CMD="npm start"
        if [ -f "$APP_PATH/package.json" ]; then
            if grep -q "\"start\"" "$APP_PATH/package.json"; then
                START_CMD="npm start"
                print_info "Detected npm start script"
            elif grep -q "\"dev\"" "$APP_PATH/package.json"; then
                START_CMD="npm run dev"
                print_info "Detected npm dev script"
            fi

            # Check for Next.js
            if grep -q "\"next\"" "$APP_PATH/package.json"; then
                START_CMD="npm run start"
                print_info "Detected Next.js application"
            fi
        fi

        cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Node.js application for ${DOMAIN}
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${APP_PATH}
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

Environment=NODE_ENV=production
Environment=PORT=${NODE_PORT}

[Install]
WantedBy=multi-user.target
EOF

        print_success "Created systemd service: $SERVICE_FILE"

        # Reload systemd
        systemctl daemon-reload
        print_success "Reloaded systemd"

        print_info "To start your application:"
        echo "  systemctl start ${SERVICE_NAME}"
        echo "  systemctl enable ${SERVICE_NAME}  # Auto-start on boot"
        echo "  systemctl status ${SERVICE_NAME}  # Check status"
        echo ""
        print_info "To view logs:"
        echo "  journalctl -u ${SERVICE_NAME} -f"
    fi
fi

# Summary
print_header "Setup Complete"
echo ""
print_success "Nginx is now configured to proxy to your Node.js app"
echo ""
echo "Configuration:"
echo "  Domain: ${DOMAIN}"
echo "  Nginx listens on: ${NGINX_PORT}"
echo "  Proxies to Node.js on: 127.0.0.1:${NODE_PORT}"
echo "  Config file: ${NGINX_CONF}"
echo ""

print_header "Next Steps"
echo ""
echo "1. Start your Node.js application on port ${NODE_PORT}"
if [ -n "$APP_PATH" ] && [ -d "$APP_PATH" ]; then
    echo "   systemctl start nodejs-${DOMAIN//[.]/-}"
    echo "   systemctl enable nodejs-${DOMAIN//[.]/-}"
else
    echo "   cd /path/to/your/app"
    echo "   PORT=${NODE_PORT} npm start"
fi
echo ""

echo "2. Generate SSL certificate:"
echo "   sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh ${DOMAIN}"
echo ""

echo "3. Test your application:"
echo "   # Direct test (nginx proxy)"
echo "   curl -H 'Host: ${DOMAIN}' http://localhost:${NGINX_PORT}"
echo ""
echo "   # After SSL setup"
echo "   curl https://${DOMAIN}"
echo ""

print_header "Useful Commands"
echo ""
echo "# Check if Node.js app is running on port ${NODE_PORT}"
echo "ss -tlnp | grep ${NODE_PORT}"
echo ""
echo "# Test nginx proxy"
echo "curl -H 'Host: ${DOMAIN}' http://localhost:${NGINX_PORT}"
echo ""
echo "# View nginx logs"
echo "tail -f /www/wwwlogs/${DOMAIN}.log"
echo "tail -f /www/wwwlogs/${DOMAIN}.error.log"
echo ""

if [ -n "$APP_PATH" ] && [ -d "$APP_PATH" ]; then
    echo "# Manage Node.js service"
    echo "systemctl status nodejs-${DOMAIN//[.]/-}"
    echo "systemctl restart nodejs-${DOMAIN//[.]/-}"
    echo "journalctl -u nodejs-${DOMAIN//[.]/-} -f"
    echo ""
fi

print_success "Configuration saved!"
