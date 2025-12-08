#!/bin/bash

#########################################################
# Standalone Nginx Installation for aaPanel
# Downloads and compiles nginx in aaPanel's expected location
#########################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Standalone Nginx Installation${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Configuration
NGINX_VERSION="1.26.2"
OPENSSL_VERSION="1.1.1w"
PCRE_VERSION="8.45"
ZLIB_VERSION="1.3.1"
INSTALL_PATH="/www/server/nginx"
SRC_PATH="/www/server/nginx/src"

echo -e "${YELLOW}This script will install nginx ${NGINX_VERSION} for aaPanel${NC}"
echo -e "${YELLOW}Installation path: ${INSTALL_PATH}${NC}"
echo ""
read -p "Continue? (y/n): " answer
if [ "$answer" != "y" ]; then
    echo "Installation cancelled"
    exit 0
fi

# Install dependencies
echo -e "${GREEN}Step 1: Installing build dependencies...${NC}"
apt-get update
apt-get install -y build-essential libgd-dev libgeoip-dev libxml2-dev libxslt1-dev

# Create directories
echo -e "${GREEN}Step 2: Creating directories...${NC}"
mkdir -p ${SRC_PATH}
mkdir -p ${INSTALL_PATH}/{conf,logs,temp,vhost}
mkdir -p /www/server/panel/vhost/nginx

# Download sources
echo -e "${GREEN}Step 3: Downloading nginx and dependencies...${NC}"
cd ${SRC_PATH}

if [ ! -f "nginx-${NGINX_VERSION}.tar.gz" ]; then
    wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
fi

if [ ! -f "openssl-${OPENSSL_VERSION}.tar.gz" ]; then
    wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
fi

if [ ! -f "pcre-${PCRE_VERSION}.tar.gz" ]; then
    wget https://sourceforge.net/projects/pcre/files/pcre/${PCRE_VERSION}/pcre-${PCRE_VERSION}.tar.gz
fi

if [ ! -f "zlib-${ZLIB_VERSION}.tar.gz" ]; then
    wget http://zlib.net/zlib-${ZLIB_VERSION}.tar.gz
fi

# Extract
echo -e "${GREEN}Step 4: Extracting sources...${NC}"
tar -xzf nginx-${NGINX_VERSION}.tar.gz
tar -xzf openssl-${OPENSSL_VERSION}.tar.gz
tar -xzf pcre-${PCRE_VERSION}.tar.gz
tar -xzf zlib-${ZLIB_VERSION}.tar.gz

# Compile nginx
echo -e "${GREEN}Step 5: Compiling nginx (this may take several minutes)...${NC}"
cd nginx-${NGINX_VERSION}

./configure \
    --prefix=${INSTALL_PATH} \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_stub_status_module \
    --with-http_auth_request_module \
    --with-http_xslt_module \
    --with-http_image_filter_module \
    --with-http_geoip_module \
    --with-threads \
    --with-stream \
    --with-stream_ssl_module \
    --with-http_slice_module \
    --with-file-aio \
    --with-openssl=${SRC_PATH}/openssl-${OPENSSL_VERSION} \
    --with-pcre=${SRC_PATH}/pcre-${PCRE_VERSION} \
    --with-zlib=${SRC_PATH}/zlib-${ZLIB_VERSION} \
    --with-ld-opt="-Wl,-rpath,/usr/local/lib"

make -j$(nproc)
make install

# Create init.d script
echo -e "${GREEN}Step 6: Creating init.d script...${NC}"
cat > /etc/init.d/nginx << 'EOF'
#!/bin/bash
# chkconfig: 2345 55 25
# Description: Nginx init.d script

### BEGIN INIT INFO
# Provides:          nginx
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts the nginx web server
# Description:       starts nginx using start-stop-daemon
### END INIT INFO

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=/www/server/nginx/sbin/nginx
NAME=nginx
DESC=nginx
PID=/www/server/nginx/logs/nginx.pid

test -x $DAEMON || exit 0

set -e

case "$1" in
    start)
        echo -n "Starting $DESC: "
        $DAEMON
        echo "$NAME."
        ;;
    stop)
        echo -n "Stopping $DESC: "
        if [ -f $PID ]; then
            kill -QUIT $(cat $PID)
        fi
        echo "$NAME."
        ;;
    reload)
        echo -n "Reloading $DESC configuration: "
        if [ -f $PID ]; then
            kill -HUP $(cat $PID)
        fi
        echo "$NAME."
        ;;
    restart)
        echo -n "Restarting $DESC: "
        if [ -f $PID ]; then
            kill -QUIT $(cat $PID)
            sleep 1
        fi
        $DAEMON
        echo "$NAME."
        ;;
    test)
        $DAEMON -t
        ;;
    status)
        if [ -f $PID ]; then
            if ps -p $(cat $PID) > /dev/null 2>&1; then
                echo "$NAME is running"
            else
                echo "$NAME is not running (stale PID file)"
            fi
        else
            echo "$NAME is not running"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|reload|test|status}" >&2
        exit 1
        ;;
esac

exit 0
EOF

chmod +x /etc/init.d/nginx

# Create basic nginx.conf
echo -e "${GREEN}Step 7: Creating basic nginx configuration...${NC}"
cat > ${INSTALL_PATH}/conf/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
error_log /www/server/nginx/logs/error.log;
pid /www/server/nginx/logs/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /www/server/nginx/logs/access.log  main;

    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;
    keepalive_timeout  65;
    types_hash_max_size 2048;

    gzip  on;
    gzip_vary on;
    gzip_min_length 1000;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;

    server_names_hash_bucket_size 128;
    client_header_buffer_size 32k;
    large_client_header_buffers 4 32k;
    client_max_body_size 50m;

    # Default server
    server {
        listen       80;
        server_name  _;
        root         /www/wwwroot/default;
        index        index.html index.htm index.php;

        location / {
            try_files $uri $uri/ =404;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }

    # Include virtual hosts
    include /www/server/panel/vhost/nginx/*.conf;
}
EOF

# Create default web root
mkdir -p /www/wwwroot/default
cat > /www/wwwroot/default/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to Nginx on aaPanel</title>
</head>
<body>
    <h1>Nginx is working!</h1>
    <p>This is the default page. Configure your sites through aaPanel.</p>
</body>
</html>
EOF

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Nginx Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Nginx has been installed to: ${INSTALL_PATH}"
echo "Version: ${NGINX_VERSION}"
echo ""
echo "Next step: Run the custom port configuration script:"
echo "  sudo /root/aaPanel-nginx-fix/aaPanel-nginx-custom-ports.sh"
echo ""
