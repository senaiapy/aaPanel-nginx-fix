# How to Use Nginx Proxy for Node.js Applications

## Overview

This guide explains how to deploy Node.js applications using nginx as a reverse proxy with automatic SSL certificates using a single command.

---

## Architecture

```
Internet (HTTPS/HTTP)
    ↓
Traefik (Port 80/443) - SSL Termination
    ↓
Nginx (Port 8080) - Reverse Proxy
    ↓
Your Node.js App (Port 3000, 5000, etc.)
```

**What Each Component Does:**
- **Traefik:** Handles SSL certificates, HTTPS traffic, domain routing
- **Nginx:** Reverse proxy, caching, WebSocket support, static files
- **Node.js:** Your application logic

---

## Quick Start - One Command Deployment

### Step 1: Prepare Your Application

Upload your Node.js application to the server:

```bash
# Example: Clone your repository
cd /var/www
git clone https://github.com/yourname/myapp.git
cd myapp

# Install dependencies
npm install

# Build if needed (Next.js, NestJS, etc.)
npm run build
```

### Step 2: Deploy with One Command

```bash
sudo /root/aaPanel-nginx-fix/deploy-nodejs.sh DOMAIN PORT /path/to/app
```

**That's it!** Your app is now live with HTTPS.

---

## Examples

### Example 1: Express.js API

```bash
# 1. Prepare your app
cd /var/www
git clone https://github.com/yourname/express-api.git
cd express-api
npm install

# 2. Deploy with one command
sudo /root/aaPanel-nginx-fix/deploy-nodejs.sh api.myapp.com 5000 /var/www/express-api

# 3. Done! Access your API
curl https://api.myapp.com
```

### Example 2: Next.js Application

```bash
# 1. Prepare and build
cd /var/www
git clone https://github.com/yourname/nextjs-app.git
cd nextjs-app
npm install
npm run build

# 2. Deploy with one command
sudo /root/aaPanel-nginx-fix/deploy-nodejs.sh app.myapp.com 3000 /var/www/nextjs-app

# 3. Done! Visit your app
# https://app.myapp.com
```

### Example 3: NestJS Backend

```bash
# 1. Prepare and build
cd /var/www
git clone https://github.com/yourname/nestjs-backend.git
cd nestjs-backend
npm install
npm run build

# 2. Deploy with one command
sudo /root/aaPanel-nginx-fix/deploy-nodejs.sh backend.myapp.com 3001 /var/www/nestjs-backend

# 3. Done!
curl https://backend.myapp.com/api/health
```

### Example 4: Socket.io Real-time App

```bash
# 1. Prepare your app
cd /var/www/socket-app
npm install

# 2. Deploy (WebSocket support is automatic)
sudo /root/aaPanel-nginx-fix/deploy-nodejs.sh chat.myapp.com 4000 /var/www/socket-app

# 3. WebSocket connection works automatically
# ws://chat.myapp.com upgrades to wss://
```

---

## What the Script Does

When you run the deployment command, here's what happens:

### Step 1: Nginx Reverse Proxy Configuration

Creates `/www/server/panel/vhost/nginx/DOMAIN.conf`:

```nginx
upstream nodejs_DOMAIN {
    server 127.0.0.1:PORT;
    keepalive 64;
}

server {
    listen 8080;
    server_name DOMAIN;

    location / {
        proxy_pass http://nodejs_DOMAIN;
        proxy_http_version 1.1;

        # Proper headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### Step 2: Systemd Service Creation

Creates `/etc/systemd/system/nodejs-DOMAIN.service`:

```ini
[Unit]
Description=Node.js application for DOMAIN
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/path/to/app
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=PORT

[Install]
WantedBy=multi-user.target
```

**Features:**
- Auto-restart on failure
- Auto-start on server boot
- Logs to systemd journal
- Environment variables set

### Step 3: Start Application

```bash
systemctl daemon-reload
systemctl start nodejs-DOMAIN
systemctl enable nodejs-DOMAIN
```

### Step 4: SSL Certificate Generation

Creates Traefik configuration in `/root/ssl-configs/DOMAIN.yml`:

```yaml
services:
  DOMAIN-proxy:
    image: alpine:latest
    command: sleep infinity
    networks:
      - traefik_public
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.DOMAIN-https.rule=Host(`DOMAIN`)"
        - "traefik.http.routers.DOMAIN-https.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.DOMAIN-service.loadbalancer.server.url=http://172.18.0.1:8080"
