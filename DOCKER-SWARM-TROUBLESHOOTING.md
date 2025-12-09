# Docker Swarm Troubleshooting Guide

## Common Issues and Solutions

---

## Redis Authentication Error in Multi-Stack Deployments

### Problem Description

**Error Message:**
```
Error: ERR AUTH <password> called without any password configured for the default user.
Are you sure your configuration is correct?
```

**Symptoms:**
- Service connects to Redis successfully (shows "Connected to Redis")
- Immediately followed by authentication error
- Service restarts repeatedly with exit code 137
- Unhealthy container status

### Root Cause

Multiple Docker Swarm stacks running Redis services with the **same DNS alias** on the same network, causing service discovery conflicts.

**Example:**
```yaml
# Stack 1: chatwoot
services:
  chatwoot_redis:    # Creates alias: chatwoot_redis
    image: redis:latest
    # No password configured

# Stack 2: chatwoot-baileys
services:
  chatwoot_redis:    # Creates SAME alias: chatwoot_redis
    image: redis:alpine
    command: redis-server --requirepass "mypassword"
```

When a service tries to connect to `chatwoot_redis`, Docker Swarm's DNS may resolve to **either** Redis instance non-deterministically, causing authentication failures.

---

## Diagnosis

### Step 1: Check for Duplicate Service Aliases

```bash
# List all Redis services
docker service ls | grep redis

# Check network aliases for each Redis
docker service inspect STACK_redis --format '{{json .Spec.TaskTemplate.Networks}}' | jq -r '.[].Aliases'
```

**Look for duplicates:**
```bash
# Service 1
docker service inspect chatwoot_chatwoot_redis --format '{{json .Spec.TaskTemplate.Networks}}' | jq -r '.[].Aliases'
# Output: ["chatwoot_redis"]

# Service 2
docker service inspect chatwoot-baileys_chatwoot_redis --format '{{json .Spec.TaskTemplate.Networks}}' | jq -r '.[].Aliases'
# Output: ["chatwoot_redis"]  ⚠️ CONFLICT!
```

### Step 2: Check Application Configuration

```bash
# Check what Redis URL the application is using
docker service inspect APP_SERVICE --format '{{json .Spec.TaskTemplate.ContainerSpec.Env}}' | jq -r '.[]' | grep REDIS
```

### Step 3: Check Redis Password Configuration

```bash
# Check if Redis requires authentication
docker service inspect REDIS_SERVICE --format '{{json .Spec.TaskTemplate.ContainerSpec.Args}}' | jq -r

# Look for: --requirepass "password"
```

---

## Solution 1: Use Full Service Names (RECOMMENDED)

Update application to use the **full service name** including stack prefix.

### For Chatwoot-Baileys:

```bash
# Get current password
REDIS_PASSWORD=$(docker service inspect chatwoot-baileys_chatwoot_baileys_api \
  --format '{{json .Spec.TaskTemplate.ContainerSpec.Env}}' | \
  jq -r '.[]' | grep REDIS_PASSWORD | cut -d'=' -f2)

# Update service with full Redis service name
docker service update \
  --env-rm REDIS_URL \
  --env-add "REDIS_URL=redis://:${REDIS_PASSWORD}@chatwoot-baileys_chatwoot_redis:6379" \
  chatwoot-baileys_chatwoot_baileys_api
```

**Before:** `redis://:password@chatwoot_redis:6379` (ambiguous)
**After:** `redis://:password@chatwoot-baileys_chatwoot_redis:6379` (specific)

### Automated Fix:

```bash
sudo bash /root/aaPanel-nginx-fix/fix-chatwoot-baileys-redis.sh
```

---

## Solution 2: Rename Services to Avoid Conflicts

Modify your docker-compose files to use unique service names.

**Example:**

```yaml
# Stack 1: chatwoot.yaml
services:
  chatwoot_redis:    # Keep original name
    image: redis:latest

# Stack 2: chatwoot-baileys.yaml
services:
  baileys_redis:     # ✓ Changed to unique name
    image: redis:alpine
    command: redis-server --requirepass "password"

  chatwoot_baileys_api:
    environment:
      - REDIS_URL=redis://:password@baileys_redis:6379  # Updated
```

