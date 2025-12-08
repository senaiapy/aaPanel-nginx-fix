#!/bin/bash

#########################################################
# Automatic SSL Certificate Generator
#
# This script automatically generates Let's Encrypt SSL
# certificates for domains using Traefik + nginx
#
# Author: marceluphd
# Repository: https://github.com/senaiapy/aaPanel-nginx-fix
#########################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
NGINX_PORT=8080
DOCKER_GATEWAY="172.18.0.1"
CONFIG_DIR="/root/ssl-configs"
TRAEFIK_NETWORK="traefik_public"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

#########################################################
# Functions
#########################################################

print_header() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

show_usage() {
    cat << EOF
${CYAN}Usage:${NC}
  $0 [OPTIONS] DOMAIN [DOMAIN2 DOMAIN3 ...]

${CYAN}Description:${NC}
  Automatically generates Let's Encrypt SSL certificates for one or more domains
  by configuring Traefik to proxy to nginx on port $NGINX_PORT.

${CYAN}Arguments:${NC}
  DOMAIN              One or more domain names (e.g., example.com www.example.com)

${CYAN}Options:${NC}
  -h, --help          Show this help message
  -p, --port PORT     Nginx port (default: $NGINX_PORT)
  -n, --name NAME     Custom stack name (default: auto-generated from first domain)
  -v, --verify        Verify certificate after generation
  -r, --remove        Remove existing stack if it exists
  --no-wait           Don't wait for certificate verification

${CYAN}Examples:${NC}
  # Single domain
  $0 blog.example.com

  # Multiple domains (will be added to the same certificate)
  $0 example.com www.example.com

  # With custom stack name
  $0 -n mysite blog.example.com api.example.com

  # Remove and recreate
  $0 -r example.com

  # Generate and verify
  $0 -v blog.example.com

${CYAN}Prerequisites:${NC}
  1. Domain DNS must point to this server ($(hostname -I | awk '{print $1}'))
  2. Traefik must be running on ports 80/443
  3. Nginx must be running on port $NGINX_PORT
  4. Site should be created in aaPanel (optional but recommended)

${CYAN}Notes:${NC}
  - Certificate generation may take 30-60 seconds
  - Certificates are automatically renewed by Traefik
  - All domains in one command share the same certificate (SAN)
  - Stack name is used for Docker service management

EOF
    exit 0
}

validate_domain() {
    local domain=$1
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 1
    fi
    return 0
}

check_prerequisites() {
    print_header "Checking Prerequisites"

    local all_good=true

    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root"
        all_good=false
    else
        print_success "Running as root"
    fi

    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        all_good=false
    else
        print_success "Docker is installed"
    fi

    # Check Docker Swarm
    if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
        print_error "Docker Swarm is not active"
        all_good=false
    else
        print_success "Docker Swarm is active"
    fi

    # Check Traefik
    if ! docker service ls 2>/dev/null | grep -q traefik; then
        print_error "Traefik service not found"
        all_good=false
    else
        print_success "Traefik service is running"
    fi

    # Check Traefik network
    if ! docker network ls | grep -q "$TRAEFIK_NETWORK"; then
        print_error "Traefik network '$TRAEFIK_NETWORK' not found"
        all_good=false
    else
        print_success "Traefik network exists"
    fi

    # Check nginx
    if ! systemctl is-active --quiet nginx; then
        print_warning "Nginx is not running (you may need to start it)"
    else
        print_success "Nginx is running"
    fi

    # Check nginx port
    if ! ss -tlnp | grep -q ":$NGINX_PORT"; then
        print_warning "Nothing listening on port $NGINX_PORT"
    else
        print_success "Service listening on port $NGINX_PORT"
    fi

    echo ""

    if [ "$all_good" = false ]; then
        print_error "Prerequisites check failed. Please fix the issues above."
        exit 1
    fi
}

check_dns() {
    local domain=$1
    print_info "Checking DNS for $domain..."

    local server_ip=$(hostname -I | awk '{print $1}')
    local dns_ip=$(dig +short "$domain" @8.8.8.8 | tail -1)

    if [ -z "$dns_ip" ]; then
        print_warning "DNS not resolving for $domain"
        return 1
    elif [ "$dns_ip" != "$server_ip" ]; then
        print_warning "DNS for $domain points to $dns_ip (this server is $server_ip)"
        return 1
    else
        print_success "DNS correctly points to $server_ip"
        return 0
    fi
}

check_aapanel_site() {
    local domain=$1
    if [ -d "/www/wwwroot/$domain" ]; then
        print_success "aaPanel site exists: /www/wwwroot/$domain"
        return 0
    else
        print_warning "Site directory not found in aaPanel: /www/wwwroot/$domain"
        print_info "You may want to create the site in aaPanel first"
        return 1
    fi
}

