#!/usr/bin/env bash
set -euo pipefail

LOG_TAG="[HAPROXY-DEPLOY]"

echo "$LOG_TAG Starting HAProxy deployment on VM"

#-----------------------------------------------------------
# Arguments:
#   $1 = Base config URL (haproxy.cfg)          [optional]
#   $2 = Env-specific config URL (haproxy.cfg.<env>) [optional]
#
# Usage patterns:
#   1) Single full config:
#        deploy-haproxy.sh "https://.../haproxy.cfg.dev"
#   2) Base + env override:
#        deploy-haproxy.sh "https://.../haproxy.cfg" "https://.../haproxy.cfg.dev"
#-----------------------------------------------------------

BASE_CFG_URL="${1:-}"
ENV_CFG_URL="${2:-}"

if [[ -z "$BASE_CFG_URL" && -z "$ENV_CFG_URL" ]]; then
  echo "$LOG_TAG ERROR: No config URL provided."
  echo "$LOG_TAG Usage:"
  echo "  $0 <fullConfigUrl>"
  echo "  $0 <baseConfigUrl> <envConfigUrl>"
  exit 1
fi

#-----------------------------------------------------------
# 1. Ensure HAProxy is installed
#-----------------------------------------------------------
if ! command -v haproxy >/dev/null 2>&1; then
  echo "$LOG_TAG HAProxy not found. Installing..."
  sudo apt-get update -y
  sudo apt-get install -y haproxy
else
  echo "$LOG_TAG HAProxy already installed. Skipping install."
fi

#-----------------------------------------------------------
# 2. Download config file(s) to temp
#-----------------------------------------------------------
TMP_DIR="/tmp/haproxy-deploy"
mkdir -p "$TMP_DIR"

TMP_BASE_CFG="$TMP_DIR/haproxy.base.cfg"
TMP_ENV_CFG="$TMP_DIR/haproxy.env.cfg"
TMP_MERGED_CFG="$TMP_DIR/haproxy.merged.cfg"

if [[ -n "$BASE_CFG_URL" && -n "$ENV_CFG_URL" ]]; then
  echo "$LOG_TAG Mode: Base + Env override"
  echo "$LOG_TAG Downloading base config: $BASE_CFG_URL"
  curl -sSL "$BASE_CFG_URL" -o "$TMP_BASE_CFG"

  echo "$LOG_TAG Downloading env config:  $ENV_CFG_URL"
  curl -sSL "$ENV_CFG_URL" -o "$TMP_ENV_CFG"

  echo "$LOG_TAG Merging base + env config into $TMP_MERGED_CFG"
  cat "$TMP_BASE_CFG" >  "$TMP_MERGED_CFG"
  echo ""              >> "$TMP_MERGED_CFG"
  cat "$TMP_ENV_CFG"   >> "$TMP_MERGED_CFG"

else
  # Single full config file
  CFG_URL="${BASE_CFG_URL:-$ENV_CFG_URL}"
  echo "$LOG_TAG Mode: Single full config"
  echo "$LOG_TAG Downloading config: $CFG_URL"
  curl -sSL "$CFG_URL" -o "$TMP_MERGED_CFG"
fi

#-----------------------------------------------------------
# 3. Validate new config BEFORE touching live config
#-----------------------------------------------------------
echo "$LOG_TAG Validating new HAProxy config..."
if ! sudo haproxy -c -f "$TMP_MERGED_CFG"; then
  echo "$LOG_TAG ERROR: New HAProxy config failed validation."
  echo "$LOG_TAG Keeping existing config in place."
  exit 1
fi
echo "$LOG_TAG Validation succeeded."

#-----------------------------------------------------------
# 4. Backup existing config (if present)
#-----------------------------------------------------------
LIVE_CFG="/etc/haproxy/haproxy.cfg"

if [[ -f "$LIVE_CFG" ]]; then
  BACKUP_CFG="/etc/haproxy/haproxy.cfg.$(date +%Y%m%d%H%M%S).bak"
  echo "$LOG_TAG Backing up existing config to $BACKUP_CFG"
  sudo cp "$LIVE_CFG" "$BACKUP_CFG"
else
  echo "$LOG_TAG No existing config at $LIVE_CFG (first deployment)."
fi

#-----------------------------------------------------------
# 5. Replace live config with merged config
#-----------------------------------------------------------
echo "$LOG_TAG Applying new config to $LIVE_CFG"
sudo mkdir -p "$(dirname "$LIVE_CFG")"
sudo mv "$TMP_MERGED_CFG" "$LIVE_CFG"
sudo chown root:root "$LIVE_CFG"
sudo chmod 644 "$LIVE_CFG"

#-----------------------------------------------------------
# 6. Enable & reload HAProxy
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

echo "$LOG_TAG Deployment completed successfully."
