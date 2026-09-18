#!/bin/bash

set -e

# Directory containing installer.sh
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parent directory = Warpnix-Navigator/
SOURCE_DIR="$(cd "$INSTALLER_DIR/.." && pwd)"

if [ ! -f "$SOURCE_DIR/wn_beta.sh" ] || [ ! -f "$SOURCE_DIR/logo.png" ]; then
    echo "Error: Could not find Warpnix Navigator files."
    echo "Make sure the installer folder is inside the Warpnix-Navigator folder."
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: Python 3 is required."
    exit 1
fi

if ! python3 -c "import gi; gi.require_version('Gtk', '3.0'); from gi.repository import Gtk" >/dev/null 2>&1; then
    echo "Error: GTK3 Python bindings are required."
    echo "On Debian/Ubuntu:"
    echo "sudo apt install python3-gi gir1.2-gtk-3.0"
    exit 1
fi

exec python3 "$INSTALLER_DIR/installer.py" "$SOURCE_DIR"
