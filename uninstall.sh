d#!/bin/bash

TARGET_DIR="$HOME/.local/share/warpnix-navigator"
BIN_FILE="$HOME/.local/bin/warpnix-navigator"
DESKTOP_FILE="$HOME/.local/share/applications/warpnix-navigator.desktop"
ICON_FILE="$HOME/.local/share/icons/hicolor/512x512/apps/warpnix-navigator.png"
ICONS_DIR="$HOME/.local/share/icons/hicolor"

echo "Uninstalling Warpnix Navigator..."

if [ ! -d "$TARGET_DIR" ] && \
   [ ! -f "$BIN_FILE" ] && \
   [ ! -f "$DESKTOP_FILE" ] && \
   [ ! -f "$ICON_FILE" ]; then
    echo "Warpnix Navigator does not appear to be installed."
    exit 0
fi

if [ -d "$TARGET_DIR" ]; then
    rm -rf "$TARGET_DIR"
    echo "Removed browser files."
fi

if [ -f "$BIN_FILE" ]; then
    rm -f "$BIN_FILE"
    echo "Removed command-line launcher."
fi

if [ -f "$DESKTOP_FILE" ]; then
    rm -f "$DESKTOP_FILE"
    echo "Removed application launcher."
fi

if [ -f "$ICON_FILE" ]; then
    rm -f "$ICON_FILE"
    echo "Removed application icon."
fi

if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$HOME/.local/share/applications" &> /dev/null
fi

if command -v gtk-update-icon-cache &> /dev/null; then
    gtk-update-icon-cache -f -t "$ICONS_DIR" &> /dev/null
fi

echo ""
echo "Warpnix Navigator has been successfully uninstalled."
