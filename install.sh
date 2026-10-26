#!/usr/bin/env bash
set -e

# XDG Standard paths for user space
INSTALL_DIR="$HOME/.local/share/mail-badge-notifier"
BIN_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"

echo "==> Starting Mail Badge Notifier installation into user space..."

# Smart client detection (Thunderbird / Betterbird) without brittle cut usage
APP_NAME=""
SYS_BINARY=""

for arg in "$@"; do
    if [[ "$arg" == *betterbird* ]]; then
        APP_NAME="betterbird"
        SYS_BINARY="betterbird"
        break
    elif [[ "$arg" == *thunderbird* ]]; then
        APP_NAME="thunderbird"
        SYS_BINARY="thunderbird"
        break
    elif [ -f "$arg" ]; then
        if grep -qi "betterbird" "$arg"; then
            APP_NAME="betterbird"
            SYS_BINARY="betterbird"
            break
        else
            APP_NAME="thunderbird"
            SYS_BINARY="thunderbird"
            break
        fi
    fi
done

# Default to Thunderbird if arguments aren't recognized
if [ -z "$APP_NAME" ]; then
    APP_NAME="thunderbird"
    SYS_BINARY="thunderbird"
fi

echo "==> Selected email client: $APP_NAME (Binary: $SYS_BINARY)"

# Create necessary directories if they don't exist
mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"
mkdir -p "$SYSTEMD_DIR"

# Determine location where the script is executed from
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Copy application files to XDG data folder (keeping git folder untouched)
echo "==> Copying application files to $INSTALL_DIR..."
if command -v rsync &> /dev/null; then
    rsync -av --exclude='.git' --exclude='install.sh' --exclude='uninstall.sh' "$SRC_DIR/" "$INSTALL_DIR/"
else
    cp -r "$SRC_DIR"/* "$INSTALL_DIR/" 2>/dev/null || true
fi

# Kreiranje izvršnog simlinka u ~/.local/bin/ (Ekvivalent za /usr/bin/)
if [ -f "$INSTALL_DIR/mail_badge_bridge.py" ]; then
    chmod +x "$INSTALL_DIR/mail_badge_bridge.py"
    ln -sf "$INSTALL_DIR/mail_badge_bridge.py" "$BIN_DIR/mail-badge-bridge"
    echo "==> Created executable link in $BIN_DIR/mail-badge-bridge"
fi

# Generate or copy .xpi extension
if [ -f "$SRC_DIR/mail-badge-bridge.xpi" ]; then
    cp "$SRC_DIR/mail-badge-bridge.xpi" "$INSTALL_DIR/"
elif [ -d "$SRC_DIR/extension" ]; then
    echo "==> Packing browser extension into .xpi..."
    cd "$SRC_DIR/extension"
    if command -v zip &> /dev/null; then
        zip -r "$INSTALL_DIR/mail-badge-notifier.xpi" * > /dev/null
    fi
    cd - > /dev/null
fi

# Configure and start systemd user service
if [ -f "$SRC_DIR/mail-badge-notifier.service" ]; then
    cp "$SRC_DIR/mail-badge-notifier.service" "$SYSTEMD_DIR/"

    echo "==> Configuring and starting systemd user service..."
    systemctl --user daemon-reload
    systemctl --user enable --now mail-badge-notifier.service
fi

echo "========================================================================"
echo " Installation completed successfully!"
echo " Application located at: $INSTALL_DIR"
echo " Executable command: mail-badge-bridge (in $BIN_DIR)"
echo " Selected client: $APP_NAME"
echo "========================================================================"
echo " You can install the extension in $APP_NAME from file:"
echo " $INSTALL_DIR/mail-badge-notifier.xpi"
echo "========================================================================"
