# SSL Certificate Generator - Quick Start Guide

## Overview

The `generate-ssl-cert.sh` script automatically generates Let's Encrypt SSL certificates for your domains by configuring Traefik to proxy to nginx. No manual configuration needed!

## How It Works

```
Your Domain → Traefik (gets SSL cert) → Nginx (serves website)
```

1. You run the script with your domain name(s)
2. Script creates Traefik configuration automatically
3. Traefik requests SSL certificate from Let's Encrypt
4. Certificate is installed and auto-renewed
5. Your site is accessible via HTTPS!

## Prerequisites

Before using the script, ensure:

- [x] Domain DNS points to your server IP
- [x] Traefik is running on ports 80/443
- [x] Nginx is running on port 8080
- [x] (Optional) Site created in aaPanel

## Quick Start

### 1. Basic Usage - Single Domain

```bash
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh example.com
```

**What happens:**
- Creates Traefik configuration for `example.com`
- Deploys to Docker Swarm
- Generates SSL certificate automatically
- Verifies certificate was obtained
- Shows you the certificate details

### 2. Multiple Domains (Same Certificate)

```bash
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh example.com www.example.com
```

**Use this when:**
- You want both `example.com` and `www.example.com` to work
- All domains should share the same SSL certificate (SAN certificate)

### 3. With Verification

```bash
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh -v blog.example.com
```

The `-v` flag enables extra verification steps to ensure everything works.

### 4. Custom Stack Name

```bash
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh -n myblog blog.example.com
```

**Why use custom names:**
- Easier to remember
- Better organization when you have many sites
- Cleaner service names in Docker

### 5. Remove and Recreate

```bash
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh -r example.com
```

Use this when you need to update configuration for an existing domain.

## Real-World Examples

### Example 1: Personal Blog

**Scenario:** You have a blog at `blog.b7g.app`

**Steps:**
1. Create site in aaPanel:
   - Go to aaPanel → Website → Add Site
   - Domain: `blog.b7g.app`
   - Don't apply for SSL

2. Run the script:
   ```bash
   sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh blog.b7g.app
   ```

3. Wait 30-60 seconds for certificate

4. Access your blog:
   ```
   https://blog.b7g.app
   ```

**Done!** ✓

---

### Example 2: Main Website with www

**Scenario:** Website at `example.com` and `www.example.com`

**Steps:**
1. Create site in aaPanel with domain `example.com`

2. Run script with both domains:
   ```bash
   sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh example.com www.example.com
   ```

3. Both URLs now work with HTTPS:
   - `https://example.com` ✓
   - `https://www.example.com` ✓

---

### Example 3: Multiple Sites

**Scenario:** You have blog, api, and app subdomains

**Option A: Separate certificates (recommended)**
```bash
# Blog
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh blog.example.com

# API
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh api.example.com

# App
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh app.example.com
```

**Option B: Single certificate for all**
```bash
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh \
  blog.example.com \
  api.example.com \
  app.example.com
```

---

### Example 4: Update Existing Certificate

**Scenario:** You already generated a certificate but want to add another domain

**Steps:**
1. Remove the old stack:
   ```bash
   sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh -r example.com
   ```

2. Recreate with new domains:
   ```bash
   sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh example.com www.example.com new.example.com
   ```

---

## Command Options

### All Available Options

```bash
generate-ssl-cert.sh [OPTIONS] DOMAIN [DOMAIN2 DOMAIN3 ...]
```

| Option | Description | Example |
|--------|-------------|---------|
| `-h, --help` | Show help message | `generate-ssl-cert.sh -h` |
| `-p, --port PORT` | Specify nginx port (default: 8080) | `generate-ssl-cert.sh -p 8080 example.com` |
| `-n, --name NAME` | Custom stack name | `generate-ssl-cert.sh -n myblog blog.com` |
| `-v, --verify` | Verify certificate after generation | `generate-ssl-cert.sh -v example.com` |
| `-r, --remove` | Remove existing stack first | `generate-ssl-cert.sh -r example.com` |
| `--no-wait` | Don't wait for certificate (faster) | `generate-ssl-cert.sh --no-wait example.com` |

### Combining Options

```bash
# Remove, recreate with custom name, and verify
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh -r -n myblog -v blog.example.com

# Multiple domains with custom name
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh -n mainsite example.com www.example.com
```

