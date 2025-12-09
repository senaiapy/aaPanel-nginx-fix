#!/bin/bash

#########################################################
# Complete Node.js Deployment Script
#
# One command to deploy Node.js applications with:
# - Nginx reverse proxy
# - Systemd service
# - SSL certificate
#
# Usage: ./deploy-nodejs.sh DOMAIN PORT APP_PATH
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
${CYAN}Complete Node.js Deployment Script${NC}

${CYAN}Usage:${NC}
  $0 DOMAIN PORT APP_PATH

${CYAN}Description:${NC}
  Deploy a Node.js application with one command:
  1. Configure nginx reverse proxy
  2. Create and start systemd service
  3. Generate SSL certificate with Traefik
  4. Verify deployment

${CYAN}Arguments:${NC}
  DOMAIN        Domain name (e.g., api.example.com)
  PORT          Port for Node.js app (e.g., 3000, 5000)
  APP_PATH      Path to Node.js application

${CYAN}Examples:${NC}
  # Express API
  $0 api.example.com 5000 /var/www/express-api

  # Next.js app
  $0 app.example.com 3000 /var/www/nextjs-app

  # Custom Node.js server
  $0 nodeapp.com 3331 /www/wwwroot/nodeapp.com

${CYAN}Prerequisites:${NC}
  - Node.js application in APP_PATH with server.js
  - DNS pointing to this server
  - Traefik running (ports 80/443)
  - Nginx running (port 8080)

${CYAN}What This Does:${NC}
  ✓ Creates nginx reverse proxy configuration
  ✓ Creates systemd service for auto-management
  ✓ Starts your Node.js application
  ✓ Enables auto-start on boot
  ✓ Generates Let's Encrypt SSL certificate
  ✓ Configures Traefik routing
  ✓ Verifies HTTPS access

${CYAN}After Running:${NC}
  Your app will be live at: https://DOMAIN

EOF
    exit 0
}

# Check arguments
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
fi

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    print_error "Missing required arguments"
    echo ""
    echo "Usage: $0 DOMAIN PORT APP_PATH"
    echo "Use -h or --help for more information"
    exit 1
fi

DOMAIN="$1"
PORT="$2"
APP_PATH="$3"
SCRIPT_DIR="/root/aaPanel-nginx-fix"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root"
    exit 1
fi

# Validate app path exists
if [ ! -d "$APP_PATH" ]; then
    print_error "Application path does not exist: $APP_PATH"
    exit 1
fi

# Check for server.js
if [ ! -f "$APP_PATH/server.js" ]; then
    print_warning "server.js not found in $APP_PATH"
    print_info "Make sure your Node.js application has a server.js file"
    echo ""
    read -p "Continue anyway? (y/n): " answer
    if [ "$answer" != "y" ]; then
        print_info "Deployment cancelled"
        exit 0
    fi
fi

print_header "Complete Node.js Deployment"
echo ""
echo "Domain:      $DOMAIN"
echo "Port:        $PORT"
echo "App Path:    $APP_PATH"
echo ""
echo "Deployment will:"
echo "  1. Setup nginx reverse proxy"
echo "  2. Create systemd service"
echo "  3. Start Node.js application"
echo "  4. Generate SSL certificate"
echo "  5. Verify HTTPS access"
echo ""
read -p "Continue? (y/n): " answer
if [ "$answer" != "y" ]; then
    print_info "Deployment cancelled"
    exit 0
fi

#########################################################
# Step 1: Setup Nginx Proxy
#########################################################

print_header "Step 1: Nginx Reverse Proxy Setup"

if [ ! -f "$SCRIPT_DIR/setup-nodejs-proxy.sh" ]; then
    print_error "setup-nodejs-proxy.sh not found at $SCRIPT_DIR"
    exit 1
fi

if ! bash "$SCRIPT_DIR/setup-nodejs-proxy.sh" "$DOMAIN" "$PORT" "$APP_PATH"; then
    print_error "Failed to setup nginx proxy"
    exit 1
fi

print_success "Nginx proxy configured"
echo ""

#########################################################
# Step 2: Start Node.js Application
#########################################################

print_header "Step 2: Starting Node.js Application"

SERVICE_NAME="nodejs-${DOMAIN//[.]/-}"

# Check if service exists
if ! systemctl list-unit-files | grep -q "^${SERVICE_NAME}.service"; then
    print_error "Systemd service not created: ${SERVICE_NAME}"
    exit 1
fi

print_info "Starting service: ${SERVICE_NAME}"
systemctl daemon-reload

# Stop if already running
if systemctl is-active --quiet "$SERVICE_NAME"; then
    print_warning "Service already running, restarting..."
    systemctl restart "$SERVICE_NAME"
