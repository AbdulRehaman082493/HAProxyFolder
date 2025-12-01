#!/usr/bin/env bash
set -euo pipefail

LOG_TAG="[HAPROXY-INSTALL]"

echo "$LOG_TAG Starting HAProxy install/update"

# The config file name is passed as an argument (e.g. haproxy.cfg.dev)
CFG_FILE="${1:-haproxy.cfg}"

if [[ ! -f "$CFG_FILE" ]]; then
  echo "$LOG_TAG ERROR: Config file '$CFG_FILE' not found in current directory."
  exit 1
fi

#-----------------------------------------------------------
# 1. Install HAProxy if missing
#-----------------------------------------------------------
if ! command -v haproxy >/dev/null 2>&1; then
  echo "$LOG_TAG HAProxy not found. Installing..."
  sudo apt-get update -y
  sudo apt-get install -y haproxy
else
  echo "$LOG_TAG HAProxy already installed. Skipping install."
fi

#-----------------------------------------------------------
# 2. Validate new config
#-----------------------------------------------------------
TMP_CFG="/tmp/haproxy.cfg.new"
cp "$CFG_FILE" "$TMP_CFG"

echo "$LOG_TAG Validating HAProxy config from $CFG_FILE"
if ! sudo haproxy -c -f "$TMP_CFG"; then
  echo "$LOG_TAG ERROR: New HAProxy config failed validation."
  exit 1
fi
echo "$LOG_TAG Validation succeeded."

#-----------------------------------------------------------
# 3. Backup existing config
#-----------------------------------------------------------
LIVE_CFG="/etc/haproxy/haproxy.cfg"

if [[ -f "$LIVE_CFG" ]]; then
  BACKUP_CFG="/etc/haproxy/haproxy.cfg.$(date +%Y%m%d%H%M%S).bak"
  echo "$LOG_TAG Backing up existing config to $BACKUP_CFG"
  sudo cp "$LIVE_CFG" "$BACKUP_CFG"
else
  echo "$LOG_TAG No existing /etc/haproxy/haproxy.cfg (first deploy)."
fi

#-----------------------------------------------------------
# 4. Apply new config
#-----------------------------------------------------------
echo "$LOG_TAG Applying new config to $LIVE_CFG"
sudo mkdir -p "$(dirname "$LIVE_CFG")"
sudo mv "$TMP_CFG" "$LIVE_CFG"
sudo chown root:root "$LIVE_CFG"
sudo chmod 644 "$LIVE_CFG"

#-----------------------------------------------------------
# 5. Enable & reload HAProxy
#-----------------------------------------------------------
echo "$LOG_TAG Enabling HAProxy service"
sudo systemctl enable haproxy || true

echo "$LOG_TAG Reloading HAProxy"
if ! sudo systemctl reload haproxy; then
  echo "$LOG_TAG Reload failed, trying restart..."
  sudo systemctl restart haproxy
fi

echo "$LOG_TAG HAProxy status:"
sudo systemctl status haproxy --no-pager || true

echo "$LOG_TAG Completed successfully."
