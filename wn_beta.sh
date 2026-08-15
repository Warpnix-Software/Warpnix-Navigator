#!/bin/bash
export WEBKIT_DISABLE_COMPOSITING_MODE=1
export WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1
export LIBGL_ALWAYS_SOFTWARE=1

python3 - <<EOF
import os
import sys
import base64
import gi

gi.require_version('Gtk', '3.0')
gi.require_version('WebKit2', '4.1')
from gi.repository import Gtk, WebKit2, Gdk

# Robust environment path detection safe for Fedora Atomic container runtimes
if '__file__' in locals():
    script_path = os.path.abspath(__file__)
else:
    if sys.argv and len(sys.argv) > 0 and sys.argv[0]:
        script_path = os.path.abspath(sys.argv[0])
    else:
        script_path = os.getcwd()

current_dir = os.path.dirname(script_path) if os.path.isfile(script_path) else os.getcwd()

# Safe verification and Base64 conversion of the local image file to bypass security layers
logo_path = os.path.join(current_dir, "logo.png")
logo_data_uri = ""

if os.path.exists(logo_path):
    try:
        with open(logo_path, "rb") as image_file:
            encoded_string = base64.b64encode(image_file.read()).decode("utf-8")
            logo_data_uri = f"data:image/png;base64,{encoded_string}"
    except Exception:
        pass  # Fallback gracefully to standard text layout if reading is blocked

