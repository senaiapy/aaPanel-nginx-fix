#!/bin/bash

#########################################################
# Enhanced aaPanel Nginx Installation & Port Configuration
# Configures nginx to run on ports 8080/8443 to avoid
# conflicts with Traefik on ports 80/443
#########################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
HTTP_PORT=8080
HTTPS_PORT=8443
NGINX_PATH="/www/server/nginx"
NGINX_CONF="${NGINX_PATH}/conf/nginx.conf"
VHOST_PATH="/www/server/panel/vhost/nginx"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}aaPanel Nginx Custom Port Installation${NC}"
echo -e "${GREEN}HTTP Port: ${HTTP_PORT} | HTTPS Port: ${HTTPS_PORT}${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Check if aaPanel is installed
if [ ! -d "/www/server/panel" ]; then
    echo -e "${RED}Error: aaPanel is not installed${NC}"
    echo "Please install aaPanel first from: https://www.aapanel.com/install.html"
    exit 1
fi

# Check if nginx is installed via aaPanel
if [ ! -d "${NGINX_PATH}" ]; then
    echo -e "${YELLOW}Nginx is not installed via aaPanel${NC}"
    echo "Please install nginx through aaPanel web interface first:"
    echo "  1. Login to aaPanel (usually at http://your-ip:7800)"
    echo "  2. Go to App Store"
    echo "  3. Find and install Nginx"
    echo ""
    read -p "Have you installed nginx via aaPanel? (y/n): " answer
    if [ "$answer" != "y" ]; then
        echo -e "${RED}Exiting. Please install nginx first.${NC}"
        exit 1
    fi

    # Check again after user confirmation
    if [ ! -d "${NGINX_PATH}" ]; then
        echo -e "${RED}Error: Nginx directory still not found at ${NGINX_PATH}${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Step 1: Running original aaPanel nginx fix...${NC}"

# Create a symbolic link for NGINX
echo "Creating symbolic link for NGINX..."
ln -sf ${NGINX_PATH}/sbin/nginx /usr/local/bin/nginx

# Rename K01nginx_bak and S01nginx_bak files
for dir in /etc/rc*.d; do
  if [ -e "$dir/K01nginx_bak" ]; then
    rm -f "$dir/K01nginx"
    rename 's/K01nginx_bak/K01nginx/' "$dir/K01nginx_bak" 2>/dev/null || mv "$dir/K01nginx_bak" "$dir/K01nginx"
  fi
  if [ -e "$dir/S01nginx_bak" ]; then
    rm -f "$dir/S01nginx"
    rename 's/S01nginx_bak/S01nginx/' "$dir/S01nginx_bak" 2>/dev/null || mv "$dir/S01nginx_bak" "$dir/S01nginx"
  fi
done

# Add symbolic links for run levels 2, 3, 4, and 5
echo "Adding symbolic links for run levels 2, 3, 4, and 5..."
ln -sf ../init.d/nginx /etc/rc2.d/S01nginx
ln -sf ../init.d/nginx /etc/rc3.d/S01nginx
ln -sf ../init.d/nginx /etc/rc4.d/S01nginx
ln -sf ../init.d/nginx /etc/rc5.d/S01nginx

# Configure NGINX to start automatically at system startup
echo "Configuring NGINX to start automatically at system startup..."
update-rc.d nginx defaults 2>/dev/null || true

# Check and correct permissions of configuration files
echo "Checking and correcting permissions of configuration files..."
if [ -f /etc/systemd/system/nginx.service ]; then
    chown root:root /etc/systemd/system/nginx.service
    chmod 644 /etc/systemd/system/nginx.service
fi

# Create or replace the nginx.service file with the provided content
echo "Creating or replacing the /etc/systemd/system/nginx.service file..."
cat <<EOL > /etc/systemd/system/nginx.service
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=network.target

[Service]
Type=forking
ExecStart=/etc/init.d/nginx start
ExecReload=/etc/init.d/nginx reload
ExecStop=/etc/init.d/nginx stop
PIDFile=${NGINX_PATH}/logs/nginx.pid

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd services to apply changes
echo "Reloading systemd services..."
systemctl daemon-reload

echo -e "${GREEN}Step 2: Backing up nginx configuration files...${NC}"

# Backup main config
if [ -f "${NGINX_CONF}" ]; then
    cp "${NGINX_CONF}" "${NGINX_CONF}.backup-$(date +%Y%m%d-%H%M%S)"
    echo "Backed up: ${NGINX_CONF}"
fi