## What You'll See

### Successful Run Output

```
========================================
Checking Prerequisites
========================================
✓ Running as root
✓ Docker is installed
✓ Docker Swarm is active
✓ Traefik service is running
✓ Traefik network exists
✓ Nginx is running
✓ Service listening on port 8080

========================================
Validating Domains
========================================
✓ Valid: example.com

ℹ Auto-generated stack name: example

========================================
Checking DNS Resolution
========================================
ℹ Checking DNS for example.com...
✓ DNS correctly points to 89.163.146.144

========================================
Checking aaPanel Sites
========================================
✓ aaPanel site exists: /www/wwwroot/example.com

========================================
Generating Configuration
========================================
ℹ Creating Traefik configuration...
✓ Configuration created: /root/ssl-configs/example.yml

========================================
Deploying to Traefik
========================================
ℹ Deploying stack 'example'...
✓ Stack deployed successfully

ℹ Waiting for service to start...
✓ Service is running

========================================
Certificate Verification
========================================
ℹ Waiting for SSL certificate (this may take up to 60s)...
✓ SSL certificate successfully obtained!

========================================
Certificate Details
========================================
  issuer=C = US, O = Let's Encrypt, CN = R12
  subject=CN = example.com
  notBefore=Dec  8 18:00:00 2025 GMT
  notAfter=Mar  8 18:00:00 2026 GMT

========================================
Testing Domains
========================================
ℹ Testing HTTPS access to example.com...
✓ Domain is accessible via HTTPS

========================================
Deployment Summary
========================================
Stack Name:     example
Domains:        example.com
Config File:    /root/ssl-configs/example.yml
Nginx Port:     8080

========================================
Useful Commands
========================================
  # Check service status
  docker service ps example_example-proxy

  # View service logs
  docker service logs -f example_example-proxy

  # Check certificate
  echo | openssl s_client -connect example.com:443 2>/dev/null | openssl x509 -noout -dates

  # Remove stack
  docker stack rm example

  # Test HTTPS
  curl -I https://example.com

✓ SSL certificate generation complete!
ℹ Access your site(s) at:
  https://example.com
```

## Troubleshooting

### Problem: "DNS not resolving"

**Cause:** Domain doesn't point to your server

**Solution:**
1. Check your DNS settings
2. Make sure A record points to your server IP
3. Wait for DNS propagation (can take up to 48 hours)
4. Test with: `nslookup your-domain.com 8.8.8.8`

---

### Problem: "Nginx is not running"

**Cause:** Nginx service is stopped

**Solution:**
```bash
sudo systemctl start nginx
sudo systemctl status nginx
```

---

### Problem: "Certificate verification timed out"

**Cause:** Let's Encrypt couldn't verify domain ownership

**Common reasons:**
1. DNS not pointing to server
2. Firewall blocking ports 80/443
3. Traefik not running properly

**Solution:**
```bash
# Check DNS
nslookup your-domain.com

# Check Traefik
docker service ls | grep traefik

# Check ports
ss -tlnp | grep -E ':(80|443)'

# Try again
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh -r your-domain.com
```

---

### Problem: "Site directory not found in aaPanel"

**Cause:** Site not created in aaPanel (warning only)

**Solution:**
1. Go to aaPanel → Website → Add Site
2. Add your domain
3. Run the script again

**Note:** This is just a warning. The SSL certificate will still be generated, but you won't have a website directory yet.

---

### Problem: "Stack already exists"

**Cause:** Domain already configured

**Solution:**
Use the `-r` flag to remove and recreate:
```bash
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh -r your-domain.com
```

---

## Managing Certificates

### Check Certificate Status

```bash
# View certificate expiry
echo | openssl s_client -connect example.com:443 2>/dev/null | openssl x509 -noout -dates

# View full certificate details
echo | openssl s_client -connect example.com:443 2>/dev/null | openssl x509 -noout -text
```

### Check Service Status

```bash
# List all SSL-related services
docker service ls | grep proxy

# Check specific service
docker service ps example_example-proxy

# View logs
docker service logs -f example_example-proxy
```

### Remove Certificate/Service

```bash
# Remove specific stack
docker stack rm example

# Or use the script
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh -r example.com
```

### Update Certificate (Add More Domains)