generate_stack_name() {
    local domain=$1
    # Remove TLD and special characters, keep only alphanumeric and dash
    echo "$domain" | sed 's/\.[^.]*$//' | tr '.' '-' | tr -cd '[:alnum:]-'
}

create_traefik_config() {
    local stack_name=$1
    shift
    local domains=("$@")
    local primary_domain="${domains[0]}"

    local config_file="$CONFIG_DIR/${stack_name}.yml"

    # Build domain rules for Traefik
    local domain_rules=""
    for domain in "${domains[@]}"; do
        if [ -z "$domain_rules" ]; then
            domain_rules="Host(\`$domain\`)"
        else
            domain_rules="$domain_rules || Host(\`$domain\`)"
        fi
    done

    print_info "Creating Traefik configuration..." >&2

    cat > "$config_file" << EOF
version: '3.8'

# Auto-generated SSL certificate configuration
# Stack: $stack_name
# Domains: ${domains[*]}
# Generated: $(date)

services:
  ${stack_name}-proxy:
    image: alpine:latest
    command: sleep infinity
    networks:
      - ${TRAEFIK_NETWORK}
    deploy:
      labels:
        # Enable Traefik
        - "traefik.enable=true"

        # HTTP router - will auto-redirect to HTTPS
        - "traefik.http.routers.${stack_name}-http.rule=$domain_rules"
        - "traefik.http.routers.${stack_name}-http.entrypoints=web"
        - "traefik.http.routers.${stack_name}-http.service=${stack_name}-service"

        # HTTPS router - Traefik will get Let's Encrypt certificate automatically
        - "traefik.http.routers.${stack_name}-https.rule=$domain_rules"
        - "traefik.http.routers.${stack_name}-https.entrypoints=websecure"
        - "traefik.http.routers.${stack_name}-https.tls=true"
        - "traefik.http.routers.${stack_name}-https.tls.certresolver=letsencryptresolver"
        - "traefik.http.routers.${stack_name}-https.service=${stack_name}-service"

        # Service - proxy to nginx on port ${NGINX_PORT}
        - "traefik.http.services.${stack_name}-service.loadbalancer.server.url=http://${DOCKER_GATEWAY}:${NGINX_PORT}"
        - "traefik.http.services.${stack_name}-service.loadbalancer.passhostheader=true"

networks:
  ${TRAEFIK_NETWORK}:
    external: true
EOF

    print_success "Configuration created: $config_file" >&2
    echo "$config_file"
}

deploy_stack() {
    local stack_name=$1
    local config_file=$2

    print_info "Deploying stack '$stack_name'..."

    if docker stack deploy -c "$config_file" "$stack_name" 2>&1; then
        print_success "Stack deployed successfully"
        return 0
    else
        print_error "Failed to deploy stack"
        return 1
    fi
}

wait_for_service() {
    local stack_name=$1
    local max_wait=30
    local count=0

    print_info "Waiting for service to start..."

    while [ $count -lt $max_wait ]; do
        if docker service ps "${stack_name}_${stack_name}-proxy" 2>/dev/null | grep -q "Running"; then
            print_success "Service is running"
            return 0
        fi
        sleep 1
        count=$((count + 1))
        echo -ne "\rWaiting... ${count}s"
    done

    echo ""
    print_error "Service did not start within ${max_wait}s"
    return 1
}

verify_certificate() {
    local domain=$1
    local max_wait=60
    local count=0

    print_info "Waiting for SSL certificate (this may take up to ${max_wait}s)..."

    while [ $count -lt $max_wait ]; do
        if timeout 5 openssl s_client -connect "$domain:443" -servername "$domain" </dev/null 2>/dev/null | grep -q "Verify return code: 0"; then
            echo ""
            print_success "SSL certificate successfully obtained!"

            # Get certificate details
            local cert_info=$(echo | openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | openssl x509 -noout -issuer -subject -dates 2>/dev/null)

            echo ""
            print_header "Certificate Details"
            echo "$cert_info" | while IFS= read -r line; do
                echo "  $line"
            done
            echo ""

            return 0
        fi
        sleep 2
        count=$((count + 2))
        echo -ne "\rWaiting for certificate... ${count}s / ${max_wait}s"
    done

    echo ""
    print_warning "Certificate verification timed out"
    print_info "The certificate may still be generating. Check later with:"
    print_info "  echo | openssl s_client -connect $domain:443 2>/dev/null | openssl x509 -noout -dates"
    return 1
}

test_domain() {
    local domain=$1

    print_info "Testing HTTPS access to $domain..."

    if curl -Isk "https://$domain" --max-time 10 2>/dev/null | head -1 | grep -q "200\|301\|302"; then
        print_success "Domain is accessible via HTTPS"
        return 0
    else
        print_warning "Could not verify HTTPS access (may need time to propagate)"
        return 1
    fi
}

