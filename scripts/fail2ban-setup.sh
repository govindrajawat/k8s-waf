#!/bin/bash
set -e

# Create jail.local for NGINX
cat <<EOF >/etc/fail2ban/jail.local
[nginx-http-auth]
enabled = true
port    = http,https
filter  = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 5
bantime = 3600
EOF

# Restart Fail2Ban
echo "Restarting Fail2Ban..."
service fail2ban restart || true 