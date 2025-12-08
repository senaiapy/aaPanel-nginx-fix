#!/bin/bash

#########################################################
# aaPanel Site Port Fixer
#
# Automatically fixes nginx port configuration for sites
# created in aaPanel to use port 8080 instead of 80
#
# Usage: ./fix-site-port.sh DOMAIN
#########################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

# Check if domain provided
if [ -z "$1" ]; then
    print_error "No domain provided"
    echo ""
    echo "Usage: $0 DOMAIN"
    echo ""
    echo "Example:"
    echo "  $0 example.com"
    echo ""
    exit 1
fi

DOMAIN="$1"
NGINX_CONF="/www/server/panel/vhost/nginx/${DOMAIN}.conf"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root"
    exit 1
fi

# Check if config file exists
if [ ! -f "$NGINX_CONF" ]; then
    print_error "Nginx config not found: $NGINX_CONF"
    print_info "Make sure the site exists in aaPanel first"
    exit 1
fi

print_info "Checking nginx configuration for $DOMAIN..."

# Check current port
if grep -q "listen 80;" "$NGINX_CONF"; then
    print_warning "Found 'listen 80;' - needs fixing"

    # Backup
    cp "$NGINX_CONF" "${NGINX_CONF}.backup-$(date +%Y%m%d-%H%M%S)"
    print_success "Created backup"

    # Fix port 80 → 8080
    sed -i 's/listen 80;/listen 8080;/g' "$NGINX_CONF"
    print_success "Changed port 80 → 8080"

    # Fix port 443 → 8443 if exists
    if grep -q "listen 443" "$NGINX_CONF"; then
        sed -i 's/listen 443/listen 8443/g' "$NGINX_CONF"
        print_success "Changed port 443 → 8443"
    fi

    # Test nginx config
    print_info "Testing nginx configuration..."
    if nginx -t 2>&1 | grep -q "successful"; then
        print_success "Nginx configuration is valid"

        # Reload nginx
        print_info "Reloading nginx..."
        systemctl reload nginx
        print_success "Nginx reloaded"

        echo ""
        print_success "Site port configuration fixed!"
        echo ""
        print_info "Site is now accessible through Traefik on standard ports"
        print_info "Direct nginx access: http://localhost:8080 -H 'Host: $DOMAIN'"
        echo ""
    else
        print_error "Nginx configuration test failed"
        print_info "Restoring backup..."
        cp "${NGINX_CONF}.backup-$(date +%Y%m%d-%H%M%S)" "$NGINX_CONF"
        exit 1
    fi

elif grep -q "listen 8080;" "$NGINX_CONF"; then
    print_success "Port is already set to 8080 - no changes needed"
    echo ""
else
    print_warning "Could not find 'listen 80;' or 'listen 8080;' in config"
    print_info "Please check the configuration manually: $NGINX_CONF"
    exit 1
fi

# Show current configuration
echo "Current configuration:"
grep -n "listen" "$NGINX_CONF" | head -5

echo ""
print_info "Configuration file: $NGINX_CONF"
