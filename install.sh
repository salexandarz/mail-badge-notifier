#!/usr/bin/env bash
set -e

# XDG Standard paths for user space
INSTALL_DIR="$HOME/.local/share/mail-badge-notifier"
BIN_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"
APPLICATIONS_DIR="$HOME/.local/share/applications"

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
mkdir -p "$APPLICATIONS_DIR"

# Determine location where the script is executed from
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Copy application files to XDG data folder (keeping git folder untouched)
echo "==> Copying application files to $INSTALL_DIR..."
if command -v rsync &> /dev/null; then
    rsync -av --exclude='.git' --exclude='install.sh' --exclude='uninstall.sh' "$SRC_DIR/" "$INSTALL_DIR/"
else
    cp -r "$SRC_DIR"/* "$INSTALL_DIR/" 2>/dev/null || true
fi

# Automatically find and set up executable symlink in ~/.local/bin/ (recursive search)
MAIN_PY=$(find "$INSTALL_DIR" -name "*.py" | head -n 1)
if [ -n "$MAIN_PY" ]; then
    chmod +x "$MAIN_PY"
    ln -sf "$MAIN_PY" "$BIN_DIR/mail-badge-bridge"
    echo "==> Created executable link in $BIN_DIR/mail-badge-bridge -> $(basename "$MAIN_PY")"
fi

# Copy system .desktop file to user space and update Exec lines to absolute paths
SYS_DESKTOP="/usr/share/applications/${SYS_BINARY}.desktop"
LOCAL_DESKTOP="$APPLICATIONS_DIR/${SYS_BINARY}.desktop"

if [ -f "$SYS_DESKTOP" ]; then
    cp "$SYS_DESKTOP" "$LOCAL_DESKTOP"
    
    # Update Exec lines to use absolute paths
    if grep -q "^Exec=" "$LOCAL_DESKTOP"; then
        sed -i "s#^Exec=.*#Exec=/usr/bin/${SYS_BINARY}#g" "$LOCAL_DESKTOP" 2>/dev/null || true
    fi

    if command -v update-desktop-database &> /dev/null; then
        update-desktop-database "$APPLICATIONS_DIR" &> /dev/null || true
    fi
    echo "==> Installed and adjusted local .desktop file for $APP_NAME in $APPLICATIONS_DIR"
fi

# Generate or copy .xpi extension
if [ -f "$SRC_DIR/mail-badge-bridge.xpi" ]; then
    cp "$SRC_DIR/mail-badge-bridge.xpi" "$INSTALL_DIR/"
elif [ -d "$SRC_DIR/extension" ]; then
    echo "==> Packing browser extension into .xpi..."
    cd "$SRC_DIR/extension"
    if command -v zip &> /dev/null; then
        zip -r "$INSTALL_DIR/mail-badge-bridge.xpi" * > /dev/null
    fi
    cd - > /dev/null
fi

# Configure and start systemd user service (recursive search for .service)
SERVICE_SRC=$(find "$SRC_DIR" -name "*.service" | head -n 1)
if [ -n "$SERVICE_SRC" ]; then
    cp "$SERVICE_SRC" "$SYSTEMD_DIR/"
    
    echo "==> Configuring and starting systemd user service..."
    systemctl --user daemon-reload
    systemctl --user enable --now "$(basename "$SERVICE_SRC")"
fi

echo "========================================================================"
echo " Installation completed successfully!"
echo " Application located at: $INSTALL_DIR"
echo " Executable command: mail-badge-bridge (in $BIN_DIR)"
echo " Selected client: $APP_NAME"
echo "========================================================================"
echo " You can install the extension in $APP_NAME from file:"
echo " $INSTALL_DIR/mail-badge-bridge.xpi"
echo "========================================================================"
