# Quick Start - SSL Certificate Generator

## TL;DR

Generate SSL certificates for your domains in one command:

```bash
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh your-domain.com
```

That's it! Wait 30-60 seconds and your site will have HTTPS with auto-renewing SSL certificate.

## The 3-Step Process

### Step 1: Create Site in aaPanel (Optional)

1. Go to aaPanel: `https://your-server-ip:12321/aapanels`
2. Website → Add Site
3. Enter domain name
4. **Skip SSL certificate application**

### Step 2: Run the Script

```bash
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh your-domain.com
```

### Step 3: Done!

Access your site:
```
https://your-domain.com
```

## Common Usage Examples

### Single Domain
```bash
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh blog.example.com
```

### Domain + www
```bash
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh example.com www.example.com
```

### Multiple Sites
```bash
# Run separately for each
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh blog.example.com
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh api.example.com
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh app.example.com
```

### Update Existing
```bash
sudo /root/aaPanel-nginx-fix/generate-ssl-cert.sh -r example.com
```

## Troubleshooting

### DNS Not Pointing to Server?

Check DNS:
```bash
nslookup your-domain.com
```

Should show your server IP: `89.163.146.144`

### Certificate Not Generated?

Wait a bit longer (can take up to 2 minutes), then check:
```bash
echo | openssl s_client -connect your-domain.com:443 2>/dev/null | openssl x509 -noout -dates
```

### Service Not Working?

Check status:
```bash
docker service ls | grep proxy
docker service ps STACKNAME_STACKNAME-proxy
```

## Management Commands

```bash
# List all SSL services
docker service ls | grep proxy

# Check specific service
docker service ps example_example-proxy

# View logs
docker service logs -f example_example-proxy

# Remove service
docker stack rm example

# Check certificate
echo | openssl s_client -connect example.com:443 2>/dev/null | openssl x509 -noout -dates
```

## Help

Full documentation:
```bash
# View script help
/root/aaPanel-nginx-fix/generate-ssl-cert.sh --help

# Read comprehensive guide
cat /root/aaPanel-nginx-fix/SSL-CERTIFICATE-GENERATOR-GUIDE.md

# Read Traefik integration guide
cat /root/aaPanel-nginx-fix/TRAEFIK-NGINX-INTEGRATION.md
```

## What Files Were Created?

- **Script:** `/root/aaPanel-nginx-fix/generate-ssl-cert.sh`
- **Guide:** `/root/aaPanel-nginx-fix/SSL-CERTIFICATE-GENERATOR-GUIDE.md`
- **Configs:** `/root/ssl-configs/*.yml` (auto-generated)

## Remember

✓ DNS must point to your server before running
✓ Certificates auto-renew (no manual work needed)
✓ Run script again to update/recreate certificates
✓ Use `-r` flag to remove and recreate
✓ Each domain can have its own certificate

---

**Need more help?** Read: `/root/aaPanel-nginx-fix/SSL-CERTIFICATE-GENERATOR-GUIDE.md`
