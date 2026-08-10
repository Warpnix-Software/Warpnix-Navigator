#!/bin/bash

export WEBKIT_DISABLE_COMPOSITING_MODE=0
export WEBKIT_FORCE_SANDBOX=0
export LIBGL_ALWAYS_SOFTWARE=1

python3 - <<EOF
import os
import gi
gi.require_version('Gtk', '3.0')
gi.require_version('WebKit2', '4.1')
from gi.repository import Gtk, WebKit2, Gdk

current_dir = os.path.dirname(os.path.realpath(__file__)) if '__file__' in locals() else os.getcwd()
logo_path = os.path.join(current_dir, "logo.png")
logo_url = "logo.png" if os.path.exists(logo_path) else ""

HOMEPAGE_HTML = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Warpnix Navigator</title>
    <style>
        body {{
            background-color: #121212;
            color: #ffffff;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            overflow: hidden;
        }}
        .container {{
            text-align: center;
            width: 100%;
            max-width: 600px;
            padding: 20px;
        }}
        img {{
            max-width: 450px;
            width: 100%;
            height: auto;
            margin-bottom: 30px;
        }}
        form {{
            display: flex;
            background: #1e1e1e;
            border: 1px solid #333;
            border-radius: 24px;
            padding: 6px 15px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.3);
        }}
        input[type="text"] {{
            flex: 1;
            background: transparent;
            border: none;
            color: white;
            font-size: 16px;
            padding: 10px;
            outline: none;
        }}
        button {{
            background: transparent;
            border: none;
            color: #888;
            cursor: pointer;
            padding: 0 10px;
            font-size: 16px;
        }}
        button:hover {{
            color: #fff;
        }}
    </style>
</head>
<body>
    <div class="container">
        {"<img src='" + logo_url + "' alt='Warpnix Logo'>" if logo_url else "<h1>Warpnix Navigator</h1>"}
        <form action="https://qwant.com" method="GET">
            <input type="text" name="q" placeholder="Search Qwant..." autofocus required autocomplete="off">
            <button type="submit">&#x1F50D;</button>
        </form>
    </div>
</body>
</html>
"""

window = Gtk.Window(title="Warpnix Navigator")
window.set_default_size(1200, 800)
window.connect("destroy", Gtk.main_quit)

settings = WebKit2.Settings()
settings.set_enable_html5_local_storage(True)
settings.set_enable_2d_canvas_acceleration(True)
settings.set_enable_developer_extras(False)
settings.set_allow_file_access_from_file_urls(True)
settings.set_user_agent("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

context = WebKit2.WebContext.get_default()
context.set_cache_model(WebKit2.CacheModel.DOCUMENT_VIEWER)

browser = WebKit2.WebView.new_with_context(context)
browser.set_settings(settings)

browser.load_html(HOMEPAGE_HTML, f"file://{current_dir}/")

scrolled_window = Gtk.ScrolledWindow()
scrolled_window.add(browser)

main_layout = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)

top_panel = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
top_panel.set_property("margin", 6)

btn_back = Gtk.Button.new_from_icon_name("go-previous", Gtk.IconSize.BUTTON)
btn_forward = Gtk.Button.new_from_icon_name("go-next", Gtk.IconSize.BUTTON)
btn_reload = Gtk.Button.new_from_icon_name("view-refresh", Gtk.IconSize.BUTTON)

url_entry = Gtk.Entry()
url_entry.set_text("about:blank")

top_panel.pack_start(btn_back, False, False, 0)
top_panel.pack_start(btn_forward, False, False, 0)
top_panel.pack_start(btn_reload, False, False, 0)
top_panel.pack_start(url_entry, True, True, 0)

main_layout.pack_start(top_panel, False, False, 0)
main_layout.pack_start(scrolled_window, True, True, 0)

def on_back_clicked(button):
    if browser.can_go_back():
        browser.go_back()

def on_forward_clicked(button):
    if browser.can_go_forward():
        browser.go_forward()

def on_reload_clicked(button):
    uri = browser.get_uri() or ""
    if uri == "about:blank" or not uri or uri.startswith("file://"):
        browser.load_html(HOMEPAGE_HTML, f"file://{current_dir}/")
    else:
        browser.reload()

btn_back.connect("clicked", on_back_clicked)
btn_forward.connect("clicked", on_forward_clicked)
btn_reload.connect("clicked", on_reload_clicked)

def on_url_submitted(entry):
    url = entry.get_text().strip()
    if url == "about:blank" or not url:
        browser.load_html(HOMEPAGE_HTML, f"file://{current_dir}/")
        return
    if not (url.startswith("http://") or url.startswith("https://") or url.startswith("file://")):
        if " " in url or "." not in url:
            url = f"https://qwant.com?q={url.replace(' ', '+')}"
        else:
            url = "https://" + url
    browser.load_uri(url)

url_entry.connect("activate", on_url_submitted)

def update_browser_state(webview, property):
    uri = browser.get_uri() or "about:blank"
    title = browser.get_title() or "Warpnix Navigator"

    if "file://" in uri or uri == "about:blank":
        title = "New Tab"
        display_uri = "about:blank"
    else:
        display_uri = uri

    window.set_title(f"{title} — {display_uri}")

    if not url_entry.is_focus():
        url_entry.set_text(display_uri)

    btn_back.set_sensitive(browser.can_go_back())
    btn_forward.set_sensitive(browser.can_go_forward())

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
            on_reload_clicked(None)
            return True
    return False

window.connect("key-press-event", handle_shortcuts)

def handle_permission_request(webview, request):
    request.deny()
    return True

browser.connect("permission-request", handle_permission_request)

window.add(main_layout)
window.show_all()
Gtk.main()
EOF