else
    systemctl start "$SERVICE_NAME"
fi

# Wait for service to start
sleep 2

# Check if started successfully
if systemctl is-active --quiet "$SERVICE_NAME"; then
    print_success "Service started successfully"
else
    print_error "Service failed to start"
    echo ""
    print_info "Checking service status..."
    systemctl status "$SERVICE_NAME" --no-pager -l
    echo ""
    print_info "Checking logs..."
    journalctl -u "$SERVICE_NAME" -n 20 --no-pager
    exit 1
fi

# Enable auto-start
print_info "Enabling auto-start on boot..."
systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
print_success "Auto-start enabled"

# Verify port is listening
print_info "Verifying Node.js is listening on port $PORT..."
sleep 1
if ss -tlnp | grep -q ":$PORT"; then
    print_success "Node.js listening on port $PORT"
else
    print_warning "Port $PORT not detected, checking service logs..."
    journalctl -u "$SERVICE_NAME" -n 10 --no-pager
fi

echo ""

#########################################################
# Step 3: Test Nginx Proxy
#########################################################

print_header "Step 3: Testing Nginx Proxy"

print_info "Testing direct Node.js connection..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT | grep -q "200"; then
    print_success "Direct Node.js connection working"
else
    print_warning "Direct connection check inconclusive"
fi

print_info "Testing nginx proxy..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: $DOMAIN" http://localhost:8080)
if [ "$HTTP_CODE" = "200" ]; then
    print_success "Nginx proxy working (HTTP 200)"
else
    print_warning "Nginx proxy returned HTTP $HTTP_CODE"
fi

echo ""

#########################################################
# Step 4: Generate SSL Certificate
#########################################################

print_header "Step 4: SSL Certificate Generation"

if [ ! -f "$SCRIPT_DIR/generate-ssl-cert.sh" ]; then
    print_error "generate-ssl-cert.sh not found at $SCRIPT_DIR"
    exit 1
fi

print_info "Generating SSL certificate for $DOMAIN..."
echo ""

if ! bash "$SCRIPT_DIR/generate-ssl-cert.sh" "$DOMAIN"; then
    print_error "SSL certificate generation failed"
    print_warning "Your app is accessible via HTTP but HTTPS setup failed"
    print_info "You can try again later with:"
    print_info "  sudo $SCRIPT_DIR/generate-ssl-cert.sh $DOMAIN"
    exit 1
fi

echo ""

#########################################################
# Step 5: Final Verification
#########################################################

print_header "Step 5: Final Verification"

print_info "Waiting for services to stabilize..."
sleep 3

# Check service status
if systemctl is-active --quiet "$SERVICE_NAME"; then
    print_success "Node.js service is running"
else
    print_error "Node.js service is not running"
fi

# Check nginx
if systemctl is-active --quiet nginx; then
    print_success "Nginx is running"
else
    print_warning "Nginx is not running"
fi

# Test HTTPS
print_info "Testing HTTPS access..."
HTTPS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" --max-time 10 2>/dev/null || echo "000")

if [ "$HTTPS_CODE" = "200" ]; then
    print_success "HTTPS access working!"
elif [ "$HTTPS_CODE" = "000" ]; then
    print_warning "HTTPS connection timed out (may still be initializing)"
else
    print_warning "HTTPS returned code: $HTTPS_CODE"
fi

echo ""

#########################################################
# Deployment Complete
#########################################################

print_header "Deployment Complete!"

echo ""
echo "${GREEN}✓ Your Node.js application is deployed!${NC}"
echo ""
echo "Domain:          https://$DOMAIN"
echo "Service:         $SERVICE_NAME"
echo "App Path:        $APP_PATH"
echo "Port:            $PORT"
echo ""

print_header "Quick Commands"
echo ""
echo "# View service status"
echo "systemctl status $SERVICE_NAME"
echo ""
echo "# View logs"
echo "journalctl -u $SERVICE_NAME -f"
echo ""
echo "# Restart application"
echo "systemctl restart $SERVICE_NAME"
echo ""
echo "# Test your application"
echo "curl https://$DOMAIN"
echo ""

print_header "Service Information"
echo ""
echo "Nginx config:    /www/server/panel/vhost/nginx/${DOMAIN}.conf"
echo "Systemd service: /etc/systemd/system/${SERVICE_NAME}.service"
echo "Traefik config:  /root/ssl-configs/${DOMAIN//[.]/-}.yml"
echo ""

# Show service status
print_info "Current service status:"
systemctl status "$SERVICE_NAME" --no-pager -l | head -15

echo ""
print_success "Deployment completed successfully!"
print_info "Access your application at: ${CYAN}https://${DOMAIN}${NC}"
echo ""
