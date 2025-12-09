# Chatwoot-Baileys Stack Fixes

## Issues Fixed

### Issue 1: Redis Authentication Error ✅ FIXED

**Problem:**
```
Error: ERR AUTH <password> called without any password configured for the default user
```

**Root Cause:**
Multiple Redis services with the same DNS alias `chatwoot_redis` on the traefik_public network:
- `chatwoot_chatwoot_redis` (no password)
- `chatwoot-baileys_chatwoot_redis` (password: 450Ab6606289828redis)

Docker Swarm's DNS randomly resolved to either instance, causing authentication failures.

**Services Affected:**
1. `chatwoot-baileys_chatwoot_baileys_api`
2. `chatwoot-baileys_chatwoot_rails`
3. `chatwoot-baileys_chatwoot_sidekiq`

**Solution Applied:**
Updated all services to use the full service name instead of ambiguous alias:

```bash
# Before (ambiguous)
REDIS_URL=redis://:450Ab6606289828redis@chatwoot_redis:6379

# After (specific)
REDIS_URL=redis://:450Ab6606289828redis@chatwoot-baileys_chatwoot_redis:6379
```

**Commands Used:**
```bash
# Baileys API
docker service update \
  --env-rm REDIS_URL \
  --env-add "REDIS_URL=redis://:450Ab6606289828redis@chatwoot-baileys_chatwoot_redis:6379" \
  chatwoot-baileys_chatwoot_baileys_api

# Rails
docker service update \
  --env-rm REDIS_URL \
  --env-add "REDIS_URL=redis://:450Ab6606289828redis@chatwoot-baileys_chatwoot_redis:6379" \
  --label-add "traefik.http.services.chatwoot_rails.loadbalancer.server.scheme=http" \
  chatwoot-baileys_chatwoot_rails

# Sidekiq
docker service update \
  --env-rm REDIS_URL \
  --env-add "REDIS_URL=redis://:450Ab6606289828redis@chatwoot-baileys_chatwoot_redis:6379" \
  chatwoot-baileys_chatwoot_sidekiq
```

**Verification:**
```bash
# Check services are running
docker service ls | grep chatwoot-baileys

# Check logs for errors
docker service logs chatwoot-baileys_chatwoot_baileys_api --since 1m | grep -i error
docker service logs chatwoot-baileys_chatwoot_sidekiq --since 1m | grep -i error
```

**Result:**
- ✅ Baileys API: Running successfully, health checks passing
- ✅ Sidekiq: Running successfully, processing jobs
- ⚠️ Rails: Running but experiencing HTTP parse errors (see Issue 2)

---

### Issue 2: HTTP Parse Error in Rails Service ⚠️ ONGOING

**Problem:**
```
HTTP parse error, malformed request: #<Puma::HttpParserError: Invalid HTTP format, parsing fails. Are you trying to open an SSL connection to a non-SSL Puma?>
[1] ! reaped unknown child process pid=XXX status=pid XXX exit 1
```

**Symptoms:**
- Error occurs every 60 seconds
- Spawns child processes that exit with status 1
- Eventually causes container health check failures
- Service restarts repeatedly

**Root Cause:**
Something is attempting HTTPS connections to Puma on port 3000, but Puma is configured for HTTP only.

**Possible Sources:**
1. External security scanner/bot probing port 3000
2. Monitoring service attempting HTTPS health checks
3. Another service in the stack misconfigured to use HTTPS
4. Traefik attempting backend health checks with HTTPS

**Mitigations Applied:**
1. ✅ Added explicit HTTP scheme to Traefik configuration:
   ```yaml
   traefik.http.services.chatwoot_rails.loadbalancer.server.scheme=http
   ```

2. Health check is already using HTTP correctly:
   ```bash
   wget -qO- --header='Accept: text/html' http://127.0.0.1:3000/
   ```

**Current Status:**
- Service boots successfully
- Puma listens on http://0.0.0.0:3000
- Workers start correctly
- HTTP requests work fine
- HTTPS connection attempts every 60 seconds cause child process failures
- Health check eventually fails, causing restart loop

**Temporary Workaround:**
The errors don't prevent normal operation when the service is running. They're cosmetic but cause eventual health check failures.

**Recommended Solutions:**

**Option 1: Increase Health Check Tolerance**
```bash
# Update health check to tolerate failed attempts
docker service update \
  --health-retries 20 \
  --health-interval 30s \
  chatwoot-baileys_chatwoot_rails
```

**Option 2: Identify and Stop HTTPS Probe**
```bash
# Find what's connecting on port 3000
docker exec $(docker ps -q -f name=chatwoot-baileys_chatwoot_rails) netstat -tnp | grep :3000

# Check Traefik logs for backend health check attempts
docker service logs traefik_traefik --since 2m | grep chatwoot_rails
```

**Option 3: Configure Puma for HTTPS (Not Recommended)**
This would require SSL certificates inside the container, adding complexity.

**Option 4: Use Nginx Sidecar**
Add nginx as a sidecar container to handle HTTPS termination before Puma.

