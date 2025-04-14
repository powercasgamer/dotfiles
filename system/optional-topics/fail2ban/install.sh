#!/bin/bash

# Fail2Ban Installation Script (Smart Service Detection)
# Creates jails only for installed services (Caddy, phpMyAdmin, SSH, Pterodactyl/Pelican)

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root or with sudo"
    exit 1
fi

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
maxretry = 3
bantime = 1h
findtime = 10m
ignoreip = 127.0.0.1/8 ::1
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
    add_jail "phpmyadmin" "phpmyadmin" "/var/log/phpmyadmin/error.log" "http,https"
fi

### Pterodactyl Panel  ###
#if [ -d "/var/www/pterodactyl" ] || [ -d "/var/www/pelican" ]; then
#    LOGPATH="/var/www/pterodactyl/storage/logs/laravel-*.log"
#    [ -d "/var/www/pelican" ] && LOGPATH="/var/www/pelican/storage/logs/laravel-*.log"
#    add_jail "pterodactyl" "pterodactyl" "$LOGPATH" "http,https"
#fi

# Enable & Restart Fail2Ban
echo "🔄 Starting Fail2Ban..."
systemctl enable --now fail2ban
fail2ban-client reload

# Status Check
echo ""
echo "✅ Done!"
echo "📋 Active jails:"
fail2ban-client status | grep "Jail list:" | sed 's/.*Jail list://g' | tr -s ',' '\n' | sed 's/ //g' | grep -v '^$'