remove_stack() {
    local stack_name=$1

    print_info "Removing existing stack '$stack_name'..."

    if docker stack rm "$stack_name" 2>/dev/null; then
        print_success "Stack removed"
        sleep 5  # Wait for cleanup
        return 0
    else
        print_warning "Stack not found or already removed"
        return 1
    fi
}

#########################################################
# Main Script
#########################################################

main() {
    local domains=()
    local stack_name=""
    local custom_name=false
    local verify=false
    local remove_existing=false
    local wait_for_cert=true

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                ;;
            -p|--port)
                NGINX_PORT="$2"
                shift 2
                ;;
            -n|--name)
                stack_name="$2"
                custom_name=true
                shift 2
                ;;
            -v|--verify)
                verify=true
                shift
                ;;
            -r|--remove)
                remove_existing=true
                shift
                ;;
            --no-wait)
                wait_for_cert=false
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                echo "Use -h or --help for usage information"
                exit 1
                ;;
            *)
                domains+=("$1")
                shift
                ;;
        esac
    done

    # Check if domains provided
    if [ ${#domains[@]} -eq 0 ]; then
        print_error "No domains provided"
        echo ""
        echo "Usage: $0 [OPTIONS] DOMAIN [DOMAIN2 ...]"
        echo "Use -h or --help for more information"
        exit 1
    fi

    # Validate domains
    print_header "Validating Domains"
    local valid_domains=()
    for domain in "${domains[@]}"; do
        if validate_domain "$domain"; then
            print_success "Valid: $domain"
            valid_domains+=("$domain")
        else
            print_error "Invalid domain format: $domain"
            exit 1
        fi
    done
    echo ""

    # Generate stack name if not provided
    if [ "$custom_name" = false ]; then
        stack_name=$(generate_stack_name "${valid_domains[0]}")
        print_info "Auto-generated stack name: $stack_name"
        echo ""
    fi

    # Check prerequisites
    check_prerequisites

    # Check DNS for all domains
    print_header "Checking DNS Resolution"
    for domain in "${valid_domains[@]}"; do
        check_dns "$domain"
    done
    echo ""

    # Check aaPanel sites
    print_header "Checking aaPanel Sites"
    for domain in "${valid_domains[@]}"; do
        check_aapanel_site "$domain"
    done
    echo ""

    # Remove existing stack if requested
    if [ "$remove_existing" = true ]; then
        remove_stack "$stack_name"
    fi

    # Create configuration
    print_header "Generating Configuration"
    config_file=$(create_traefik_config "$stack_name" "${valid_domains[@]}")
    echo ""

    # Deploy stack
    print_header "Deploying to Traefik"
    if ! deploy_stack "$stack_name" "$config_file"; then
        print_error "Deployment failed"
        exit 1
    fi
    echo ""

    # Wait for service
    if ! wait_for_service "$stack_name"; then
        print_error "Service failed to start"
        exit 1
    fi
    echo ""

    # Wait and verify certificate
    if [ "$wait_for_cert" = true ]; then
        print_header "Certificate Verification"
        sleep 5  # Give Traefik a moment to start certificate request

        if verify_certificate "${valid_domains[0]}"; then
            # Test all domains
            echo ""
            print_header "Testing Domains"
            for domain in "${valid_domains[@]}"; do
                test_domain "$domain"
            done
        fi
        echo ""
    fi

    # Summary
    print_header "Deployment Summary"
    echo -e "${CYAN}Stack Name:${NC}     $stack_name"
    echo -e "${CYAN}Domains:${NC}        ${valid_domains[*]}"
    echo -e "${CYAN}Config File:${NC}    $config_file"
    echo -e "${CYAN}Nginx Port:${NC}     $NGINX_PORT"
    echo ""

    print_header "Useful Commands"
    echo "  # Check service status"
    echo "  docker service ps ${stack_name}_${stack_name}-proxy"
    echo ""
    echo "  # View service logs"
    echo "  docker service logs -f ${stack_name}_${stack_name}-proxy"
    echo ""
    echo "  # Check certificate"
    echo "  echo | openssl s_client -connect ${valid_domains[0]}:443 2>/dev/null | openssl x509 -noout -dates"
    echo ""
    echo "  # Remove stack"
    echo "  docker stack rm $stack_name"
    echo ""
    echo "  # Test HTTPS"
    echo "  curl -I https://${valid_domains[0]}"
    echo ""

    print_success "SSL certificate generation complete!"
    print_info "Access your site(s) at:"
    for domain in "${valid_domains[@]}"; do
        echo "  https://$domain"
    done
    echo ""
}

# Run main function
main "$@"
