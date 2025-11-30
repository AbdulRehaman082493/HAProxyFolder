#!/usr/bin/env bash
set -euo pipefail

LOG_TAG="[HAPROXY-DEPLOY]"

echo "$LOG_TAG Starting HAProxy deployment on VM"

#-----------------------------------------------------------
# Arguments (MSI / Storage mode):
#   $1 = storage account name          (e.g. sthaproxyshared)
#   $2 = container name                (e.g. haproxy)
#   $3 = base config blob name         (haproxy.cfg OR haproxy.cfg.dev)
#   $4 = env-specific config blob name (haproxy.cfg.dev) [optional]
#
# Usage patterns:
#   1) Single full config:
#        deploy-haproxy.sh sthaproxyshared haproxy haproxy.cfg.dev
#
#   2) Base + env override:
#        deploy-haproxy.sh sthaproxyshared haproxy haproxy.cfg haproxy.cfg.dev
#-----------------------------------------------------------

if [[ $# -lt 3 ]]; then
  echo "$LOG_TAG ERROR: Not enough arguments."
  echo "$LOG_TAG Usage:"
  echo "  $0 <accountName> <containerName> <fullConfigBlob>"
  echo "  $0 <accountName> <containerName> <baseConfigBlob> <envConfigBlob>"
  exit 1
fi

ACCOUNT_NAME="$1"
CONTAINER_NAME="$2"
BASE_BLOB="$3"
ENV_BLOB="${4:-}"

#-----------------------------------------------------------
# 0. Login using managed identity
#-----------------------------------------------------------
echo "$LOG_TAG Logging in with managed identity..."
az login --identity --allow-no-subscriptions >/dev/null

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
# 2. Download config blob(s) to temp
#-----------------------------------------------------------
TMP_DIR="/tmp/haproxy-deploy"
mkdir -p "$TMP_DIR"

TMP_BASE_CFG="$TMP_DIR/haproxy.base.cfg"
TMP_ENV_CFG="$TMP_DIR/haproxy.env.cfg"
TMP_MERGED_CFG="$TMP_DIR/haproxy.merged.cfg"

download_blob() {
  local blob_name="$1"
  local dest_file="$2"

  echo "$LOG_TAG Downloading blob '$blob_name' from $ACCOUNT_NAME/$CONTAINER_NAME -> $dest_file"
  az storage blob download \
    --account-name "$ACCOUNT_NAME" \
    --container-name "$CONTAINER_NAME" \
    --name "$blob_name" \
    --file "$dest_file" \
    --auth-mode login \
    --output none
}

if [[ -n "$ENV_BLOB" ]]; then
  echo "$LOG_TAG Mode: Base + Env override"

  download_blob "$BASE_BLOB" "$TMP_BASE_CFG"
  download_blob "$ENV_BLOB"  "$TMP_ENV_CFG"

  echo "$LOG_TAG Merging base + env config into $TMP_MERGED_CFG"
  cat "$TMP_BASE_CFG" >  "$TMP_MERGED_CFG"
  echo ""              >> "$TMP_MERGED_CFG"
  cat "$TMP_ENV_CFG"   >> "$TMP_MERGED_CFG"
else
  echo "$LOG_TAG Mode: Single full config"
  download_blob "$BASE_BLOB" "$TMP_MERGED_CFG"
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
