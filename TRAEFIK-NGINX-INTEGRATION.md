# Traefik + Nginx Integration Guide

## Overview

This guide explains how to use Traefik (ports 80/443) and nginx (ports 8080/8443) together, with automatic SSL certificates from Let's Encrypt.

## Architecture

```
Internet (Port 80/443)
    ↓
Traefik (Docker Swarm)
    ├─ Handles SSL certificates
    ├─ Routes by domain name
    └─ Proxies to backends
        ↓
Nginx on aaPanel (Port 8080/8443)
    ├─ Serves websites
    └─ Managed via aaPanel
```

## Problem & Solution

### The Problem

When nginx runs on non-standard ports (8080/8443), aaPanel's SSL certificate verification fails because:

1. Let's Encrypt validation requires access on port 80
2. Traefik is using port 80 and redirects all traffic to HTTPS
3. The domain doesn't reach nginx for ACME challenge verification

**Error:**
```
Verification failed, domain name resolution error or verification URL cannot be accessed!
Invalid response from http://domain/.well-known/acme-challenge/...: 404
```

### The Solution

Use Traefik to:
1. Handle SSL certificates automatically
2. Proxy domains to nginx on port 8080
3. Route traffic based on domain names

## Setup Instructions

### Step 1: Create Site in aaPanel

1. Login to aaPanel: `https://your-server:12321/aapanels`
2. Go to "Website" → "Add Site"
3. Enter your domain name
4. **Do NOT** apply for SSL certificate in aaPanel
5. Create the site normally

### Step 2: Configure Traefik Proxy

Create a configuration file for your site:

```bash
# Copy the template
cp /root/traefik-nginx-site-template.yml /root/mysite.yml

# Edit the file
nano /root/mysite.yml
```

Replace placeholders:
- `SITENAME` → Your site identifier (e.g., `blog`, `api`, `testserver`)
- `DOMAIN` → Your domain name (e.g., `blog.b7g.app`)

Example:
```yaml
version: '3.8'

services:
  blog-proxy:
    image: alpine:latest
    command: sleep infinity
    networks:
      - traefik_public
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.blog-http.rule=Host(`blog.b7g.app`)"
        - "traefik.http.routers.blog-http.entrypoints=web"
        - "traefik.http.routers.blog-http.service=blog-service"
        - "traefik.http.routers.blog-https.rule=Host(`blog.b7g.app`)"
        - "traefik.http.routers.blog-https.entrypoints=websecure"
        - "traefik.http.routers.blog-https.tls=true"
        - "traefik.http.routers.blog-https.tls.certresolver=letsencryptresolver"
        - "traefik.http.routers.blog-https.service=blog-service"
        - "traefik.http.services.blog-service.loadbalancer.server.url=http://172.18.0.1:8080"
        - "traefik.http.services.blog-service.loadbalancer.passhostheader=true"

networks:
  traefik_public:
    external: true
```

### Step 3: Deploy to Traefik

```bash
docker stack deploy -c /root/mysite.yml SITENAME
```

Example:
```bash
docker stack deploy -c /root/blog.yml blog
```

### Step 4: Verify

1. **Check service status:**
   ```bash
   docker service ls | grep blog
   ```

2. **Test HTTP (should redirect to HTTPS):**
   ```bash
   curl -I http://blog.b7g.app
   ```

3. **Test HTTPS (should return 200 OK):**
   ```bash
   curl -I https://blog.b7g.app
   ```

4. **Check SSL certificate:**
   ```bash
   echo | openssl s_client -connect blog.b7g.app:443 -servername blog.b7g.app 2>/dev/null | openssl x509 -noout -issuer -subject -dates
   ```

## Current Configuration

### Existing Site: testserver.b7g.app

**Configuration File:** `/root/nginx-traefik-proxy.yml`

**Stack Name:** `testserver`

**Status:** ✓ Active with valid SSL certificate

**Commands:**
```bash
# View logs
docker service logs testserver_testserver-proxy

# Update service
docker service update testserver_testserver-proxy

# Remove service
docker stack rm testserver
```

### SSL Certificate Details

```
Domain: testserver.b7g.app
Issuer: Let's Encrypt (R12)
Valid From: Dec 8, 2025
Valid Until: Mar 8, 2026
Auto-Renewal: Handled by Traefik
```

## Management Commands

### List All Proxy Services

```bash
docker service ls | grep proxy
```

### Check Service Status

```bash
docker service ps SITENAME_SITENAME-proxy
```

### View Service Logs

```bash
docker service logs -f SITENAME_SITENAME-proxy
```

### Update Service Configuration

```bash
# Method 1: Update labels directly
docker service update \
  --label-add "traefik.http.routers.SITENAME-https.rule=Host(`newdomain.com`)" \
  SITENAME_SITENAME-proxy

# Method 2: Re-deploy stack
docker stack deploy -c /root/mysite.yml SITENAME
```

### Remove a Site

```bash
docker stack rm SITENAME
```

## Troubleshooting

### Site Returns 404

**Check:**
1. Is the site created in aaPanel?
   ```bash
   ls -la /www/wwwroot/ | grep domain
   ```

2. Is nginx running?
   ```bash
   systemctl status nginx
   ```

3. Can you access directly on port 8080?
   ```bash
   curl -H "Host: domain.com" http://localhost:8080
   ```

