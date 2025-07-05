#!/bin/bash
set -e

# Start Fail2Ban if present
if [ -x /usr/bin/fail2ban-server ]; then
  echo "Starting Fail2Ban..."
  service fail2ban start || true
fi

# Start Wazuh agent if present
if [ -x /usr/bin/wazuh-agent ]; then
  echo "Starting Wazuh agent..."
  service wazuh-agent start || true
fi

# Start NGINX
exec nginx -g 'daemon off;' 