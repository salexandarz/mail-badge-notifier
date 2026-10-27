#!/usr/bin/env bash
# Mail Badge Bridge User-Space Installer (XDG Compliant)
set -euo pipefail

TARGET_DIR="$HOME/.local/share/mail-badge-notifier"
BIN_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"
APPLICATIONS_DIR="$HOME/.local/share/applications"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$SCRIPT_DIR" != "$TARGET_DIR" ]]; then
  echo "==> Syncing project files to XDG data directory: $TARGET_DIR..."
  mkdir -p "$TARGET_DIR"
  if command -v rsync &> /dev/null; then
    rsync -av --exclude='.git' --exclude='install.sh' --exclude='uninstall.sh' "$SCRIPT_DIR/" "$TARGET_DIR/"
  else
    cp -r "$SCRIPT_DIR"/* "$TARGET_DIR/" 2>/dev/null || true
  fi
  chmod -R u+rwX "$TARGET_DIR"
  cd "$TARGET_DIR"
else
  cd "$SCRIPT_DIR"
fi

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
  -h|--help) sed -n 2,12p "$0"; exit 0 ;;
  *) echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
esac

echo "=================================================="
echo " Installing Mail Badge Bridge for: $APP_NAME"
echo "=================================================="

# 1. Create GUI Wrapper script in ~/.local/bin/ first
WRAPPER="$BIN_DIR/$APP_NAME"
mkdir -p "$BIN_DIR"

cat << 'EOF_WRAPPER' > "$WRAPPER"
#!/usr/bin/env bash
systemctl --user stop APP_NAME_PLACEHOLDER.service 2>/dev/null
pkill -f "SYS_BINARY_PLACEHOLDER --headless" 2>/dev/null
sleep 1
SYS_BINARY_PLACEHOLDER "$@"
systemctl --user start APP_NAME_PLACEHOLDER.service 2>/dev/null
EOF_WRAPPER

sed -i "s|APP_NAME_PLACEHOLDER|$APP_NAME|g" "$WRAPPER"
sed -i "s|SYS_BINARY_PLACEHOLDER|$SYS_BINARY|g" "$WRAPPER"
chmod +x "$WRAPPER"

# 2. Find system desktop file, copy locally with its proper name, and update ALL Exec lines
found=""
for d in "/usr/share/applications" "/usr/local/share/applications" "$APPLICATIONS_DIR"; do
  if [[ -f "$d/$DESKTOP_FILE" ]]; then
    found="$d/$DESKTOP_FILE"
    break
  fi
done

if [[ -z "$found" ]]; then
  found=$(find /usr/share/applications -maxdepth 1 -iname "*${APP_NAME}*.desktop" | head -n 1)
  if [[ -n "$found" ]]; then
    DESKTOP_FILE="$(basename "$found")"
  fi
fi

mkdir -p "$APPLICATIONS_DIR"
LOCAL_DESKTOP="$APPLICATIONS_DIR/$DESKTOP_FILE"

if [[ -n "$found" && -f "$found" ]]; then
  cp "$found" "$LOCAL_DESKTOP"
  # Replace ALL Exec= lines (main entry and actions like ComposeMessage, OpenAddressBook) with wrapper + %u
  sed -i "s#^Exec=.*#Exec=$WRAPPER %u#g" "$LOCAL_DESKTOP"
  if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$APPLICATIONS_DIR" &> /dev/null || true
  fi
  echo "==> Copied and updated desktop file: $LOCAL_DESKTOP"
else
  echo "Error: $DESKTOP_FILE not found in the system." >&2
  exit 1
fi

# 3. Install Python Native Helper into TARGET_DIR and symlink to BIN_DIR
HELPER_SRC=""
if [[ -f "helper/mail_badge_bridge.py" ]]; then
  HELPER_SRC="helper/mail_badge_bridge.py"
elif [[ -f "mail_badge_bridge.py" ]]; then
  HELPER_SRC="mail_badge_bridge.py"
fi

if [[ -n "$HELPER_SRC" ]]; then
  sed "s|^APP_URI = .*|APP_URI = \"application://$DESKTOP_FILE\"|" \
    "$HELPER_SRC" > "$TARGET_DIR/mail_badge_bridge.py"
  chmod 755 "$TARGET_DIR/mail_badge_bridge.py"
  ln -sf "$TARGET_DIR/mail_badge_bridge.py" "$BIN_DIR/mail-badge-bridge"
else
  echo "Error: mail_badge_bridge.py helper not found!" >&2
  exit 1
fi

# 4. Create and start systemd user service for Headless background mode
mkdir -p "$SYSTEMD_DIR"
SERVICE_FILE="$SYSTEMD_DIR/$APP_NAME.service"

cat << 'EOF_SERVICE' > "$SERVICE_FILE"
[Unit]
Description=APP_NAME_CAP Headless Background Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=SYS_BINARY_PLACEHOLDER --headless -no-remote
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF_SERVICE

sed -i "s|APP_NAME_CAP|${APP_NAME^}|g" "$SERVICE_FILE"
sed -i "s|SYS_BINARY_PLACEHOLDER|$SYS_BINARY|g" "$SERVICE_FILE"

systemctl --user daemon-reload
systemctl --user enable --now "$APP_NAME.service" 2>/dev/null || true

# 5. Set up Native Messaging Manifest for Thunderbird/Firefox
MANIFEST=$(cat << 'EOF_MANIFEST'
{
  "name": "mail_badge_bridge",
  "description": "Mail Badge Bridge helper",
  "path": "BIN_PATH",
  "type": "stdio",
  "allowed_extensions": ["mail-badge-bridge@celest-watches.com"]
}
EOF_MANIFEST
)
MANIFEST="${MANIFEST//BIN_PATH/$BIN_DIR/mail-badge-bridge}"

for dir in "$HOME/.mozilla/native-messaging-hosts" \
         "${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/native-messaging-hosts"; do
  mkdir -p "$dir"
  printf '%s\n' "$MANIFEST" > "$dir/mail_badge_bridge.json"
done

# 6. Compile add-on package (.xpi)
if [[ -d "addon" ]]; then
  (cd addon && rm -f ../mail-badge-bridge.xpi \
    && python3 -m zipfile -c ../mail-badge-bridge.xpi manifest.json background.js)
elif [[ -f "manifest.json" && -f "background.js" ]]; then
  rm -f mail-badge-bridge.xpi
  python3 -m zipfile -c mail-badge-bridge.xpi manifest.json background.js
fi

echo "=================================================="
echo " Successfully installed and configured!"
echo "=================================================="
echo " Target Directory:   $TARGET_DIR"
echo " Local Desktop file: $LOCAL_DESKTOP"
echo " Wrapper script:     $WRAPPER"
echo " Systemd service:    $APP_NAME.service (running in background)"
echo " Native Helper:      $BIN_DIR/mail-badge-bridge"
echo " Add-on package:     $TARGET_DIR/mail-badge-bridge.xpi"
echo ""
echo "=================================================="
echo " Now install the add-on in Thunderbird from: $TARGET_DIR/mail-badge-bridge.xpi"
echo "    - Open Thunderbird or Betterbird."
echo "    - Go to Add-ons and Themes (Ctrl+Shift+A) -> Gear icon (⚙)."
echo "    - Click 'Install Add-on From File...'"
echo "    - Select: $TARGET_DIR/mail-badge-bridge.xpi"
echo "    - Restart your mail client once."
echo "=================================================="
echo ""
echo "=================================================="
echo "NOTE FOR CAIRO-DOCK USERS:"
echo "  If you use Cairo-Dock and the icon doesn't switch to GUI properly:"
echo "  1. Right-click the app icon in Cairo-Dock"
echo "  2. Go to '$APP_NAME' -> 'Edit'"
echo "  3. Set 'Command to launch on click' to: $WRAPPER"
echo "  4. Click 'Apply'"
echo "=================================================="
echo ""
echo "=================================================="
echo "TO UNINSTALL:"
echo "  Run the uninstallation script from:"
echo "  $TARGET_DIR/uninstall.sh"
echo "  and yay -Rns mail-badge-notifier-git (if you installed from AUR)"
echo "=================================================="