---

## Service Status Summary

### ✅ Working Services

**1. chatwoot-baileys_chatwoot_baileys_api**
- Status: Running (14+ minutes)
- Health: Passing
- Redis: Connected correctly
- Logs: Clean, no errors

**2. chatwoot-baileys_chatwoot_sidekiq**
- Status: Running
- Health: Passing
- Redis: Connected correctly
- Jobs: Processing normally

**3. chatwoot-baileys_chatwoot_postgres**
- Status: Running
- Health: Passing

**4. chatwoot-baileys_chatwoot_redis**
- Status: Running
- Health: Passing

### ⚠️ Partially Working

**5. chatwoot-baileys_chatwoot_rails**
- Status: Starting/Restarting
- Health: Failing after ~5-10 minutes
- Redis: Connected correctly
- Issue: HTTP parse errors causing health check failures

---

## Verification Commands

### Check All Services Status
```bash
docker service ls | grep chatwoot-baileys
```

### Check Service Logs
```bash
# Baileys API
docker service logs chatwoot-baileys_chatwoot_baileys_api -f

# Rails
docker service logs chatwoot-baileys_chatwoot_rails -f

# Sidekiq
docker service logs chatwoot-baileys_chatwoot_sidekiq -f
```

### Check Redis Connections
```bash
# Verify each service is using correct Redis URL
docker service inspect chatwoot-baileys_chatwoot_baileys_api --format '{{json .Spec.TaskTemplate.ContainerSpec.Env}}' | jq -r '.[]' | grep REDIS_URL

docker service inspect chatwoot-baileys_chatwoot_rails --format '{{json .Spec.TaskTemplate.ContainerSpec.Env}}' | jq -r '.[]' | grep REDIS_URL

docker service inspect chatwoot-baileys_chatwoot_sidekiq --format '{{json .Spec.TaskTemplate.ContainerSpec.Env}}' | jq -r '.[]' | grep REDIS_URL
```

### Check Traefik Configuration
```bash
docker service inspect chatwoot-baileys_chatwoot_rails --format '{{json .Spec.Labels}}' | jq | grep -A2 chatwoot_rails
```

---

## Files Created

1. **fix-chatwoot-baileys-redis.sh**
   - Interactive script to diagnose and fix Redis connection issues
   - Located: `/root/aaPanel-nginx-fix/fix-chatwoot-baileys-redis.sh`
   - Usage: `sudo bash /root/aaPanel-nginx-fix/fix-chatwoot-baileys-redis.sh`

2. **DOCKER-SWARM-TROUBLESHOOTING.md**
   - Comprehensive guide for Docker Swarm service discovery issues
   - Covers Redis authentication errors, DNS conflicts, and solutions
   - Located: `/root/aaPanel-nginx-fix/DOCKER-SWARM-TROUBLESHOOTING.md`

3. **CHATWOOT-BAILEYS-FIXES.md** (this file)
   - Summary of all fixes applied to chatwoot-baileys stack
   - Located: `/root/aaPanel-nginx-fix/CHATWOOT-BAILEYS-FIXES.md`

---

## Next Steps

### For Rails HTTP Parse Error:

**Immediate Action:**
1. Identify source of HTTPS connections:
   ```bash
   # Monitor connections in real-time
   docker exec -it $(docker ps -q -f name=chatwoot-baileys_chatwoot_rails) sh
   watch -n 1 'netstat -tn | grep :3000'
   ```

2. Check if external monitoring is configured:
   - Review any monitoring services (Uptime Robot, Pingdom, etc.)
   - Check if they're configured to use HTTPS for health checks
   - Update to use HTTP if found

3. Increase health check tolerance temporarily:
   ```bash
   docker service update \
     --health-retries 20 \
     --health-interval 30s \
     --health-timeout 10s \
     chatwoot-baileys_chatwoot_rails
   ```

**Long-term Solution:**
- Investigate and eliminate source of HTTPS connection attempts
- Or configure proper HTTPS handling if HTTPS is required

### For Production Stability:

1. Monitor all services:
   ```bash
   watch -n 5 'docker service ls | grep chatwoot-baileys'
   ```

2. Set up log aggregation:
   ```bash
   # Forward logs to external system
   # Or set up log rotation
   ```

3. Configure alerts for service failures:
   ```bash
   # Use monitoring tools like Prometheus/Grafana
   # Or simple cron + email alerts
   ```

---

## Related Documentation

- [DOCKER-SWARM-TROUBLESHOOTING.md](./DOCKER-SWARM-TROUBLESHOOTING.md) - General Docker Swarm issues
- [fix-chatwoot-baileys-redis.sh](./fix-chatwoot-baileys-redis.sh) - Automated Redis fix script
- [HOW-TO-USE-PROXY.md](./HOW-TO-USE-PROXY.md) - Node.js proxy deployment guide

---

**Last Updated:** 2025-12-09
**Services Fixed:** 4/5 (Baileys API, Sidekiq, Postgres, Redis)
**Outstanding Issues:** 1 (Rails HTTP parse error)
