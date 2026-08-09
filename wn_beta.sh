#!/bin/bash

MY_URL=$(zenity --entry \
  --title="Warpnix Navigator" \
  --text="Enter website URL, leave blank to go to the default search engine, Qwant Search:" \
  --entry-text="https://qwant.com")

if [ $? -ne 0 ]; then
  exit 0
fi

if [ -z "$MY_URL" ] || [ "$MY_URL" = "https://" ]; then
  MY_URL="https://qwant.com"
elif [[ ! "$MY_URL" =~ ^[a-zA-Z]+:// ]]; then
  MY_URL="https://$MY_URL"
fi

MY_URL=$(echo "$MY_URL" | tr -d '\\')

(
  echo "10" ; sleep 0.1
  echo "50" ; sleep 0.1
  echo "90" ; sleep 0.1
  echo "100"
) | zenity --progress \
  --title="Warpnix Engine" \
  --text="Launching engine..." \
  --percentage=0 \
  --auto-close \
  --width=350

export WEBKIT_DISABLE_COMPOSITING_MODE=0
export WEBKIT_FORCE_SANDBOX=0
export LIBGL_ALWAYS_SOFTWARE=1
export TARGET_URL="$MY_URL"

python3 - <<EOF
import os
import gi
gi.require_version('Gtk', '3.0')
gi.require_version('WebKit2', '4.1')
from gi.repository import Gtk, WebKit2, Gdk

window = Gtk.Window(title="Warpnix Navigator")
window.set_default_size(1200, 800)
window.connect("destroy", Gtk.main_quit)

settings = WebKit2.Settings()
settings.set_enable_html5_local_storage(True)
settings.set_enable_2d_canvas_acceleration(True)
settings.set_enable_developer_extras(False)
settings.set_enable_hyperlink_auditing(False)
settings.set_user_agent("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

context = WebKit2.WebContext.get_default()
context.set_cache_model(WebKit2.CacheModel.DOCUMENT_VIEWER)

browser = WebKit2.WebView.new_with_context(context)
browser.set_settings(settings)
browser.load_uri(os.environ.get('TARGET_URL'))

scrolled_window = Gtk.ScrolledWindow()
scrolled_window.add(browser)

main_layout = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)

top_panel = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
top_panel.set_property("margin", 6)

url_entry = Gtk.Entry()
url_entry.set_text(os.environ.get('TARGET_URL'))

top_panel.pack_start(url_entry, True, True, 0)

main_layout.pack_start(top_panel, False, False, 0)
main_layout.pack_start(scrolled_window, True, True, 0)

def on_url_submitted(entry):
    url = entry.get_text().strip()
    if url and not (url.startswith("http://") or url.startswith("https://")):
        url = "https://" + url
    browser.load_uri(url)

url_entry.connect("activate", on_url_submitted)

def update_browser_state(webview, property):
    title = browser.get_title() or "Warpnix Navigator"
    uri = browser.get_uri() or ""
    window.set_title(f"{title} — {uri}")
    
    if not url_entry.is_focus():
        url_entry.set_text(uri)

browser.connect("notify::title", update_browser_state)
browser.connect("notify::uri", update_browser_state)

def handle_shortcuts(widget, event):
    alt_pressed = event.state & Gdk.ModifierType.MOD1_MASK
    if alt_pressed:
        if event.keyval == Gdk.KEY_Left:
            if browser.can_go_back():
                browser.go_back()
            return True
        elif event.keyval == Gdk.KEY_Right:
            if browser.can_go_forward():
                browser.go_forward()
            return True
        elif event.keyval == Gdk.KEY_r:
            browser.reload()
            return True
    return False

window.connect("key-press-event", handle_shortcuts)

window.add(main_layout)
window.show_all()
Gtk.main()
EOF