```bash
# Remove old configuration
docker stack rm example

# Deploy with new domain list
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh example.com www.example.com new.example.com
```

## Certificate Auto-Renewal

**Good news:** You don't need to do anything!

Traefik automatically renews certificates:
- Renewal starts 30 days before expiry
- Happens in the background
- No downtime
- No manual intervention needed

## Advanced Usage

### Custom Nginx Port

If your nginx runs on a different port:

```bash
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh -p 8888 example.com
```

### Batch Processing Multiple Sites

Create a script:

```bash
#!/bin/bash
# generate-all-certs.sh

DOMAINS=(
    "blog.example.com"
    "api.example.com"
    "app.example.com"
)

for domain in "${DOMAINS[@]}"; do
    echo "Generating certificate for $domain..."
    sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh "$domain"
    echo ""
done
```

Run it:
```bash
chmod +x generate-all-certs.sh
./generate-all-certs.sh
```

### Configuration Files

All generated configurations are stored in:
```
/root/ssl-configs/
```

You can edit these files and redeploy:
```bash
# Edit configuration
nano /root/ssl-configs/example.yml

# Redeploy
docker stack deploy -c /root/ssl-configs/example.yml example
```

## Files and Locations

| File | Purpose | Location |
|------|---------|----------|
| Script | Main SSL generator | `/root/aaPanel-nginx-fix/generate-ssl-cert.sh` |
| Configs | Generated configurations | `/root/ssl-configs/*.yml` |
| Certificates | Stored by Traefik | Docker volume: `volume_swarm_certificates` |
| Nginx sites | Website files | `/www/wwwroot/DOMAIN/` |

## Quick Reference Card

```bash
# Generate SSL for one domain
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh example.com

# Multiple domains
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh example.com www.example.com

# With verification
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh -v example.com

# Remove and recreate
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh -r example.com

# Custom name
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh -n myblog blog.example.com

# Check certificate
echo | openssl s_client -connect example.com:443 2>/dev/null | openssl x509 -noout -dates

# List all services
docker service ls | grep proxy

# Remove service
docker stack rm example
```

## Best Practices

1. **Create aaPanel site first** (optional but recommended)
   - Easier to manage website files
   - Consistent directory structure

2. **Use separate certificates for different projects**
   - Better isolation
   - Easier to manage
   - Independent renewal

3. **Use custom stack names for important sites**
   - Easier to identify
   - Better documentation

4. **Keep configuration files**
   - Backup `/root/ssl-configs/` directory
   - Include in version control
   - Document customizations

5. **Monitor certificate expiry**
   - Check Traefik logs occasionally
   - Set up monitoring if running production sites

## Getting Help

### View Script Help

```bash
/root/aaPanel-nginx-fix/generate-ssl-cert.sh --help
```

### Check Traefik Logs

```bash
docker service logs traefik_traefik | tail -100
```

### Check Nginx Logs

```bash
tail -f /www/wwwlogs/your-domain.log
tail -f /www/wwwlogs/your-domain.error.log
```

### Debug Mode

Add `-x` to see what the script is doing:
```bash
bash -x /root/aaPanel-nginx-fix/generate-ssl-cert.sh example.com
```

## Common Workflows

### New Site Workflow

1. Create DNS record (A record to server IP)
2. Wait for DNS propagation (optional but recommended)
3. Create site in aaPanel
4. Run SSL generator script
5. Upload website files
6. Test HTTPS access

### Existing Site Adding SSL

1. Site already exists in aaPanel
2. Run SSL generator script
3. Test HTTPS access
4. Update any hardcoded HTTP links in your site

### Moving Site from Another Server

1. Set up DNS to point to new server
2. Create site in aaPanel
3. Upload website files
4. Run SSL generator script
5. Test thoroughly before switching

## Support and Resources

- **Documentation:** `/root/aaPanel-nginx-fix/TRAEFIK-NGINX-INTEGRATION.md`
- **Template:** `/root/aaPanel-nginx-fix/traefik-nginx-site-template.yml`
- **Example:** `/root/aaPanel-nginx-fix/nginx-traefik-proxy.yml`
- **Repository:** https://github.com/senaiapy/aaPanel-nginx-fix

---

**Last Updated:** 2025-12-08
**Version:** 1.0
**Compatible with:** Traefik v3.4.0, Nginx 1.24.0, aaPanel