```

Deploys to Docker Swarm:
```bash
docker stack deploy -c /root/ssl-configs/DOMAIN.yml DOMAIN-proxy
```

Traefik automatically:
- Requests Let's Encrypt certificate
- Configures HTTPS
- Routes traffic to nginx on port 8080

### Step 5: Verification

Tests:
- Node.js app is running on PORT
- Nginx proxy is working
- HTTPS access is functional
- Service is enabled for auto-start

---

## Prerequisites

Before using the proxy deployment:

### 1. DNS Configuration

Point your domain to your server's IP:

```
A Record: myapp.com → YOUR_SERVER_IP
A Record: api.myapp.com → YOUR_SERVER_IP
```

**Verify DNS:**
```bash
dig +short myapp.com
# Should show your server IP
```

### 2. Node.js Application Requirements

Your app must have:

```javascript
// server.js (or index.js)
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;  // Important: Read PORT from environment

app.get('/', (req, res) => {
  res.send('Hello World!');
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

**Key Points:**
- Must read PORT from `process.env.PORT`
- Must have a `server.js` file (or update systemd service)
- Must listen on `0.0.0.0` or `127.0.0.1`, not localhost

### 3. Server Requirements

- Nginx running on port 8080
- Traefik running on ports 80/443
- Docker Swarm initialized
- Traefik network: `traefik_public`

**Verify:**
```bash
# Check nginx
systemctl status nginx

# Check Traefik
docker service ls | grep traefik

# Check Swarm
docker info | grep Swarm
```

---

## Managing Your Application

### View Service Status

```bash
systemctl status nodejs-DOMAIN
```

### View Live Logs

```bash
journalctl -u nodejs-DOMAIN -f
```

### Restart Application

```bash
systemctl restart nodejs-DOMAIN
```

### Stop Application

```bash
systemctl stop nodejs-DOMAIN
```

### Start Application

```bash
systemctl start nodejs-DOMAIN
```

### Disable Auto-Start

```bash
systemctl disable nodejs-DOMAIN
```

---

## Updating Your Application

### Update Code

```bash
# 1. Stop the service
systemctl stop nodejs-DOMAIN

# 2. Update your code
cd /path/to/app
git pull
npm install
npm run build  # if needed

# 3. Restart
systemctl start nodejs-DOMAIN
```

### Update Environment Variables

```bash
# 1. Edit service file
nano /etc/systemd/system/nodejs-DOMAIN.service

# 2. Add/modify environment variables
[Service]
Environment=DATABASE_URL=postgresql://localhost/mydb
Environment=API_KEY=your-secret-key
Environment=NODE_ENV=production

# 3. Reload and restart
systemctl daemon-reload
systemctl restart nodejs-DOMAIN
```

### Change Port

```bash
# 1. Update nginx configuration
nano /www/server/panel/vhost/nginx/DOMAIN.conf
# Change: server 127.0.0.1:OLD_PORT;
# To:     server 127.0.0.1:NEW_PORT;

# 2. Update systemd service
nano /etc/systemd/system/nodejs-DOMAIN.service
# Change: Environment=PORT=OLD_PORT
# To:     Environment=PORT=NEW_PORT

# 3. Reload and restart
nginx -t
systemctl reload nginx
systemctl daemon-reload
systemctl restart nodejs-DOMAIN
```

---

## Multiple Applications on One Server

You can run multiple Node.js apps on the same server, each with its own domain:

```bash
# Frontend (React/Next.js)
sudo /root/aaPanel-nginx-fix/deploy-nodejs.sh app.example.com 3000 /var/www/frontend

# Backend API
sudo /root/aaPanel-nginx-fix/deploy-nodejs.sh api.example.com 5000 /var/www/backend

# Admin Panel
sudo /root/aaPanel-nginx-fix/deploy-nodejs.sh admin.example.com 4000 /var/www/admin

# WebSocket Server
sudo /root/aaPanel-nginx-fix/deploy-nodejs.sh ws.example.com 6000 /var/www/websocket
```

Each app:
- Runs independently on its own port
- Has its own SSL certificate
- Has its own systemd service
- Can be managed separately

---

## Troubleshooting

### 502 Bad Gateway

**Cause:** Node.js app is not running

**Fix:**
```bash
# Check service status
systemctl status nodejs-DOMAIN

# View logs for errors
journalctl -u nodejs-DOMAIN -n 50

# Try starting manually
systemctl start nodejs-DOMAIN
```

### Port Already in Use

**Cause:** Another app is using the port

**Fix:**
```bash
# Find what's using the port
ss -tlnp | grep PORT

# Stop the conflicting service
systemctl stop conflicting-service

# Or choose a different port
sudo /root/aaPanel-nginx-fix/deploy-nodejs.sh DOMAIN NEW_PORT /path/to/app
```

### SSL Certificate Not Generated

**Cause:** DNS not pointing to server or port 80/443 blocked

**Fix:**
```bash
# Verify DNS
dig +short DOMAIN
# Should show your server IP

# Check Traefik logs
docker service logs traefik_traefik

# Manually regenerate certificate
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh DOMAIN
```

### Application Won't Start

**Cause:** Missing dependencies or syntax errors

**Fix:**
```bash
# View detailed logs
journalctl -u nodejs-DOMAIN -n 100

# Test manually
cd /path/to/app
PORT=PORT node server.js
# Look for error messages

# Check for missing dependencies
npm install

# Check Node.js version
node --version
```

### Can't Access Application

**Cause:** Firewall or network configuration

**Fix:**
```bash
# Test direct Node.js connection
curl http://localhost:PORT

# Test nginx proxy
curl -H 'Host: DOMAIN' http://localhost:8080

# Test HTTPS
curl https://DOMAIN

# Check nginx logs
tail -f /www/wwwlogs/DOMAIN.error.log
```

---

## Advanced Configuration

### Custom Nginx Configuration

Edit the generated config:

```bash
nano /www/server/panel/vhost/nginx/DOMAIN.conf
```

**Add Rate Limiting:**
```nginx
# Add before server block
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;

# Add inside location /
limit_req zone=api_limit burst=20 nodelay;
```

**Add CORS Headers:**
```nginx
# Add inside location /
add_header 'Access-Control-Allow-Origin' '*' always;
add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
add_header 'Access-Control-Allow-Headers' 'Content-Type' always;
```

**Add Caching:**
```nginx
# Add inside location /
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=app_cache:10m;
proxy_cache app_cache;
proxy_cache_valid 200 5m;
```

After editing:
```bash
nginx -t
systemctl reload nginx
```

### Custom Systemd Service

Edit the service file:

```bash
nano /etc/systemd/system/nodejs-DOMAIN.service
```

**Use PM2 Instead:**
```ini
[Service]
ExecStart=/usr/bin/pm2 start server.js --name DOMAIN --no-daemon
```

**Add Memory Limits:**
```ini
[Service]
MemoryLimit=512M
```

**Add Custom Node Options:**
```ini
[Service]
ExecStart=/usr/bin/node --max-old-space-size=2048 server.js
```

After editing:
```bash
systemctl daemon-reload
systemctl restart nodejs-DOMAIN
```

---

## Security Best Practices

### 1. Use Environment Variables for Secrets

Never hardcode secrets in your code:

```bash
# Edit service file
nano /etc/systemd/system/nodejs-DOMAIN.service

# Add secrets
[Service]
Environment=DATABASE_PASSWORD=secret123
Environment=JWT_SECRET=your-jwt-secret
Environment=API_KEY=your-api-key
```

### 2. Run as Non-Root User (Production)

Create dedicated user:

```bash
# Create user
useradd -r -s /bin/false nodeapp

# Change ownership
chown -R nodeapp:nodeapp /path/to/app

# Update service
nano /etc/systemd/system/nodejs-DOMAIN.service
# Change: User=root
# To:     User=nodeapp

systemctl daemon-reload
systemctl restart nodejs-DOMAIN
```

### 3. Enable Nginx Rate Limiting

```nginx
limit_req_zone $binary_remote_addr zone=app_limit:10m rate=100r/s;

server {
    location / {
        limit_req zone=app_limit burst=200 nodelay;
        # ... rest of config
    }
}
```

### 4. Keep Dependencies Updated

```bash
cd /path/to/app
npm audit
npm audit fix
npm update
```

---

## Performance Optimization

### 1. Enable Nginx Caching

```nginx
proxy_cache_path /var/cache/nginx/DOMAIN levels=1:2 keys_zone=DOMAIN_cache:10m max_size=1g;

location / {
    proxy_cache DOMAIN_cache;
    proxy_cache_valid 200 5m;
    proxy_cache_use_stale error timeout http_500 http_502 http_503;
    add_header X-Cache-Status $upstream_cache_status;
}
```

### 2. Enable Gzip Compression

```nginx
location / {
    gzip on;
    gzip_types text/plain text/css application/json application/javascript;
    gzip_min_length 1000;
}
```

### 3. Use Process Manager (PM2)

```bash
npm install -g pm2

# Update systemd service
[Service]
ExecStart=/usr/bin/pm2 start server.js --name DOMAIN -i max --no-daemon
```

### 4. Enable Keep-Alive

```nginx
upstream nodejs_DOMAIN {
    server 127.0.0.1:PORT;
    keepalive 64;
}

location / {
    proxy_http_version 1.1;
    proxy_set_header Connection "";
}
```

---

## Complete Example: Production Deployment

Here's a complete example deploying a production Express.js API:

```bash
# 1. Prepare server
cd /var/www
git clone https://github.com/company/production-api.git
cd production-api

# 2. Install dependencies
npm ci --production

# 3. Deploy with one command
sudo /root/aaPanel-nginx-fix/deploy-nodejs.sh api.company.com 5000 /var/www/production-api

# 4. Add environment variables
sudo nano /etc/systemd/system/nodejs-api-company-com.service
# Add:
# Environment=DATABASE_URL=postgresql://user:pass@localhost/db
# Environment=REDIS_URL=redis://localhost:6379
# Environment=NODE_ENV=production
# Environment=LOG_LEVEL=info

# 5. Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart nodejs-api-company-com

# 6. Verify deployment
curl https://api.company.com/health
systemctl status nodejs-api-company-com
journalctl -u nodejs-api-company-com -f

# 7. Setup monitoring
sudo systemctl enable nodejs-api-company-com
```

---

## Summary

### One Command Deployment

```bash
sudo /root/aaPanel-nginx-fix/deploy-nodejs.sh DOMAIN PORT /path/to/app
```

### This Automatically:

- ✅ Configures nginx reverse proxy with WebSocket support
- ✅ Creates systemd service with auto-restart
- ✅ Starts your Node.js application
- ✅ Generates Let's Encrypt SSL certificate
- ✅ Enables HTTPS access
- ✅ Configures auto-start on boot
- ✅ Sets up logging to systemd journal

### Result:

Your Node.js application is live at `https://DOMAIN` with:
- Production-ready configuration
- Automatic SSL certificates
- Auto-restart on failure
- Professional logging
- WebSocket support
- High performance reverse proxy

---

## Quick Reference

```bash
# Deploy
sudo /root/aaPanel-nginx-fix/deploy-nodejs.sh DOMAIN PORT /path/to/app

# Manage
systemctl status nodejs-DOMAIN
systemctl restart nodejs-DOMAIN
systemctl stop nodejs-DOMAIN
systemctl start nodejs-DOMAIN

# Logs
journalctl -u nodejs-DOMAIN -f
tail -f /www/wwwlogs/DOMAIN.error.log

# Update
systemctl stop nodejs-DOMAIN
cd /path/to/app && git pull && npm install
systemctl start nodejs-DOMAIN

# SSL
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh DOMAIN
docker service logs traefik_traefik
```

---

**Your Node.js app is now deployed with professional infrastructure!**
