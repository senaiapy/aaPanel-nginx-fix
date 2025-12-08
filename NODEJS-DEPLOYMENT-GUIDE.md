# Node.js Deployment Guide with Nginx Reverse Proxy

## Overview

This guide shows how to deploy Node.js applications using nginx as a reverse proxy in your Traefik + nginx + aaPanel setup.

## Architecture

```
Internet (80/443)
    ↓
Traefik (SSL termination, domain routing)
    ↓
Nginx (8080 - reverse proxy)
    ↓
Node.js Application (3000, 5000, etc.)
```

## Quick Start

### The 4-Step Process

```bash
# 1. Configure nginx proxy
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh YOUR-DOMAIN.com NODE_PORT [APP_PATH]

# 2. Start your Node.js app
cd /path/to/your/app
PORT=NODE_PORT npm start

# 3. Generate SSL certificate
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh YOUR-DOMAIN.com

# 4. Access your app
curl https://YOUR-DOMAIN.com
```

## Complete Examples

### Example 1: Express.js API

**Scenario:** Deploy an Express API at `api.b7g.app` running on port 5000

**Step 1:** Prepare your Express app
```bash
# Your app structure
/var/www/express-api/
├── package.json
├── server.js
├── routes/
└── node_modules/
```

**Step 2:** Configure nginx proxy
```bash
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh api.b7g.app 5000 /var/www/express-api
```

**Step 3:** Start the app (automatically via systemd)
```bash
systemctl start nodejs-api-b7g-app
systemctl enable nodejs-api-b7g-app
systemctl status nodejs-api-b7g-app
```

**Step 4:** Generate SSL
```bash
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh api.b7g.app
```

**Step 5:** Test
```bash
curl https://api.b7g.app
```

---

### Example 2: Next.js Application

**Scenario:** Deploy Next.js app at `nextapp.b7g.app` on port 3000

**Step 1:** Build your Next.js app
```bash
cd /var/www/nextjs-app
npm install
npm run build
```

**Step 2:** Configure nginx proxy
```bash
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh nextapp.b7g.app 3000 /var/www/nextjs-app
```

**Step 3:** Start Next.js
```bash
systemctl start nodejs-nextapp-b7g-app
systemctl enable nodejs-nextapp-b7g-app
```

**Step 4:** Generate SSL
```bash
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh nextapp.b7g.app
```

**Step 5:** Access
```
https://nextapp.b7g.app
```

---

### Example 3: React App with API Backend

**Scenario:** React frontend (Vite/CRA) + Express backend

**Architecture:**
```
app.b7g.app (frontend - port 3000)
api.b7g.app (backend - port 5000)
```

**Setup Frontend:**
```bash
# Frontend on port 3000
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh app.b7g.app 3000 /var/www/react-app
systemctl start nodejs-app-b7g-app
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh app.b7g.app
```

**Setup Backend:**
```bash
# Backend on port 5000
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh api.b7g.app 5000 /var/www/express-api
systemctl start nodejs-api-b7g-app
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh api.b7g.app
```

**Configure CORS in Express:**
```javascript
const cors = require('cors');

app.use(cors({
  origin: 'https://app.b7g.app',
  credentials: true
}));
```

---

### Example 4: Socket.io / WebSocket Application

**Scenario:** Real-time chat app with Socket.io on port 4000

**Step 1:** Configure nginx (WebSocket support included automatically)
```bash
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh chat.b7g.app 4000 /var/www/chat-app
```

**Step 2:** Your Socket.io server code
```javascript
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "https://chat.b7g.app",
    methods: ["GET", "POST"]
  }
});

const PORT = process.env.PORT || 4000;

io.on('connection', (socket) => {
  console.log('New client connected');
  // Your socket logic
});

server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

**Step 3:** Start and enable
```bash
systemctl start nodejs-chat-b7g-app
systemctl enable nodejs-chat-b7g-app
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh chat.b7g.app
```

**Step 4:** Connect from client
```javascript
import io from 'socket.io-client';
const socket = io('https://chat.b7g.app');
```

---

## Detailed Workflow

### Manual Deployment (Without Systemd)

If you want to manage your Node.js app manually:

**Step 1:** Configure nginx proxy
```bash
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh myapp.b7g.app 3000
```

**Step 2:** Start your app with PM2
```bash
# Install PM2 globally
npm install -g pm2

# Start your app
cd /var/www/myapp
pm2 start npm --name "myapp" -- start

# Save PM2 configuration
pm2 save
pm2 startup
```

**Step 3:** Generate SSL
```bash
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh myapp.b7g.app
```

---

### Automatic Deployment (With Systemd)

Let the script create and manage the systemd service:

**Step 1:** Configure with app path
```bash
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh myapp.b7g.app 3000 /var/www/myapp
```

**Step 2:** Manage with systemctl
```bash
# Start
systemctl start nodejs-myapp-b7g-app

