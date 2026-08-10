#!/bin/bash

if [ ! -f "wn_beta.sh" ] || [ ! -f "logo.png" ]; then
    echo "Error: Please execute install.sh from inside your cloned Warpnix-Navigator folder."
    exit 1
fi

TARGET_DIR="$HOME/.local/share/warpnix-navigator"
APPS_DIR="$HOME/.local/share/applications"
ICONS_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"

echo "Deploying Warpnix Navigator assets..."

mkdir -p "$TARGET_DIR"
mkdir -p "$APPS_DIR"
mkdir -p "$ICONS_DIR"

cp wn_beta.sh "$TARGET_DIR/wn_beta.sh"
cp logo.png "$TARGET_DIR/logo.png"
chmod +x "$TARGET_DIR/wn_beta.sh"

cp logo.png "$ICONS_DIR/warpnix-navigator.png"

cat <<EOF > "$APPS_DIR/warpnix-navigator.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Warpnix Navigator
Comment=Lightweight, privacy-focused web browser
Exec=$TARGET_DIR/wn_beta.sh
Icon=warpnix-navigator
Terminal=false
Categories=Network;WebBrowser;
Keywords=browser;web;internet;warpnix;qwant;
EOF

chmod +x "$APPS_DIR/warpnix-navigator.desktop"

if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$APPS_DIR"
fi

echo "Installation successful! You can now launch Warpnix Navigator from your application launcher."