HOMEPAGE_HTML = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Warpnix Navigator</title>
    <style>
        body {{ background-color: #121212; color: #ffffff; font-family: -apple-system, BlinkMacSystemFont, sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; overflow: hidden; }}
        .container {{ text-align: center; width: 100%; max-width: 600px; padding: 20px; }}
        h1 {{ font-size: 32px; font-weight: 600; margin-bottom: 25px; letter-spacing: -0.5px; }}
        img {{ max-width: 450px; width: 100%; height: auto; margin-bottom: 30px; display: block; margin-left: auto; margin-right: auto; }}
        form {{ display: flex; background: #1e1e1e; border: 1px solid #333; border-radius: 24px; padding: 6px 15px; box-shadow: 0 4px 6px rgba(0,0,0,0.3); }}
        input[type="text"] {{ flex: 1; background: transparent; border: none; color: white; font-size: 16px; padding: 10px; outline: none; }}
        button {{ background: transparent; border: none; color: #888; cursor: pointer; padding: 0 10px; font-size: 16px; }}
        button:hover {{ color: #fff; }}
    </style>
</head>
<body>
    <div class="container">
        {f'<img src="{logo_data_uri}" alt="Warpnix Logo">' if logo_data_uri else '<h1>Warpnix Navigator</h1>'}
        <form onsubmit="event.preventDefault(); window.location.href='https://qwant.com/?q=' + encodeURIComponent(document.querySelector('input').value);">
            <input type="text" placeholder="Search Qwant..." autofocus required autocomplete="off">
            <button type="submit">&#x1F50D;</button>
        </form>
    </div>
</body>
</html>
"""

window = Gtk.Window(title="Warpnix Navigator")
window.set_default_size(1200, 800)
window.connect("destroy", Gtk.main_quit)

main_layout = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
top_panel = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
top_panel.set_property("margin", 6)

btn_back = Gtk.Button.new_from_icon_name("go-previous", Gtk.IconSize.BUTTON)
btn_forward = Gtk.Button.new_from_icon_name("go-next", Gtk.IconSize.BUTTON)
btn_reload = Gtk.Button.new_from_icon_name("view-refresh", Gtk.IconSize.BUTTON)
btn_new_tab = Gtk.Button.new_from_icon_name("list-add", Gtk.IconSize.BUTTON)
url_entry = Gtk.Entry()
url_entry.set_text("about:blank")

top_panel.pack_start(btn_back, False, False, 0)
top_panel.pack_start(btn_forward, False, False, 0)
top_panel.pack_start(btn_reload, False, False, 0)
top_panel.pack_start(url_entry, True, True, 0)
top_panel.pack_start(btn_new_tab, False, False, 0)

notebook = Gtk.Notebook()
notebook.set_scrollable(True)

main_layout.pack_start(top_panel, False, False, 0)
main_layout.pack_start(notebook, True, True, 0)

def get_current_browser():
    page_num = notebook.get_current_page()
    if page_num != -1:
        scrolled = notebook.get_nth_page(page_num)
        child = scrolled.get_child()
        if isinstance(child, Gtk.Viewport):
            return child.get_child()
        return child
    return None

def close_tab(button, child_widget):
    page_num = notebook.page_num(child_widget)
    if page_num != -1:
        notebook.remove_page(page_num)
    if notebook.get_n_pages() == 0:
        Gtk.main_quit()

def create_new_tab(url=None):
    settings = WebKit2.Settings()
    settings.set_enable_html5_local_storage(True)
    settings.set_enable_2d_canvas_acceleration(True)
    settings.set_enable_developer_extras(True)
    settings.set_allow_file_access_from_file_urls(True)
    settings.set_user_agent("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
    
    context = WebKit2.WebContext.get_default()
    context.set_cache_model(WebKit2.CacheModel.DOCUMENT_VIEWER)
    
    browser = WebKit2.WebView.new_with_context(context)
    browser.set_settings(settings)
    
    scrolled_window = Gtk.ScrolledWindow()
    scrolled_window.add(browser)
    
    tab_header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
    tab_label = Gtk.Label(label="New Tab")
    tab_label.set_max_width_chars(15)
    tab_label.set_ellipsize(3)
    
    btn_close = Gtk.Button.new_from_icon_name("window-close", Gtk.IconSize.MENU)
    btn_close.set_relief(Gtk.ReliefStyle.NONE)
    btn_close.connect("clicked", close_tab, scrolled_window)
    
    tab_header.pack_start(tab_label, True, True, 0)
    tab_header.pack_start(btn_close, False, False, 0)
    tab_header.show_all()
    
    tab_index = notebook.append_page(scrolled_window, tab_header)
    notebook.show_all()
    
    browser.connect("notify::title", update_browser_state)
    browser.connect("notify::uri", update_browser_state)
    browser.connect("permission-request", lambda nw, req: req.deny() or True)
    
    if url:
        browser.load_uri(url)
    else:
        browser.load_html(HOMEPAGE_HTML, f"file://{current_dir}/")
        
    notebook.set_current_page(tab_index)
    return browser

def on_back_clicked(button):
    browser = get_current_browser()
    if browser and browser.can_go_back():
        browser.go_back()

def on_forward_clicked(button):
    browser = get_current_browser()
    if browser and browser.can_go_forward():
        browser.go_forward()

def on_reload_clicked(button):
    browser = get_current_browser()
    if browser:
        uri = browser.get_uri() or ""
        if uri == "about:blank" or not uri or uri.startswith("file://"):
            browser.load_html(HOMEPAGE_HTML, f"file://{current_dir}/")
        else:
            browser.reload()

btn_back.connect("clicked", on_back_clicked)
btn_forward.connect("clicked", on_forward_clicked)
btn_reload.connect("clicked", on_reload_clicked)
btn_new_tab.connect("clicked", lambda b: create_new_tab())

def on_url_submitted(entry):
    browser = get_current_browser()
    if not browser:
        return
    url = entry.get_text().strip()
    if url == "about:blank" or not url:
        browser.load_html(HOMEPAGE_HTML, f"file://{current_dir}/")
        return
    if not (url.startswith("http://") or url.startswith("https://") or url.startswith("file://")):
        if " " in url or "." not in url:
            url = f"https://qwant.com{url.replace(' ', '+')}"
        else:
            url = "https://" + url
    browser.load_uri(url)

url_entry.connect("activate", on_url_submitted)

def update_browser_state(webview, *args):
    browser = get_current_browser()
    if not browser or webview != browser:
        return
    
    raw_uri = browser.get_uri()
    uri = raw_uri if raw_uri else "about:blank"
    title = browser.get_title() or "Warpnix Navigator"
    
    if "file://" in uri or uri == "about:blank":
        title = "New Tab"
        display_uri = "about:blank"
    else:
        display_uri = uri
        
    page_num = notebook.get_current_page()
    if page_num != -1:
        scrolled = notebook.get_nth_page(page_num)
        tab_header = notebook.get_tab_label(scrolled)
        if isinstance(tab_header, Gtk.Box):
            children = tab_header.get_children()
            if children:
                # FIXED: Correctly targeting index zero element inside list array wrapper
                children[0].set_text(title)
                
    window.set_title(f"{title} — {display_uri}")
    if not url_entry.is_focus():
        url_entry.set_text(display_uri)
        
    btn_back.set_sensitive(browser.can_go_back())
    btn_forward.set_sensitive(browser.can_go_forward())

notebook.connect("switch-page", lambda nb, p, i: update_browser_state(p.get_child(), None))

def handle_shortcuts(widget, event):
    alt_pressed = event.state & Gdk.ModifierType.MOD1_MASK
    if alt_pressed:
        if event.keyval == Gdk.KEY_Left:
            on_back_clicked(None)
            return True
        elif event.keyval == Gdk.KEY_Right:
            on_forward_clicked(None)
            return True
        elif event.keyval == Gdk.KEY_r:
            on_reload_clicked(None)
            return True
        elif event.keyval == Gdk.KEY_t:
            create_new_tab()
            return True
        elif event.keyval == Gdk.KEY_w:
            browser_widget = get_current_browser()
            if browser_widget:
                scrolled = browser_widget.get_parent()
                close_tab(None, scrolled)
            return True
    return False

window.connect("key-press-event", handle_shortcuts)

create_new_tab()
window.add(main_layout)
window.show_all()
Gtk.main()
EOF
