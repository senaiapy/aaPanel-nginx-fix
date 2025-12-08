# Node.js Deployment - Quick Start

## The Fastest Way to Deploy Node.js Apps

### 4 Simple Steps

```bash
# 1. Setup nginx reverse proxy
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh YOUR-DOMAIN.com NODE_PORT /path/to/app

# 2. Start your Node.js app
systemctl start nodejs-YOUR-DOMAIN
systemctl enable nodejs-YOUR-DOMAIN

# 3. Generate SSL certificate
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh YOUR-DOMAIN.com

# 4. Done! Access your app
https://YOUR-DOMAIN.com
```

---

## Real Example: Deploy Express API

**Scenario:** Deploy Express.js API at `api.b7g.app`

### Your Express App

```javascript
// server.js
const express = require('express');
const app = express();
const PORT = process.env.PORT || 5000;

app.get('/', (req, res) => {
  res.json({ message: 'API is working!' });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

### Deployment Commands

```bash
# 1. Upload your app
cd /var/www
git clone https://github.com/yourname/express-api.git
cd express-api
npm install

# 2. Configure nginx proxy
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh api.b7g.app 5000 /var/www/express-api

# 3. Start the app
systemctl start nodejs-api-b7g-app
systemctl enable nodejs-api-b7g-app

# 4. Generate SSL
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh api.b7g.app

# 5. Test
curl https://api.b7g.app
```

**Done!** Your API is live at `https://api.b7g.app`

---

## Different Node.js Frameworks

### Express.js
```bash
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh api.example.com 5000 /var/www/express-app
systemctl start nodejs-api-example-com
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh api.example.com
```

### Next.js
```bash
# Build first
cd /var/www/nextjs-app
npm run build

# Then deploy
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh app.example.com 3000 /var/www/nextjs-app
systemctl start nodejs-app-example-com
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh app.example.com
```

### NestJS
```bash
cd /var/www/nestjs-api
npm run build

sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh api.example.com 3000 /var/www/nestjs-api
systemctl start nodejs-api-example-com
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh api.example.com
```

---

## Common Commands

### Manage Your App

```bash
# Start
systemctl start nodejs-YOUR-DOMAIN

# Stop
systemctl stop nodejs-YOUR-DOMAIN

# Restart (after code changes)
systemctl restart nodejs-YOUR-DOMAIN

# Check status
systemctl status nodejs-YOUR-DOMAIN

# View logs
journalctl -u nodejs-YOUR-DOMAIN -f

# Enable auto-start on boot
systemctl enable nodejs-YOUR-DOMAIN
```

### Update Your App

```bash
# 1. Stop service
systemctl stop nodejs-YOUR-DOMAIN

# 2. Update code
cd /var/www/your-app
git pull
npm install
npm run build  # if needed

# 3. Restart
systemctl start nodejs-YOUR-DOMAIN
```

---

## Troubleshooting

### App Not Working?

```bash
# Check if app is running
systemctl status nodejs-YOUR-DOMAIN

# View error logs
journalctl -u nodejs-YOUR-DOMAIN -n 50

# Test direct connection
curl http://localhost:YOUR_PORT
```

### 502 Bad Gateway?

**Your Node.js app isn't running**

```bash
# Start it
systemctl start nodejs-YOUR-DOMAIN

# Check logs for errors
journalctl -u nodejs-YOUR-DOMAIN -f
```

### Can't Connect?

```bash
# Check if port is open
ss -tlnp | grep YOUR_PORT

# Check nginx config
nginx -t

# Reload nginx
systemctl reload nginx
```

---

## Environment Variables

Edit systemd service:
```bash
nano /etc/systemd/system/nodejs-YOUR-DOMAIN.service
```

Add variables:
```ini
[Service]
Environment=DATABASE_URL=postgresql://localhost/mydb
Environment=API_KEY=your-secret-key
Environment=NODE_ENV=production
```

Reload:
```bash
systemctl daemon-reload
systemctl restart nodejs-YOUR-DOMAIN
```

---

## Architecture

```
Internet → Traefik (SSL, port 80/443)
         → Nginx (port 8080, reverse proxy)
         → Your Node.js App (port 3000, 5000, etc.)
```

**What each does:**
- **Traefik:** Handles SSL certificates, routes by domain
- **Nginx:** Reverse proxy, caching, WebSocket support
- **Your App:** Runs your Node.js code

---

## Multiple Apps on One Server

```bash
# App 1: Frontend (React/Next.js)
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh app.example.com 3000 /var/www/frontend

# App 2: Backend API
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh api.example.com 5000 /var/www/backend

# App 3: Admin Panel
sudo /root/aaPanel-nginx-fix/setup-nodejs-proxy.sh admin.example.com 4000 /var/www/admin

# Generate SSL for all
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh app.example.com
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh api.example.com
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh admin.example.com
```

Each app runs independently on its own port!

---

## Quick Checklist

- [ ] DNS points to server
- [ ] App code uploaded to `/var/www/your-app`
- [ ] Dependencies installed (`npm install`)
- [ ] Built if needed (`npm run build`)
- [ ] Nginx proxy configured
- [ ] App started via systemd
- [ ] SSL certificate generated
- [ ] App accessible via HTTPS

---

## Help

```bash
# Script help
/root/aaPanel-nginx-fix/setup-nodejs-proxy.sh --help

# Full guide
cat /root/aaPanel-nginx-fix/NODEJS-DEPLOYMENT-GUIDE.md

# Workflow guide
cat /root/aaPanel-nginx-fix/NEW-SITE-WORKFLOW.md
```

---

**That's it!** Your Node.js app is now deployed with HTTPS! 🚀