**Redeploy both stacks:**
```bash
docker stack deploy -c chatwoot.yaml chatwoot
docker stack deploy -c chatwoot-baileys.yaml chatwoot-baileys
```

---

## Solution 3: Separate Networks

Run stacks on different overlay networks to isolate service discovery.

```yaml
# Stack 1: chatwoot.yaml
networks:
  chatwoot_network:
    driver: overlay

services:
  chatwoot_redis:
    networks:
      - chatwoot_network

# Stack 2: chatwoot-baileys.yaml
networks:
  baileys_network:
    driver: overlay

services:
  chatwoot_redis:
    networks:
      - baileys_network  # Different network = no conflict
```

---

## Verification

### Check Service is Running

```bash
docker service ps STACK_SERVICE_NAME
```

**Healthy output:**
```
ID             NAME                    IMAGE           NODE    DESIRED STATE   CURRENT STATE
abc123         service.1               image:latest    node1   Running         Running 2 minutes ago
```

### Check Logs for Errors

```bash
# View recent logs
docker service logs STACK_SERVICE_NAME --since 1m

# Follow logs in real-time
docker service logs STACK_SERVICE_NAME -f

# Filter for Redis errors
docker service logs STACK_SERVICE_NAME --since 5m 2>&1 | grep -i "redis\|error"
```

**Success indicators:**
```
INFO: Connected to Redis
INFO: GET http://localhost:3025/status [200]
```

**No errors like:**
```
ERROR: Redis client error
Error: ERR AUTH <password> called without...
```

### Verify Configuration

```bash
# Check current REDIS_URL
docker service inspect SERVICE_NAME --format '{{json .Spec.TaskTemplate.ContainerSpec.Env}}' | jq -r '.[]' | grep REDIS_URL
```

---

## Prevention

### Best Practices for Multi-Stack Deployments

1. **Use Unique Service Names**
   ```yaml
   # Instead of:
   services:
     redis:

   # Use:
   services:
     myapp_redis:
   ```

2. **Use Full Service Names in Connections**
   ```
   # Instead of: redis://redis:6379
   # Use: redis://mystack_redis:6379
   ```

3. **Document Service Names**
   - Maintain a list of all service aliases
   - Document which stacks use which networks
   - Use consistent naming conventions

4. **Separate Networks When Possible**
   ```yaml
   networks:
     app_network:
       driver: overlay
       name: myapp_network
   ```

5. **Use Docker Compose Service Names with Stack Prefix**
   ```yaml
   services:
     app:
       environment:
         # Will resolve to: stackname_redis
         - REDIS_URL=redis://{{ .Task.Name }}_redis:6379
   ```

---

## Common Docker Swarm Service Discovery Issues

### Issue: "Connection Refused" to Service

**Cause:** Service not on same network

**Fix:**
```bash
# Check service networks
docker service inspect SERVICE --format '{{json .Spec.TaskTemplate.Networks}}' | jq

# Update service to join network
docker service update --network-add NETWORK_NAME SERVICE_NAME
```

### Issue: "Could not resolve host" Error

**Cause:** Service name typo or service doesn't exist

**Fix:**
```bash
# List all services in stack
docker stack services STACK_NAME

# Verify service name spelling
docker service ls | grep SERVICE_NAME
```

### Issue: Service Connects to Wrong Instance

