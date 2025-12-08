# New Site Workflow - Complete Guide

## The Complete Process (3 Steps)

When you create a new site in aaPanel and want it accessible via HTTPS with SSL certificate, follow these steps:

### Step 1: Create Site in aaPanel

1. Login to aaPanel: `https://your-server-ip:12321/aapanels`
2. Go to **Website** → **Add Site**
3. Enter your domain name (e.g., `api.b7g.app`)
4. Click **Submit**
5. **Do NOT** apply for SSL certificate in aaPanel (it won't work with our setup)

### Step 2: Fix Nginx Port Configuration

After creating the site, run this command:

```bash
sudo /root/aaPanel-nginx-fix/fix-site-port.sh YOUR-DOMAIN.com
```

**Example:**
```bash
sudo /root/aaPanel-nginx-fix/fix-site-port.sh api.b7g.app
```

**What this does:**
- Changes nginx from port 80 → 8080
- Changes nginx from port 443 → 8443 (if SSL exists)
- Tests nginx configuration
- Reloads nginx
- Creates backup of original config

### Step 3: Generate SSL Certificate

Run the SSL certificate generator:

```bash
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh YOUR-DOMAIN.com
```

**Example:**
```bash
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh api.b7g.app
```

**What this does:**
- Validates prerequisites
- Checks DNS resolution
- Creates Traefik configuration
- Deploys to Docker Swarm
- Generates Let's Encrypt SSL certificate
- Verifies HTTPS access

### Done!

Your site is now accessible at: `https://YOUR-DOMAIN.com`

---

## Quick Command Reference

```bash
# 1. After creating site in aaPanel
sudo /root/aaPanel-nginx-fix/fix-site-port.sh DOMAIN

# 2. Generate SSL certificate
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh DOMAIN

# 3. Verify
curl -I https://DOMAIN
```

---

## Complete Example - Real Workflow

Let's say you want to create `blog.b7g.app`:

### 1. Create in aaPanel

- Login to aaPanel
- Website → Add Site
- Domain: `blog.b7g.app`
- Submit

### 2. Fix Port

```bash
sudo /root/aaPanel-nginx-fix/fix-site-port.sh blog.b7g.app
```

**Output:**
```
ℹ Checking nginx configuration for blog.b7g.app...
⚠ Found 'listen 80;' - needs fixing
✓ Created backup
✓ Changed port 80 → 8080
ℹ Testing nginx configuration...
✓ Nginx configuration is valid
ℹ Reloading nginx...
✓ Nginx reloaded
✓ Site port configuration fixed!
```

### 3. Generate SSL

```bash
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh blog.b7g.app
```

Wait 30-60 seconds for certificate generation.

### 4. Access

Visit: `https://blog.b7g.app` ✓

---

## Why This Process?

### The Problem

1. aaPanel creates sites with `listen 80;`
2. But our nginx runs on port `8080`
3. Traefik uses ports `80` and `443`
4. Sites created with port 80 won't be accessible through Traefik

### The Solution

1. **fix-site-port.sh** updates nginx config to use port 8080
2. **generate-ssl-cert.sh** configures Traefik to proxy to nginx on port 8080
3. Traefik handles SSL certificates and forwards to nginx

### The Result

```
Internet (80/443) → Traefik (SSL) → Nginx (8080) → Your Site
```

---

## Troubleshooting

### "Site not accessible" after Step 1

**Cause:** Port not fixed yet

**Solution:** Run Step 2 (fix-site-port.sh)

---

### "Nginx configuration test failed"

**Cause:** Syntax error in nginx config

**Solution:**
```bash
# Check nginx config
nginx -t

# View config file
cat /www/server/panel/vhost/nginx/YOUR-DOMAIN.conf

# Fix manually or restore backup
ls -la /www/server/panel/vhost/nginx/YOUR-DOMAIN.conf.backup-*
```

---

### "SSL certificate generation failed"

**Cause:** Usually DNS not pointing to server

**Solution:**
```bash
# Check DNS
nslookup YOUR-DOMAIN.com

# Should show your server IP: 89.163.146.144

# If not, update DNS and wait for propagation
```

---

### "Domain binding error" or "Please confirm domain bound"

**Cause:** Nginx listening on wrong port

**Solution:**
```bash
# Check what port nginx is using for your site
grep "listen" /www/server/panel/vhost/nginx/YOUR-DOMAIN.conf

# Should show:
# listen 8080;

# If it shows 'listen 80;', run:
sudo /root/aaPanel-nginx-fix/fix-site-port.sh YOUR-DOMAIN.com
```

---

## Advanced: Multiple Domains

### Same Site, Multiple Domains

If you want `example.com` and `www.example.com` to point to the same site:

**Step 1:** Create site in aaPanel with primary domain (`example.com`)

**Step 2:** In aaPanel, add alias domain:
- Website → Click on site → Domains
- Add `www.example.com` as alias

**Step 3:** Fix port
```bash
sudo /root/aaPanel-nginx-fix/fix-site-port.sh example.com
```

**Step 4:** Generate SSL for both
```bash
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh example.com www.example.com
```

---

## Automation Script

Want to automate Steps 2 & 3? Create this script:

```bash
#!/bin/bash
# new-site.sh - Automate new site setup

DOMAIN="$1"

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 DOMAIN"
    exit 1
fi

echo "Setting up $DOMAIN..."
echo ""

# Step 1: Fix port
echo "Step 1: Fixing nginx port..."
sudo /root/aaPanel-nginx-fix/fix-site-port.sh "$DOMAIN"
echo ""

# Step 2: Generate SSL
echo "Step 2: Generating SSL certificate..."
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh "$DOMAIN"
echo ""

echo "Done! Your site is ready at: https://$DOMAIN"
```

Save as `/root/new-site.sh`, make executable:
```bash
chmod +x /root/new-site.sh
```

Use it:
```bash
# 1. Create site in aaPanel first
# 2. Run automation
sudo /root/new-site.sh blog.b7g.app
```

---

## Files and Scripts Reference

| Script | Purpose | Usage |
|--------|---------|-------|
| `fix-site-port.sh` | Fix nginx port 80→8080 | After creating site in aaPanel |
| `generate-ssl-cert.sh` | Generate SSL certificate | After fixing port |
| `nginx -t` | Test nginx config | Before reloading nginx |
| `systemctl reload nginx` | Apply nginx changes | After config changes |

---

## Checklist for New Sites

- [ ] **DNS:** Domain points to server IP
- [ ] **aaPanel:** Site created in aaPanel
- [ ] **Port:** Run `fix-site-port.sh DOMAIN`
- [ ] **SSL:** Run `generate-ssl-cert.sh DOMAIN`
- [ ] **Test:** Visit `https://DOMAIN`
- [ ] **Files:** Upload website files to `/www/wwwroot/DOMAIN/`

---

## Quick Commands

```bash
# Check if port is correct
grep "listen" /www/server/panel/vhost/nginx/DOMAIN.conf

# Should show: listen 8080;

# Check if SSL is working
echo | openssl s_client -connect DOMAIN:443 2>/dev/null | openssl x509 -noout -dates

# Check Traefik proxy
docker service ls | grep DOMAIN

# View site files
ls -la /www/wwwroot/DOMAIN/

# View nginx logs
tail -f /www/wwwlogs/DOMAIN.log
tail -f /www/wwwlogs/DOMAIN.error.log
```

---

## Summary

**Every new site needs:**
1. ✅ Created in aaPanel
2. ✅ Port fixed (80→8080)
3. ✅ SSL certificate generated via Traefik

**Remember:**
- aaPanel creates sites with port 80 by default
- Always run `fix-site-port.sh` after creating a site
- Then run `generate-ssl-cert.sh` for SSL

**Result:**
- Site accessible via HTTPS
- Automatic SSL certificate renewal
- Traefik handles all SSL/routing
- Nginx serves the actual website

---

Last Updated: 2025-12-08
