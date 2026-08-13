#!/bin/bash

if [ ! -f "wn_beta.sh" ] || [ ! -f "logo.png" ]; then
    echo "Error: Please execute installer.sh from inside your cloned Warpnix-Navigator folder."
    exit 1
fi

# Standard, secure Atomic-compliant target paths
TARGET_DIR="$HOME/.local/share/warpnix-navigator"
BIN_DIR="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"
ICONS_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"

echo "Deploying Warpnix Navigator assets..."

# Ensure every single nested structure path target exists explicitly
mkdir -p "$TARGET_DIR"
mkdir -p "$BIN_DIR"
mkdir -p "$APPS_DIR"
mkdir -p "$ICONS_DIR"

# 1. Copy BOTH core assets to the shared directory where the browser expects them
cp logo.png "$TARGET_DIR/logo.png"
cp wn_beta.sh "$TARGET_DIR/wn_beta.sh"
chmod +x "$TARGET_DIR/wn_beta.sh"

# 2. Create a clean system bin wrapper redirecting execution back to the asset root
cat <<'EOF' > "$BIN_DIR/warpnix-navigator"
#!/bin/bash
exec "$HOME/.local/share/warpnix-navigator/wn_beta.sh" "$@"
EOF
chmod +x "$BIN_DIR/warpnix-navigator"

# 3. Copy image to global theme icon cache for desktop environment layout engines
cp logo.png "$ICONS_DIR/warpnix-navigator.png"

# 4. Generate the universal launcher shortcut file
cat <<EOF > "$APPS_DIR/warpnix-navigator.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Warpnix Navigator
Comment=Lightweight, privacy-focused web browser
Exec=$BIN_DIR/warpnix-navigator
Icon=warpnix-navigator
Terminal=false
Categories=Network;WebBrowser;
Keywords=browser;web;internet;warpnix;qwant;
EOF

chmod +x "$APPS_DIR/warpnix-navigator.desktop"

# Force desktop menu updates to register the application immediately
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$APPS_DIR"
fi

# Force desktop icon theme cache updates so the icon renders cleanly without a reboot
if command -v gtk-update-icon-cache &> /dev/null; then
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" &> /dev/null
fi

echo "Installation successful! You can now launch Warpnix Navigator from your application launcher."