**Cause:** Multiple services with same alias (this document's main topic)

**Fix:** Use full service name with stack prefix (see Solution 1)

---

## Quick Reference

### Useful Commands

```bash
# List all stacks
docker stack ls

# List services in stack
docker stack services STACK_NAME

# Check service status
docker service ps SERVICE_NAME

# View service logs
docker service logs SERVICE_NAME -f

# Inspect service configuration
docker service inspect SERVICE_NAME

# Update service environment variable
docker service update --env-add KEY=VALUE SERVICE_NAME
docker service update --env-rm KEY SERVICE_NAME

# Force service restart
docker service update --force SERVICE_NAME

# Check service networks
docker service inspect SERVICE_NAME --format '{{json .Spec.TaskTemplate.Networks}}' | jq

# Check service DNS aliases
docker service inspect SERVICE_NAME --format '{{json .Spec.TaskTemplate.Networks}}' | jq -r '.[].Aliases'

# Remove and redeploy service
docker service rm SERVICE_NAME
docker stack deploy -c compose.yml STACK_NAME
```

### Diagnostic Checklist

When debugging service connectivity:

- [ ] Check service is running: `docker service ps SERVICE`
- [ ] Check logs for errors: `docker service logs SERVICE --tail 50`
- [ ] Verify service names: `docker service ls`
- [ ] Check network membership: `docker service inspect SERVICE`
- [ ] Check DNS aliases: `docker service inspect SERVICE | jq .Spec.TaskTemplate.Networks`
- [ ] Verify environment variables: `docker service inspect SERVICE | jq .Spec.TaskTemplate.ContainerSpec.Env`
- [ ] Test DNS resolution from another container on same network
- [ ] Check for duplicate service aliases across stacks
- [ ] Verify network connectivity between services

---

## Example: Complete Fix Walkthrough

### Scenario: Chatwoot-Baileys Redis Authentication Error

**1. Identify the Problem**
```bash
docker service logs chatwoot-baileys_chatwoot_baileys_api --tail 20
# Error: ERR AUTH <password> called without any password configured
```

**2. Find Duplicate Services**
```bash
docker service ls | grep redis
# Output shows:
# chatwoot_chatwoot_redis
# chatwoot-baileys_chatwoot_redis

docker service inspect chatwoot_chatwoot_redis --format '{{json .Spec.TaskTemplate.Networks}}' | jq -r '.[].Aliases'
# ["chatwoot_redis"]

docker service inspect chatwoot-baileys_chatwoot_redis --format '{{json .Spec.TaskTemplate.Networks}}' | jq -r '.[].Aliases'
# ["chatwoot_redis"]  ⚠️ CONFLICT!
```

**3. Check Application Configuration**
```bash
docker service inspect chatwoot-baileys_chatwoot_baileys_api --format '{{json .Spec.TaskTemplate.ContainerSpec.Env}}' | jq -r '.[]' | grep REDIS
# REDIS_URL=redis://:450Ab6606289828redis@chatwoot_redis:6379
#                                          ^^^^^^^^^^^^^^ Ambiguous!
```

**4. Apply Fix**
```bash
docker service update \
  --env-rm REDIS_URL \
  --env-add "REDIS_URL=redis://:450Ab6606289828redis@chatwoot-baileys_chatwoot_redis:6379" \
  chatwoot-baileys_chatwoot_baileys_api
```

**5. Verify Fix**
```bash
# Wait for service to restart
sleep 10

# Check service status
docker service ps chatwoot-baileys_chatwoot_baileys_api

# Check logs - should show no errors
docker service logs chatwoot-baileys_chatwoot_baileys_api --since 1m

# Verify configuration
docker service inspect chatwoot-baileys_chatwoot_baileys_api \
  --format '{{json .Spec.TaskTemplate.ContainerSpec.Env}}' | \
  jq -r '.[]' | grep REDIS_URL
# REDIS_URL=redis://:450Ab6606289828redis@chatwoot-baileys_chatwoot_redis:6379
#                                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Specific!
```

**6. Monitor**
```bash
# Watch logs for any issues
docker service logs chatwoot-baileys_chatwoot_baileys_api -f

# Expected output:
# INFO: Connected to Redis
# INFO: No saved connections to reconnect
# INFO: GET http://localhost:3025/status [200]
```

---

## Additional Resources

- Docker Swarm DNS Documentation: https://docs.docker.com/network/overlay/
- Docker Service Networking: https://docs.docker.com/engine/swarm/networking/
- Redis Authentication: https://redis.io/docs/management/security/

---

**Last Updated:** 2025-12-09
**Tested On:** Docker Swarm (v20+), Redis (alpine & latest), Chatwoot-Baileys Stack
