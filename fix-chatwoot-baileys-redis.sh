#!/bin/bash

#########################################################
# Fix Chatwoot-Baileys Redis Connection Error
#
# Problem: baileys API connects to wrong Redis instance
# Solution: Update REDIS_URL to use full service name
#########################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() { echo -e "${CYAN}========================================${NC}"; echo -e "${CYAN}$1${NC}"; echo -e "${CYAN}========================================${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

print_header "Chatwoot-Baileys Redis Fix"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root"
    exit 1
fi

print_info "Diagnosing Redis connection issue..."
echo ""

# Show current configuration
print_info "Current baileys API Redis configuration:"
docker service inspect chatwoot-baileys_chatwoot_baileys_api --format '{{json .Spec.TaskTemplate.ContainerSpec.Env}}' | jq -r '.[]' | grep REDIS

echo ""
print_info "Redis services available:"
docker service ls | grep redis

echo ""

print_warning "PROBLEM IDENTIFIED:"
echo "  - Both Redis instances use the same DNS alias: 'chatwoot_redis'"
echo "  - This causes DNS resolution conflicts"
echo "  - Baileys API connects to the WRONG Redis (one without password)"
echo ""

print_header "Solution Options"
echo ""
echo "1. Update baileys API to use full service name (RECOMMENDED)"
echo "   Change: redis://:PASSWORD@chatwoot_redis:6379"
echo "   To:     redis://:PASSWORD@chatwoot-baileys_chatwoot_redis:6379"
echo ""
echo "2. Remove Redis password from baileys setup"
echo "   (Less secure, not recommended)"
echo ""

read -p "Choose option (1 or 2): " option

if [ "$option" = "1" ]; then
    print_header "Updating Baileys API Configuration"
    echo ""

    # Get current password
    REDIS_PASSWORD=$(docker service inspect chatwoot-baileys_chatwoot_baileys_api --format '{{json .Spec.TaskTemplate.ContainerSpec.Env}}' | jq -r '.[]' | grep REDIS_PASSWORD | cut -d'=' -f2)

    print_info "Redis password: $REDIS_PASSWORD"
    print_info "Updating service with correct Redis URL..."

    # Update the service
    docker service update \
        --env-rm REDIS_URL \
        --env-add "REDIS_URL=redis://:${REDIS_PASSWORD}@chatwoot-baileys_chatwoot_redis:6379" \
        chatwoot-baileys_chatwoot_baileys_api

    print_success "Service updated!"
    echo ""

    print_info "Waiting for service to restart..."
    sleep 5

    print_info "Checking service status..."
    docker service ps chatwoot-baileys_chatwoot_baileys_api --no-trunc | head -5

    echo ""
    print_success "Fix applied!"
    echo ""
    print_info "Monitor logs with:"
    echo "  docker service logs chatwoot-baileys_chatwoot_baileys_api -f"

elif [ "$option" = "2" ]; then
    print_header "Removing Redis Password Requirement"
    echo ""

    print_warning "This will make Redis accessible without authentication!"
    read -p "Are you sure? (yes/no): " confirm

    if [ "$confirm" = "yes" ]; then
        print_info "Updating baileys Redis to remove password..."

        # Update Redis service to remove password
        docker service update \
            --args "redis-server --appendonly yes --port 6379" \
            chatwoot-baileys_chatwoot_redis

        print_success "Redis password removed"
        echo ""

        print_info "Updating baileys API to connect without password..."

        # Update baileys API
        docker service update \
            --env-rm REDIS_URL \
            --env-rm REDIS_PASSWORD \
            --env-add "REDIS_URL=redis://chatwoot_redis:6379" \
            chatwoot-baileys_chatwoot_baileys_api

        print_success "Fix applied!"
        echo ""
        print_info "Monitor logs with:"
        echo "  docker service logs chatwoot-baileys_chatwoot_baileys_api -f"
    else
        print_info "Operation cancelled"
        exit 0
    fi
else
    print_error "Invalid option"
    exit 1
fi

echo ""
print_header "Verification"
echo ""

print_info "Waiting for services to stabilize..."
sleep 10

print_info "Checking baileys API logs for errors..."
docker service logs chatwoot-baileys_chatwoot_baileys_api --tail 20 2>&1 | grep -i "error\|redis" || echo "No recent errors found"

echo ""
print_header "Fix Complete"
echo ""
print_success "The Redis connection issue should now be resolved"
echo ""
print_info "Useful commands:"
echo "  # Check service status"
echo "  docker service ps chatwoot-baileys_chatwoot_baileys_api"
echo ""
echo "  # View logs"
echo "  docker service logs chatwoot-baileys_chatwoot_baileys_api -f"
echo ""
echo "  # Restart service if needed"
echo "  docker service update --force chatwoot-baileys_chatwoot_baileys_api"
echo ""