### Site Returns 504 Gateway Timeout

**Check:**
1. Is nginx accessible from Docker network?
   ```bash
   # From host
   curl -I http://172.18.0.1:8080 -H "Host: domain.com"
   ```

2. Is the service URL correct?
   ```bash
   docker service inspect SITENAME_SITENAME-proxy --format '{{json .Spec.Labels}}' | grep loadbalancer.server.url
   ```

3. Check nginx logs:
   ```bash
   tail -f /www/wwwlogs/domain.com.log
   ```

### SSL Certificate Not Working

**Check:**
1. Is domain DNS resolving correctly?
   ```bash
   nslookup domain.com 8.8.8.8
   ```

2. Is Traefik router configured?
   ```bash
   docker service inspect SITENAME_SITENAME-proxy
   ```

3. Check Traefik logs:
   ```bash
   docker service logs traefik_traefik | grep domain.com
   ```

### Site Not Accessible

**Checklist:**
```bash
# 1. DNS resolution
nslookup domain.com

# 2. Nginx running
systemctl status nginx

# 3. Service deployed
docker service ls | grep SITENAME

# 4. Service running
docker service ps SITENAME_SITENAME-proxy

# 5. Direct nginx access
curl -I http://89.163.146.144:8080 -H "Host: domain.com"

# 6. Through Traefik
curl -I http://domain.com
curl -I https://domain.com
```

## Advanced Configuration

### Multiple Domains on One Site

```yaml
# Edit your stack file
- "traefik.http.routers.SITENAME-https.rule=Host(`domain1.com`) || Host(`domain2.com`) || Host(`www.domain1.com`)"
```

### Custom Headers

```yaml
# Add custom headers
- "traefik.http.middlewares.SITENAME-headers.headers.customresponseheaders.X-Custom-Header=value"
- "traefik.http.routers.SITENAME-https.middlewares=SITENAME-headers"
```

### Rate Limiting

```yaml
# Add rate limiting
- "traefik.http.middlewares.SITENAME-ratelimit.ratelimit.average=100"
- "traefik.http.middlewares.SITENAME-ratelimit.ratelimit.burst=50"
- "traefik.http.routers.SITENAME-https.middlewares=SITENAME-ratelimit"
```

### IP Whitelisting

```yaml
# Restrict access by IP
- "traefik.http.middlewares.SITENAME-ipwhitelist.ipwhitelist.sourcerange=1.2.3.4/32,5.6.7.0/24"
- "traefik.http.routers.SITENAME-https.middlewares=SITENAME-ipwhitelist"
```

## Network Configuration

### Docker Networks

Traefik uses `traefik_public` network:
```bash
# View network
docker network inspect traefik_public

# List containers in network
docker network inspect traefik_public --format '{{range .Containers}}{{.Name}} {{end}}'
```

### Host Network Access

Nginx is accessed via Docker gateway bridge:
```bash
# Show network interfaces
ip addr show docker_gwbridge

# Gateway IP (used in configuration)
# 172.18.0.1 → docker_gwbridge
# 172.17.0.1 → docker0 (not used in swarm)
```

## Files Reference

### Configuration Files

- `/root/nginx-traefik-proxy.yml` - testserver.b7g.app configuration
- `/root/traefik-nginx-site-template.yml` - Template for new sites
- `/www/server/panel/vhost/nginx/*.conf` - Nginx site configurations

### Logs

- `/www/wwwlogs/*.log` - Nginx access logs
- `/www/wwwlogs/*.error.log` - Nginx error logs
- `docker service logs traefik_traefik` - Traefik logs

## Best Practices

1. **Always use the template** for new sites to maintain consistency
2. **Test nginx directly** on port 8080 before adding to Traefik
3. **Monitor certificates** - Traefik auto-renews 30 days before expiry
4. **Keep backups** of stack configuration files
5. **Document custom configurations** in your stack YAML files
6. **Use meaningful stack names** that match your domain/site name

## Quick Reference

### Add New Site Checklist

- [ ] Create site in aaPanel (don't apply SSL)
- [ ] Copy template: `cp /root/traefik-nginx-site-template.yml /root/SITENAME.yml`
- [ ] Edit file: Replace SITENAME and DOMAIN
- [ ] Deploy: `docker stack deploy -c /root/SITENAME.yml SITENAME`
- [ ] Test HTTP: `curl -I http://DOMAIN`
- [ ] Test HTTPS: `curl -I https://DOMAIN`
- [ ] Verify SSL: `echo | openssl s_client -connect DOMAIN:443 2>/dev/null | openssl x509 -noout -dates`

### Common Commands

```bash
# List all stacks
docker stack ls

# List services in a stack
docker stack services STACKNAME

# View service logs
docker service logs -f STACKNAME_SERVICENAME

# Update service
docker stack deploy -c /root/file.yml STACKNAME

# Remove stack
docker stack rm STACKNAME

# Restart nginx
systemctl restart nginx

# Test nginx config
nginx -t
```

## Support

For issues:
- Nginx/aaPanel: https://forum.aapanel.com/
- Traefik: https://doc.traefik.io/traefik/
- Docker Swarm: https://docs.docker.com/engine/swarm/

---

Last Updated: 2025-12-08
Configuration: Traefik v3.4.0 + Nginx 1.24.0 + aaPanel
