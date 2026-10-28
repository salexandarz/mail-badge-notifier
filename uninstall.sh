#!/usr/bin/env bash
# Mail Badge Bridge User-Space Uninstaller (XDG Compliant)
set -euo pipefail

TARGET_DIR="$HOME/.local/share/mail-badge-notifier"
BIN_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"
APPLICATIONS_DIR="$HOME/.local/share/applications"

DESKTOP_FILE="org.mozilla.Thunderbird.desktop"
APP_NAME="thunderbird"
SYS_BINARY="/usr/bin/thunderbird"

case "${1:-}" in
  ""|--thunderbird)
    DESKTOP_FILE="org.mozilla.Thunderbird.desktop"
    APP_NAME="thunderbird"
    SYS_BINARY="/usr/bin/thunderbird"
    ;;
  --betterbird)
    DESKTOP_FILE="eu.betterbird.Betterbird.desktop"
    APP_NAME="betterbird"
    SYS_BINARY="/usr/bin/betterbird"
    ;;
  --desktop-file)
    DESKTOP_FILE="${2:?--desktop-file needs a name, e.g. org.mozilla.Thunderbird.desktop}"
    APP_NAME="$(echo "$DESKTOP_FILE" | cut -d'.' -f1 | tr '[:upper:]' '[:lower:]')"
    SYS_BINARY="/usr/bin/$APP_NAME"
    ;;
  -h|--help)
    echo "Usage: ./uninstall.sh [--thunderbird | --betterbird | --desktop-file NAME]"
    exit 0
    ;;
  *) echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
esac

echo "=================================================="
echo " Uninstalling Mail Badge Bridge for: $APP_NAME"
echo "=================================================="

# 1. Stop and disable systemd user service (if present)
if systemctl --user --quiet is-active "$APP_NAME.service" 2>/dev/null; then
  echo "==> Stopping systemd service: $APP_NAME.service..."
  systemctl --user stop "$APP_NAME.service" 2>/dev/null || true
fi

if systemctl --user --quiet is-enabled "$APP_NAME.service" 2>/dev/null; then
  echo "==> Disabling systemd service: $APP_NAME.service..."
  systemctl --user disable "$APP_NAME.service" 2>/dev/null || true
fi

SERVICE_FILE="$SYSTEMD_DIR/$APP_NAME.service"
if [[ -f "$SERVICE_FILE" ]]; then
  rm -f "$SERVICE_FILE"
  echo "==> Removed service file: $SERVICE_FILE"
  systemctl --user daemon-reload 2>/dev/null || true
fi

# 2. Kill remaining headless processes for this client
pkill -f "$SYS_BINARY --headless" 2>/dev/null || true

# 3. Remove wrapper script and helper symlink from BIN_DIR
if [[ -f "$BIN_DIR/$APP_NAME" ]]; then
  rm -f "$BIN_DIR/$APP_NAME"
  echo "==> Removed wrapper script: $BIN_DIR/$APP_NAME"
fi

if [[ -L "$BIN_DIR/mail-badge-bridge" || -f "$BIN_DIR/mail-badge-bridge" ]]; then
  rm -f "$BIN_DIR/mail-badge-bridge"
  echo "==> Removed bridge binary/symlink: $BIN_DIR/mail-badge-bridge"
fi

# 4. Remove local desktop file and update desktop database
LOCAL_DESKTOP="$APPLICATIONS_DIR/$DESKTOP_FILE"
if [[ -f "$LOCAL_DESKTOP" ]]; then
  rm -f "$LOCAL_DESKTOP"
  echo "==> Removed local desktop file: $LOCAL_DESKTOP"
  if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$APPLICATIONS_DIR" &> /dev/null || true
  fi
fi

# 5. Remove Native Messaging Manifests
for dir in "$HOME/.mozilla/native-messaging-hosts" \
         "${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/native-messaging-hosts"; do
  MANIFEST_FILE="$dir/mail_badge_bridge.json"
  if [[ -f "$MANIFEST_FILE" ]]; then
    rm -f "$MANIFEST_FILE"
    echo "==> Removed native messaging manifest: $MANIFEST_FILE"
  fi
done

# 6. Remove XDG data target directory
if [[ -d "$TARGET_DIR" ]]; then
  rm -rf "$TARGET_DIR"
  echo "==> Removed target XDG data directory: $TARGET_DIR"
fi

# Clean up any local compiled .xpi file if present in working directory
if [[ -f "mail-badge-bridge.xpi" ]]; then
  rm -f "mail-badge-bridge.xpi"
fi

echo "=================================================="
echo " Uninstallation completed successfully!"
echo "=================================================="
