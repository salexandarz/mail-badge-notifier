#!/usr/bin/env bash
# Mail Badge Bridge User-Space Installer
# Automatically sets up everything inside ~/mail-badge-notifier/
#
# Usage:
#   ./install.sh --thunderbird              # Thunderbird (default)
#   ./install.sh --betterbird               # Betterbird
#   ./install.sh --desktop-file NAME        # Any custom .desktop launcher

set -euo pipefail

# 0. Automatska instalacija/premeštanje u koreni korisnički folder
TARGET_DIR="$HOME/mail-badge-notifier"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$SCRIPT_DIR" != "$TARGET_DIR" ]]; then
  echo "==> Postavljanje i sinhronizacija fajlova u $TARGET_DIR..."
  mkdir -p "$TARGET_DIR"
  cp -r "$SCRIPT_DIR/"* "$TARGET_DIR/" 2>/dev/null || true
  # Osiguraj da su dozvole ispravne za korisnika
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

if [[ ! "$DESKTOP_FILE" =~ ^[A-Za-z0-9._-]+\.desktop$ ]]; then
  echo "Invalid launcher name: $DESKTOP_FILE" >&2
  exit 1
fi

echo "=================================================="
echo " Installing Mail Badge Bridge for: $APP_NAME"
echo "=================================================="

# 1. Find system desktop file and copy it locally if not already there
found=""
for d in "$HOME/.local/share/applications" /usr/local/share/applications /usr/share/applications; do
  [[ -f "$d/$DESKTOP_FILE" ]] && found="$d/$DESKTOP_FILE" && break
done

mkdir -p "$HOME/.local/share/applications"
LOCAL_DESKTOP="$HOME/.local/share/applications/$DESKTOP_FILE"

if [[ -n "$found" ]]; then
  if [[ "$found" != "$LOCAL_DESKTOP" ]]; then
    cp "$found" "$LOCAL_DESKTOP"
  fi
else
  echo "Error: $DESKTOP_FILE not found in the system." >&2
  exit 1
fi

# 2. Install Python Native Helper into ~/.local/bin
BIN="$HOME/.local/bin/mail_badge_bridge.py"
mkdir -p "$HOME/.local/bin"
if [[ -f "helper/mail_badge_bridge.py" ]]; then
  sed "s|^APP_URI = .*|APP_URI = \"application://$DESKTOP_FILE\"|" \
    helper/mail_badge_bridge.py > "$BIN"
else
  echo "Error: helper/mail_badge_bridge.py does not exist!" >&2
  exit 1
fi
chmod 755 "$BIN"

# 3. Create GUI Wrapper script in ~/.local/bin/
WRAPPER="$HOME/.local/bin/$APP_NAME"
cat <<EOF > "$WRAPPER"
#!/usr/bin/env bash
# 1. Stop background headless service
systemctl --user stop $APP_NAME.service 2>/dev/null

# 2. Ensure headless process has fully terminated
pkill -f "$SYS_BINARY --headless" 2>/dev/null
sleep 1

# 3. Launch GUI app with all passed arguments
$SYS_BINARY "\$@"

# 4. Restart headless service in the background upon closing the GUI window
systemctl --user start $APP_NAME.service 2>/dev/null
EOF
chmod +x "$WRAPPER"

# 4. Update .desktop file to use absolute wrapper path
sed -i "s|Exec=.*$APP_NAME|Exec=$WRAPPER|g" "$LOCAL_DESKTOP"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

# 5. Create and start systemd user service for Headless mode
SYSTEMD_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_DIR"
SERVICE_FILE="$SYSTEMD_DIR/$APP_NAME.service"

cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=${APP_NAME^} Headless Background Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$SYS_BINARY --headless -no-remote
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now "$APP_NAME.service" 2>/dev/null || true

# 6. Set up Native Messaging Manifest for Firefox/Thunderbird
MANIFEST=$(cat <<EOF
{
  "name": "mail_badge_bridge",
  "description": "Mail Badge Bridge helper",
  "path": "$BIN",
  "type": "stdio",
  "allowed_extensions": ["mail-badge-bridge@celest-watches.com"]
}
EOF
)

for dir in "$HOME/.mozilla/native-messaging-hosts" \
          "${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/native-messaging-hosts"; do
  mkdir -p "$dir"
  printf '%s\n' "$MANIFEST" > "$dir/mail_badge_bridge.json"
done

# 7. Compile add-on package (.xpi) directly in TARGET_DIR
if [[ -d "addon" ]]; then
  (cd addon && rm -f ../mail-badge-bridge.xpi \
    && python3 -m zipfile -c ../mail-badge-bridge.xpi manifest.json background.js)
fi

echo "=================================================="
echo " Successfully installed and configured!"
echo "=================================================="
echo " Project Directory:  $TARGET_DIR"
echo " Local Desktop file: $LOCAL_DESKTOP"
echo " Wrapper script:     $WRAPPER"
echo " Systemd service:    $APP_NAME.service (running in background)"
echo " Native Helper:      $BIN"
echo " Add-on package:     $TARGET_DIR/mail-badge-bridge.xpi"
echo
echo "Next step: Open Thunderbird -> Add-ons and Themes -> Gear icon"
echo "           -> Install Add-on From File... and select mail-badge-bridge.xpi"