# Enable auto-start
systemctl enable nodejs-myapp-b7g-app

# Check status
systemctl status nodejs-myapp-b7g-app

# View logs
journalctl -u nodejs-myapp-b7g-app -f

# Restart after code changes
systemctl restart nodejs-myapp-b7g-app
```

**Step 3:** Generate SSL
```bash
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh myapp.b7g.app
```

---

## Environment Variables

### Method 1: Systemd Service File

Edit the generated service file:
```bash
nano /etc/systemd/system/nodejs-myapp-b7g-app.service
```

Add environment variables:
```ini
[Service]
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=DATABASE_URL=postgresql://user:pass@localhost/db
Environment=API_KEY=your-api-key
Environment=REDIS_URL=redis://localhost:6379
```

Reload and restart:
```bash
systemctl daemon-reload
systemctl restart nodejs-myapp-b7g-app
```

### Method 2: .env File (with dotenv)

Create `.env` file in app directory:
```bash
cd /var/www/myapp
nano .env
```

Add variables:
```env
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://user:pass@localhost/db
API_KEY=your-api-key
REDIS_URL=redis://localhost:6379
```

In your Node.js app:
```javascript
require('dotenv').config();

const port = process.env.PORT || 3000;
const dbUrl = process.env.DATABASE_URL;
```

Secure the file:
```bash
chmod 600 .env
chown www-data:www-data .env
```

---

## Common Node.js Frameworks

### Express.js

```bash
# Setup
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh api.example.com 5000 /var/www/express-api

# Your server.js
const express = require('express');
const app = express();
const PORT = process.env.PORT || 5000;

