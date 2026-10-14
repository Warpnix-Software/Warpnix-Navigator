#!/bin/bash
set -u

python3 - <<'PY'
import os
import shutil
import subprocess
import sys
import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk

home = os.path.expanduser("~")
target_dir = os.path.join(home, ".local/share/warpnix-navigator")
bin_file = os.path.join(home, ".local/bin/warpnix-navigator")
desktop_file = os.path.join(
    home, ".local/share/applications/warpnix-navigator.desktop"
)
icon_file = os.path.join(
    home, ".local/share/icons/hicolor/512x512/apps/"
    "warpnix-navigator.png"
)
config_dir = os.path.join(home, ".config/warpnix-navigator")

items = [
    ("Installed browser files", target_dir, os.path.isdir(target_dir)),
    ("Command-line launcher", bin_file, os.path.isfile(bin_file)),
    ("Application menu entry", desktop_file, os.path.isfile(desktop_file)),
    ("Application icon", icon_file, os.path.isfile(icon_file)),
]
existing = [item for item in items if item[2]]

Gtk.init_check()

def message(kind, title, text):
    dialog = Gtk.MessageDialog(
        transient_for=None,
        flags=Gtk.DialogFlags.MODAL,
        message_type=kind,
        buttons=Gtk.ButtonsType.OK,
        text=title,
    )
    dialog.format_secondary_text(text)
    dialog.run()
    dialog.destroy()

if not existing:
    message(
        Gtk.MessageType.INFO,
        "Warpnix Navigator",
        "Navigator does not appear to be installed."
    )
    sys.exit(0)

dialog = Gtk.MessageDialog(
    transient_for=None,
    flags=Gtk.DialogFlags.MODAL,
    message_type=Gtk.MessageType.WARNING,
    buttons=Gtk.ButtonsType.CANCEL,
    text="Uninstall Warpnix Navigator?",
)
dialog.add_button("Uninstall", Gtk.ResponseType.ACCEPT)
dialog.set_default_response(Gtk.ResponseType.CANCEL)
dialog.format_secondary_text(
    "The following items will be removed:\n\n"
    + "\n".join(f"• {label}\n  {path}" for label, path, _ in existing)
    + "\n\nYour browser settings and history will be preserved at:\n"
    + config_dir
)
response = dialog.run()
dialog.destroy()

if response != Gtk.ResponseType.ACCEPT:
    sys.exit(0)

try:
    for label, path, _ in existing:
        if os.path.isdir(path) and not os.path.islink(path):
            shutil.rmtree(path)
        elif os.path.lexists(path):
            os.remove(path)

    applications_dir = os.path.dirname(desktop_file)
    icons_dir = os.path.join(home, ".local/share/icons/hicolor")

    if shutil.which("update-desktop-database"):
        subprocess.run(
            ["update-desktop-database", applications_dir],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )

    if shutil.which("gtk-update-icon-cache"):
        subprocess.run(
            ["gtk-update-icon-cache", "-f", "-t", icons_dir],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )

except OSError as exc:
    message(
        Gtk.MessageType.ERROR,
        "Uninstallation failed",
        f"Could not remove an item:\n{exc}\n\n"
        "Some files may already have been removed."
    )
    sys.exit(1)

message(
    Gtk.MessageType.INFO,
    "Uninstallation complete",
    "Warpnix Navigator has been uninstalled.\n\n"
    "Your settings and browsing history were preserved."
)
PY