# Backup virtual host configs
if [ -d "${VHOST_PATH}" ]; then
    mkdir -p "${VHOST_PATH}/backups-$(date +%Y%m%d-%H%M%S)"
    cp -r "${VHOST_PATH}"/*.conf "${VHOST_PATH}/backups-$(date +%Y%m%d-%H%M%S)/" 2>/dev/null || echo "No virtual host configs to backup"
fi

echo -e "${GREEN}Step 3: Configuring nginx for custom ports (${HTTP_PORT}/${HTTPS_PORT})...${NC}"

# Stop nginx if it's running
echo "Stopping nginx if running..."
systemctl stop nginx 2>/dev/null || /etc/init.d/nginx stop 2>/dev/null || true

# Update main nginx.conf - change default listen ports
if [ -f "${NGINX_CONF}" ]; then
    echo "Updating main nginx configuration..."

    # Replace listen 80 with listen 8080
    sed -i "s/listen\s*80;/listen ${HTTP_PORT};/g" "${NGINX_CONF}"
    sed -i "s/listen\s*80\s/listen ${HTTP_PORT} /g" "${NGINX_CONF}"

    # Replace listen 443 with listen 8443
    sed -i "s/listen\s*443\s/listen ${HTTPS_PORT} /g" "${NGINX_CONF}"
    sed -i "s/listen\s*443;/listen ${HTTPS_PORT};/g" "${NGINX_CONF}"

    # Handle IPv6 addresses if present
    sed -i "s/listen\s*\[::\]:80;/listen [::]:${HTTP_PORT};/g" "${NGINX_CONF}"
    sed -i "s/listen\s*\[::\]:443\s/listen [::]:${HTTPS_PORT} /g" "${NGINX_CONF}"

    echo "Main config updated: ${NGINX_CONF}"
else
    echo -e "${RED}Warning: Main nginx config not found at ${NGINX_CONF}${NC}"
fi

# Update virtual host configurations
if [ -d "${VHOST_PATH}" ]; then
    echo "Updating virtual host configurations..."
    conf_count=0

    for conf_file in "${VHOST_PATH}"/*.conf; do
        if [ -f "$conf_file" ]; then
            # Replace listen 80 with listen 8080
            sed -i "s/listen\s*80;/listen ${HTTP_PORT};/g" "$conf_file"
            sed -i "s/listen\s*80\s/listen ${HTTP_PORT} /g" "$conf_file"

            # Replace listen 443 with listen 8443
            sed -i "s/listen\s*443\s/listen ${HTTPS_PORT} /g" "$conf_file"
            sed -i "s/listen\s*443;/listen ${HTTPS_PORT};/g" "$conf_file"

            # Handle IPv6
            sed -i "s/listen\s*\[::\]:80;/listen [::]:${HTTP_PORT};/g" "$conf_file"
            sed -i "s/listen\s*\[::\]:443\s/listen [::]:${HTTPS_PORT} /g" "$conf_file"

            conf_count=$((conf_count + 1))
            echo "  Updated: $(basename $conf_file)"
        fi
    done

    echo "Updated ${conf_count} virtual host configuration(s)"
else
    echo -e "${YELLOW}No virtual host directory found (this is ok for new installations)${NC}"
fi

echo -e "${GREEN}Step 4: Testing nginx configuration...${NC}"

# Test nginx configuration
if nginx -t 2>&1; then
    echo -e "${GREEN}Nginx configuration test passed!${NC}"
else
    echo -e "${RED}Nginx configuration test failed!${NC}"
    echo "Please check the error messages above and fix the configuration."
    echo "Backup files are available in case you need to restore."
    exit 1
fi

echo -e "${GREEN}Step 5: Starting nginx service...${NC}"

# Enable NGINX service at startup
echo "Enabling NGINX service..."
systemctl enable nginx

# Start NGINX service
echo "Starting NGINX service..."
if systemctl start nginx; then
    echo -e "${GREEN}Nginx started successfully!${NC}"
else
    echo -e "${RED}Failed to start nginx. Check the error messages above.${NC}"
    exit 1
fi

# Wait a moment for nginx to fully start
sleep 2

# Verify nginx is running on correct ports
echo -e "${GREEN}Step 6: Verifying installation...${NC}"

if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓ Nginx service is active${NC}"
else
    echo -e "${RED}✗ Nginx service is not active${NC}"
fi

# Check if nginx is listening on the correct ports
if ss -tlnp | grep -q ":${HTTP_PORT}"; then
    echo -e "${GREEN}✓ Nginx is listening on port ${HTTP_PORT}${NC}"
else
    echo -e "${YELLOW}✗ Nginx is not listening on port ${HTTP_PORT}${NC}"
fi

if ss -tlnp | grep -q ":${HTTPS_PORT}"; then
    echo -e "${GREEN}✓ Nginx is listening on port ${HTTPS_PORT}${NC}"
else
    echo -e "${YELLOW}Note: HTTPS port ${HTTPS_PORT} not active (normal if no SSL sites configured)${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Nginx is now configured to run on:"
echo "  - HTTP:  port ${HTTP_PORT}"
echo "  - HTTPS: port ${HTTPS_PORT}"
echo ""
echo "This avoids conflicts with Traefik on ports 80/443"
echo ""
echo "Useful commands:"
echo "  sudo systemctl status nginx   - Check nginx status"
echo "  sudo systemctl restart nginx  - Restart nginx"
echo "  sudo systemctl stop nginx     - Stop nginx"
echo "  sudo systemctl start nginx    - Start nginx"
echo "  sudo nginx -t                 - Test configuration"
echo "  ss -tlnp | grep nginx        - Check listening ports"
echo ""
echo "Access aaPanel at: http://your-server-ip:7800"
echo "Your websites will be accessible at: http://your-server-ip:${HTTP_PORT}"
echo ""
echo -e "${YELLOW}Note: You may need to configure Traefik to proxy to nginx on ports ${HTTP_PORT}/${HTTPS_PORT}${NC}"
echo ""