app.get('/', (req, res) => {
  res.json({ message: 'API is running' });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

### Next.js

```bash
# Setup
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh nextapp.com 3000 /var/www/nextjs-app

# Build and start
cd /var/www/nextjs-app
npm run build
npm run start  # Or use systemd service
```

### NestJS

```bash
# Setup
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh api.example.com 3000 /var/www/nestjs-api

# Build and start
cd /var/www/nestjs-api
npm run build
npm run start:prod  # Or use systemd
```

### Nuxt.js

```bash
# Setup
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh nuxtapp.com 3000 /var/www/nuxt-app

# Build and start
cd /var/www/nuxt-app
npm run build
npm run start
```

### Strapi CMS

```bash
# Setup
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh cms.example.com 1337 /var/www/strapi

# Start
cd /var/www/strapi
npm run start
```

---

## Troubleshooting

### Node.js App Not Accessible

**Check if app is running:**
```bash
ss -tlnp | grep PORT_NUMBER
ps aux | grep node
```

**Check systemd service:**
```bash
systemctl status nodejs-DOMAIN
journalctl -u nodejs-DOMAIN -n 50
```

**Check if port is correct:**
```bash
# Should show your Node.js app
curl http://localhost:PORT_NUMBER

# Should show nginx proxy working
curl -H 'Host: DOMAIN' http://localhost:8080
```

### 502 Bad Gateway

**Cause:** Node.js app is not running or not listening on correct port

**Solution:**
```bash
# 1. Check if app is running
systemctl status nodejs-DOMAIN

# 2. Check app logs
journalctl -u nodejs-DOMAIN -f

# 3. Check what's on the port
ss -tlnp | grep PORT

# 4. Start the app
systemctl start nodejs-DOMAIN

# 5. Test direct connection
curl http://localhost:PORT
```

### Connection Refused

**Cause:** App not listening or firewall blocking

**Check:**
```bash
# Test local connection
curl http://127.0.0.1:PORT

# Check if app is bound to correct interface
ss -tlnp | grep PORT

# Should show 127.0.0.1:PORT or 0.0.0.0:PORT
```

**Fix:** Ensure app listens on `0.0.0.0` or `127.0.0.1`:
```javascript
// Good - listens on all interfaces
app.listen(PORT, '0.0.0.0');

// Or
app.listen(PORT, '127.0.0.1');

// Bad - only localhost in some cases
app.listen(PORT, 'localhost');
```

### WebSocket Connection Fails

**Check nginx config has WebSocket headers:**
```bash
grep -A 2 "Upgrade" /www/server/panel/vhost/nginx/DOMAIN.conf
```

Should show:
```nginx
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

If missing, re-run setup script:
```bash
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh DOMAIN PORT
```

### Permission Denied

**Cause:** App running as www-data can't access files

**Fix permissions:**
```bash
# Change ownership
chown -R www-data:www-data /var/www/your-app

# Set correct permissions
chmod -R 755 /var/www/your-app
chmod 600 /var/www/your-app/.env  # if you have .env
```

---

## Performance Optimization

### PM2 Cluster Mode

For better performance, use PM2 with cluster mode:

```bash
# Install PM2
npm install -g pm2

# Start with cluster mode
pm2 start app.js -i max  # max = number of CPU cores

# Or with ecosystem file
pm2 start ecosystem.config.js
```

**ecosystem.config.js:**
```javascript
module.exports = {
  apps: [{
    name: 'myapp',
    script: './server.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    }
  }]
};
```

### Nginx Caching

For static assets, nginx is already configured with caching in the generated config:

```nginx
location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
    proxy_pass http://nodejs_app;
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

### Node.js Production Best Practices

```javascript
// Use production mode
process.env.NODE_ENV = 'production';

// Enable gzip compression
const compression = require('compression');
app.use(compression());

// Use helmet for security
const helmet = require('helmet');
app.use(helmet());

// Rate limiting
const rateLimit = require('express-rate-limit');
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});
app.use('/api/', limiter);
```

---

## Monitoring and Logging

### View Application Logs

```bash
# Systemd service logs
journalctl -u nodejs-DOMAIN -f

# Nginx access logs
tail -f /www/wwwlogs/DOMAIN.log

# Nginx error logs
tail -f /www/wwwlogs/DOMAIN.error.log

# PM2 logs
pm2 logs myapp
```

### Monitor Application

```bash
# Systemd status
systemctl status nodejs-DOMAIN

# PM2 monitoring
pm2 monit

# Check resource usage
top -p $(pgrep -f "node.*DOMAIN")

# Check memory
ps aux | grep node | grep DOMAIN
```

---

## Updating Your Application

### With Systemd

```bash
# 1. Stop the service
systemctl stop nodejs-DOMAIN

# 2. Update code
cd /var/www/your-app
git pull  # or your update method
npm install

# 3. Rebuild if needed (Next.js, TypeScript, etc.)
npm run build

# 4. Start service
systemctl start nodejs-DOMAIN

# 5. Check status
systemctl status nodejs-DOMAIN
```

### With PM2

```bash
# Update and reload
cd /var/www/your-app
git pull
npm install
pm2 reload myapp

# Or with zero-downtime
pm2 reload myapp --update-env
```

---

## Security Checklist

- [ ] Run app as non-root user (www-data)
- [ ] Use environment variables for secrets
- [ ] Secure .env file permissions (chmod 600)
- [ ] Enable HTTPS (SSL certificate)
- [ ] Use helmet.js for security headers
- [ ] Implement rate limiting
- [ ] Keep dependencies updated
- [ ] Use NODE_ENV=production
- [ ] Disable debug mode in production
- [ ] Implement proper error handling
- [ ] Don't expose stack traces to users
- [ ] Validate and sanitize user input
- [ ] Use CORS appropriately

---

## Quick Command Reference

```bash
# Setup nginx proxy
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh DOMAIN PORT [APP_PATH]

# Generate SSL
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh DOMAIN

# Systemd commands
systemctl start nodejs-DOMAIN
systemctl stop nodejs-DOMAIN
systemctl restart nodejs-DOMAIN
systemctl status nodejs-DOMAIN
systemctl enable nodejs-DOMAIN
journalctl -u nodejs-DOMAIN -f

# Test connections
curl http://localhost:PORT  # Direct to Node.js
curl -H 'Host: DOMAIN' http://localhost:8080  # Through nginx
curl https://DOMAIN  # Through Traefik + nginx

# Check ports
ss -tlnp | grep PORT
netstat -tlnp | grep PORT

# View logs
tail -f /www/wwwlogs/DOMAIN.log
journalctl -u nodejs-DOMAIN -f

# Nginx
nginx -t  # Test config
systemctl reload nginx
```

---

## Files and Locations

| Purpose | Location |
|---------|----------|
| Nginx proxy config | `/www/server/panel/vhost/nginx/DOMAIN.conf` |
| Systemd service | `/etc/systemd/system/nodejs-DOMAIN.service` |
| Application files | `/var/www/your-app/` |
| Nginx logs | `/www/wwwlogs/DOMAIN.log` |
| Application logs | `journalctl -u nodejs-DOMAIN` |
| SSL certificates | Managed by Traefik (Docker volume) |

---

## Support

For help:
- Node.js proxy setup: `/root/aaPanel-nginx-fix/setup-nodejs-proxy.sh --help`
- SSL certificates: `/root/aaPanel-nginx-fix/generate-ssl-cert.sh --help`
- Full workflow: `/root/aaPanel-nginx-fix/NEW-SITE-WORKFLOW.md`

---

Last Updated: 2025-12-08
Version: 1.0
