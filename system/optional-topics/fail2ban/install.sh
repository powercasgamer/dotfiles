#!/bin/bash

# Fail2Ban Installation Script (Smart Service Detection)
# Creates jails only for installed services with optional components

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root or with sudo"
    exit 1
fi

# Configuration parameters (customizable)
MAX_RETRY=3
BAN_TIME="1h"
FIND_TIME="10m"
IGNORE_IP="127.0.0.1/8 ::1"

# Install Fail2Ban
echo "🔧 Installing Fail2Ban..."
if command -v apt &> /dev/null; then
    apt update && apt install -y fail2ban
elif command -v yum &> /dev/null; then
    yum install -y epel-release && yum install -y fail2ban
elif command -v dnf &> /dev/null; then
    dnf install -y fail2ban
else
    echo "❌ Unsupported package manager. Install Fail2Ban manually first."
    exit 1
fi

# Config directory
JAIL_DIR="/etc/fail2ban/jail.d"
mkdir -p "$JAIL_DIR"

# Function to add a jail
add_jail() {
    local service="$1"
    local filter="$2"
    local logpath="$3"
    local port="$4"

    echo "🛡️  Configuring Fail2Ban for $service"
    cat > "$JAIL_DIR/${service}.local" <<EOL
[$service]
enabled = true
port = $port
filter = $filter
logpath = $logpath
maxretry = $MAX_RETRY
bantime = $BAN_TIME
findtime = $FIND_TIME
ignoreip = $IGNORE_IP
EOL
}

### SSH (Default) ###
if [ -f "/var/log/auth.log" ] || [ -f "/var/log/secure" ]; then
    LOGPATH="/var/log/auth.log"
    [ -f "/var/log/secure" ] && LOGPATH="/var/log/secure"
    add_jail "sshd" "sshd" "$LOGPATH" "ssh"
fi

### Caddy ###
if command -v caddy &> /dev/null && { [ -f "/var/log/caddy/access.log" ] || [ -f "/var/log/caddy/global-access.log" ]; }; then
    LOGPATH="/var/log/caddy/access.log"
    [ -f "/var/log/caddy/global-access.log" ] && LOGPATH="/var/log/caddy/global-access.log"
    add_jail "caddy" "caddy" "$LOGPATH" "http,https"
fi

### phpMyAdmin ###
if [ -d "/usr/share/phpmyadmin" ] || [ -d "/var/www/html/phpmyadmin" ]; then
    # Try to find the most appropriate log file
    PMA_LOGS=(
        "/var/log/phpmyadmin/error.log"
        "/var/log/nginx/phpmyadmin_error.log"
        "/var/log/apache2/phpmyadmin_error.log"
        "/var/log/httpd/phpmyadmin_error.log"
    )

    for log in "${PMA_LOGS[@]}"; do
        if [ -f "$log" ]; then
            add_jail "phpmyadmin" "phpmyadmin" "$log" "http,https"
            break
        fi
    done

    # Fallback to syslog if no specific log found
    if [ ! -f "$JAIL_DIR/phpmyadmin.local" ]; then
        add_jail "phpmyadmin" "phpmyadmin" "/var/log/syslog" "http,https"
    fi
fi

### Nginx (Optional) ###
if command -v nginx &> /dev/null; then
    NGINX_LOGS=(
        "/var/log/nginx/error.log"
        "/var/log/nginx/access.log"
    )

    for log in "${NGINX_LOGS[@]}"; do
        if [ -f "$log" ]; then
            add_jail "nginx-http-auth" "nginx-http-auth" "$log" "http,https"
            break
        fi
    done
fi

### MySQL/MariaDB (Optional) ###
if command -v mysqld &> /dev/null || command -v mariadbd &> /dev/null; then
    MYSQL_LOGS=(
        "/var/log/mysql/error.log"
        "/var/log/mysql.log"
        "/var/log/mysqld.log"
        "/var/log/mariadb/mariadb.log"
    )

    for log in "${MYSQL_LOGS[@]}"; do
        if [ -f "$log" ]; then
            add_jail "mysqld-auth" "mysqld-auth" "$log" "3306"
            break
        fi
    done
fi

### Redis (Optional) ###
if command -v redis-server &> /dev/null && [ -f "/var/log/redis/redis.log" ]; then
    add_jail "redis" "redis" "/var/log/redis/redis.log" "6379"
fi

### MongoDB (Optional) ###
if command -v mongod &> /dev/null; then
    MONGO_LOGS=(
        "/var/log/mongodb/mongod.log"
        "/var/log/mongo.log"
    )

    for log in "${MONGO_LOGS[@]}"; do
        if [ -f "$log" ]; then
            add_jail "mongodb-auth" "mongodb-auth" "$log" "27017"
            break
        fi
    done
fi

### Pterodactyl Panel (Optional) ###
PANEL_PATHS=("/var/www/pterodactyl" "/var/www/pelican")
for path in "${PANEL_PATHS[@]}"; do
    if [ -d "$path" ]; then
        LOGPATH="$path/storage/logs/laravel-$(date +'%Y-%m-%d').log"
        [ -f "$LOGPATH" ] || LOGPATH="$path/storage/logs/laravel.log"
        add_jail "pterodactyl" "pterodactyl" "$LOGPATH" "http,https"
        break
    fi
done

# Enable & Restart Fail2Ban
echo "🔄 Starting Fail2Ban..."
systemctl enable --now fail2ban
systemctl restart fail2ban

# Status Check
echo ""
echo "✅ Done!"
echo "📋 Active jails:"
fail2ban-client status | grep "Jail list:" | sed 's/.*Jail list://g' | tr -s ',' '\n' | sed 's/ //g' | grep -v '^$'