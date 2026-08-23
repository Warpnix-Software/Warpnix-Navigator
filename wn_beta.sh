#!/bin/bash
export WEBKIT_DISABLE_COMPOSITING_MODE=1
export WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1
export LIBGL_ALWAYS_SOFTWARE=1

python3 - <<'EOF'
import os
import sys
import base64
import gi

gi.require_version('Gtk', '3.0')
gi.require_version('WebKit2', '4.1')

from gi.repository import Gtk, WebKit2, Gdk

if '__file__' in locals():
    script_path = os.path.abspath(__file__)
else:
    if sys.argv and len(sys.argv) > 0 and sys.argv[0]:
        script_path = os.path.abspath(sys.argv[0])
    else:
        script_path = os.getcwd()

current_dir = (
    os.path.dirname(script_path)
    if os.path.isfile(script_path)
    else os.getcwd()
)

logo_path = os.path.join(current_dir, "logo.png")
logo_data_uri = ""

if os.path.exists(logo_path):
    try:
        with open(logo_path, "rb") as image_file:
            encoded_string = base64.b64encode(
                image_file.read()
            ).decode("utf-8")

            logo_data_uri = (
                f"data:image/png;base64,{encoded_string}"
            )
    except Exception:
        pass


def get_homepage_html():

    gtk_settings = Gtk.Settings.get_default()

    dark_mode = gtk_settings.get_property(
        "gtk-application-prefer-dark-theme"
    )

    if dark_mode:
        background = "#121212"
        foreground = "#ffffff"
        form_background = "#1e1e1e"
        border = "#333333"
        secondary = "#888888"
    else:
        background = "#f5f5f5"
        foreground = "#111111"
        form_background = "#ffffff"
        border = "#cccccc"
        secondary = "#666666"

    logo_html = (
        f'<img src="{logo_data_uri}" alt="Warpnix Logo">'
        if logo_data_uri
        else
        '<h1>Warpnix Navigator</h1>'
    )

    return f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Warpnix Navigator</title>

    <style>
        body {{
            background-color: {background};
            color: {foreground};
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
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
            box-sizing: border-box;
        }}

        h1 {{
            font-size: 32px;
            font-weight: 600;
            margin-bottom: 25px;
            letter-spacing: -0.5px;
        }}

        img {{
            max-width: 450px;
            width: 100%;
            height: auto;
            margin-bottom: 30px;
            display: block;
            margin-left: auto;
            margin-right: auto;
        }}

        form {{
            display: flex;
            background: {form_background};
            border: 1px solid {border};
            border-radius: 24px;
            padding: 6px 15px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.15);
        }}

        input[type="text"] {{
            flex: 1;
            background: transparent;
            border: none;
            color: {foreground};
            font-size: 16px;
            padding: 10px;
            outline: none;
        }}

        input[type="text"]::placeholder {{
            color: {secondary};
        }}

        button {{
            background: transparent;
            border: none;
            color: {secondary};
            cursor: pointer;
            padding: 0 10px;
            font-size: 16px;
        }}

        button:hover {{
            color: {foreground};
        }}
    </style>
</head>

<body>
    <div class="container">
        {logo_html}

        <form onsubmit="
            event.preventDefault();
            window.location.href =
                'https://qwant.com/?q=' +
                encodeURIComponent(
                    document.querySelector('input').value
                );
        ">
            <input
                type="text"
                placeholder="Search Qwant..."
                autofocus
                required
                autocomplete="off"
            >

            <button type="submit">&#x1F50D;</button>
        </form>
    </div>
</body>
</html>
"""


window = Gtk.Window(
    title="Warpnix Navigator"
)

window.set_default_size(
    1200,
    800
)

window.connect(
    "destroy",
    Gtk.main_quit
)

main_layout = Gtk.Box(
    orientation=Gtk.Orientation.VERTICAL,
    spacing=0
)

top_panel = Gtk.Box(
    orientation=Gtk.Orientation.HORIZONTAL,
    spacing=6
)

top_panel.set_property(
    "margin",
    6
)

btn_back = Gtk.Button.new_from_icon_name(
    "go-previous",
    Gtk.IconSize.BUTTON
)

btn_forward = Gtk.Button.new_from_icon_name(
    "go-next",
    Gtk.IconSize.BUTTON
)

btn_reload = Gtk.Button.new_from_icon_name(
    "view-refresh",
    Gtk.IconSize.BUTTON
)

btn_new_tab = Gtk.Button.new_from_icon_name(
    "list-add",
    Gtk.IconSize.BUTTON
)

btn_settings = Gtk.Button(
    label="⚙ Settings"
)

btn_settings.set_tooltip_text(
    "Warpnix Settings"
)

url_entry = Gtk.Entry()

url_entry.set_text(
    "about:blank"
)

top_panel.pack_start(
    btn_back,
    False,
    False,
    0
)

top_panel.pack_start(
    btn_forward,
    False,
    False,
    0
)

top_panel.pack_start(
    btn_reload,
    False,
    False,
    0
)

top_panel.pack_start(
    url_entry,
    True,
    True,
    0
)

top_panel.pack_start(
    btn_new_tab,
    False,
    False,
    0
)

top_panel.pack_end(
    btn_settings,
    False,
    False,
    0
)

notebook = Gtk.Notebook()

notebook.set_scrollable(
    True
)

main_layout.pack_start(
    top_panel,
    False,
    False,
    0
)

main_layout.pack_start(
    notebook,
    True,
    True,
    0
)

browser_to_tab = {}

history_entries = []


def add_history_entry(webview):

    if not webview:
        return

    uri = webview.get_uri() or ""

    if (
        not uri
        or uri == "about:blank"
        or uri.startswith("file://")
    ):
        return

    title = webview.get_title() or uri

    if history_entries:
        if history_entries[-1]["uri"] == uri:
            return

    history_entries.append({
        "title": title,
        "uri": uri
    })


def save_history_to_txt(parent_window):

    if not history_entries:

        dialog = Gtk.MessageDialog(
            transient_for=parent_window,
            modal=True,
            message_type=Gtk.MessageType.INFO,
            buttons=Gtk.ButtonsType.OK,
            text="History is empty."
        )

        dialog.run()
        dialog.destroy()

        return

    dialog = Gtk.FileChooserDialog(
        title="Save Warpnix History",
        parent=parent_window,
        action=Gtk.FileChooserAction.SAVE
    )

    dialog.add_button(
        "Cancel",
        Gtk.ResponseType.CANCEL
    )

    dialog.add_button(
        "Save",
        Gtk.ResponseType.ACCEPT
    )

    dialog.set_current_name(
        "warpnix-history.txt"
    )

    dialog.set_do_overwrite_confirmation(
        True
    )

    response = dialog.run()

    if response == Gtk.ResponseType.ACCEPT:

        filename = dialog.get_filename()

        if filename:

            if not filename.lower().endswith(".txt"):
                filename += ".txt"

            try:

                with open(
                    filename,
                    "w",
                    encoding="utf-8"
                ) as history_file:

                    history_file.write(
                        "Warpnix Navigator History\n"
                    )

                    history_file.write(
                        "==========================\n\n"
                    )

                    for index, entry in enumerate(
                        reversed(history_entries),
                        start=1
                    ):

                        history_file.write(
                            f"{index}. "
                            f"{entry['title']}\n"
                        )

                        history_file.write(
                            f"   {entry['uri']}\n\n"
                        )

                success_dialog = Gtk.MessageDialog(
                    transient_for=parent_window,
                    modal=True,
                    message_type=Gtk.MessageType.INFO,
                    buttons=Gtk.ButtonsType.OK,
                    text="History saved successfully."
                )

                success_dialog.format_secondary_text(
                    filename
                )

                success_dialog.run()
                success_dialog.destroy()

            except Exception as error:

                error_dialog = Gtk.MessageDialog(
                    transient_for=parent_window,
                    modal=True,
                    message_type=Gtk.MessageType.ERROR,
                    buttons=Gtk.ButtonsType.OK,
                    text="Could not save history."
                )

                error_dialog.format_secondary_text(
                    str(error)
                )

                error_dialog.run()
                error_dialog.destroy()

    dialog.destroy()


def show_history(button=None):

    history_window = Gtk.Window(
        title="Warpnix History",
        transient_for=window,
        modal=False
    )

    history_window.set_default_size(
        650,
        500
    )

    layout = Gtk.Box(
        orientation=Gtk.Orientation.VERTICAL,
        spacing=8
    )

    layout.set_property(
        "margin",
        12
    )

    header = Gtk.Box(
        orientation=Gtk.Orientation.HORIZONTAL,
        spacing=8
    )

    title = Gtk.Label()

    title.set_markup(
        "<big><b>🕘 Warpnix History</b></big>"
    )

    title.set_xalign(0)

    header.pack_start(
        title,
        True,
        True,
        0
    )

    save_button = Gtk.Button(
        label="💾 Save as TXT"
    )

    save_button.set_tooltip_text(
        "Save browsing history as a text file"
    )

    save_button.connect(
        "clicked",
        lambda b:
            save_history_to_txt(history_window)
    )

    header.pack_end(
        save_button,
        False,
        False,
        0
    )

    layout.pack_start(
        header,
        False,
        False,
        0
    )

    scrolled = Gtk.ScrolledWindow()

    scrolled.set_policy(
        Gtk.PolicyType.AUTOMATIC,
        Gtk.PolicyType.AUTOMATIC
    )

    history_list = Gtk.ListBox()

    history_list.set_selection_mode(
        Gtk.SelectionMode.SINGLE
    )

    def open_history_url(uri):

        browser = get_current_browser()

        if browser:

            browser.load_uri(
                uri
            )

            history_window.destroy()

    def rebuild_history_list():

        for child in history_list.get_children():
            history_list.remove(child)

        for entry in reversed(history_entries):

            row = Gtk.ListBoxRow()

            row_box = Gtk.Box(
                orientation=Gtk.Orientation.VERTICAL,
                spacing=3
            )

            row_box.set_property(
                "margin",
                8
            )

            page_title = Gtk.Label(
                label=entry["title"]
            )

            page_title.set_xalign(0)

            page_title.set_ellipsize(3)

            page_uri = Gtk.Label(
                label=entry["uri"]
            )

            page_uri.set_xalign(0)

            page_uri.set_ellipsize(3)

            row_box.pack_start(
                page_title,
                False,
                False,
                0
            )

            row_box.pack_start(
                page_uri,
                False,
                False,
                0
            )

            row.add(
                row_box
            )

            row.connect(
                "activate",
                lambda r, uri=entry["uri"]:
                    open_history_url(uri)
            )

            history_list.add(
                row
            )

        history_list.show_all()

    scrolled.add(
        history_list
    )

    layout.pack_start(
        scrolled,
        True,
        True,
        0
    )

    bottom_panel = Gtk.Box(
        orientation=Gtk.Orientation.HORIZONTAL,
        spacing=8
    )

    history_count = Gtk.Label()

    history_count.set_xalign(0)

    history_count.set_text(
        f"{len(history_entries)} history entries"
    )

    clear_button = Gtk.Button(
        label="🗑 Clear History"
    )

    def clear_history(button):

        if not history_entries:
            return

        confirm = Gtk.MessageDialog(
            transient_for=history_window,
            modal=True,
            message_type=Gtk.MessageType.QUESTION,
            buttons=Gtk.ButtonsType.YES_NO,
            text="Clear all history?"
        )

        confirm.format_secondary_text(
            "This will remove all WIP history from this session."
        )

        response = confirm.run()

        confirm.destroy()

        if response == Gtk.ResponseType.YES:

            history_entries.clear()

            rebuild_history_list()

            history_count.set_text(
                "0 history entries"
            )

    clear_button.connect(
        "clicked",
        clear_history
    )

    bottom_panel.pack_start(
        history_count,
        True,
        True,
        0
    )

    bottom_panel.pack_end(
        clear_button,
        False,
        False,
        0
    )

    layout.pack_start(
        bottom_panel,
        False,
        False,
        0
    )

    history_window.add(
        layout
    )

    rebuild_history_list()

    history_window.show_all()


def get_current_browser():

    page_num = notebook.get_current_page()

    if page_num == -1:
        return None

    scrolled = notebook.get_nth_page(
        page_num
    )

    if not scrolled:
        return None

    child = scrolled.get_child()

    if isinstance(
        child,
        Gtk.Viewport
    ):
        return child.get_child()

    return child


def close_tab(
    button,
    scrolled_window
):

    page_num = notebook.page_num(
        scrolled_window
    )

    if page_num == -1:
        return

    browser = None

    for webview, tab in list(
        browser_to_tab.items()
    ):

        if tab == scrolled_window:

            browser = webview

            del browser_to_tab[
                webview
            ]

            break

    notebook.remove_page(
        page_num
    )

    if notebook.get_n_pages() == 0:
        Gtk.main_quit()


def get_tab_label_widget(
    scrolled_window
):

    tab_header = notebook.get_tab_label(
        scrolled_window
    )

    if not isinstance(
        tab_header,
        Gtk.Box
    ):
        return None

    for child in tab_header.get_children():

        if isinstance(
            child,
            Gtk.Label
        ):
            return child

    return None


def update_tab_title(
    webview
):

    if not webview:
        return

    scrolled_window = browser_to_tab.get(
        webview
    )

    if not scrolled_window:
        return

    page_num = notebook.page_num(
        scrolled_window
    )

    if page_num == -1:
        return

    uri = (
        webview.get_uri()
        or
        "about:blank"
    )

    title = webview.get_title()

    if not title or not title.strip():
        title = "New Tab"

    if (
        uri == "about:blank"
        or
        uri.startswith("file://")
    ):
        title = "New Tab"

    tab_label = get_tab_label_widget(
        scrolled_window
    )

    if tab_label:

        tab_label.set_text(
            title
        )

        tab_label.set_tooltip_text(
            title
        )


def update_browser_state(
    webview,
    *args
):

    if not webview:
        return

    add_history_entry(
        webview
    )

    update_tab_title(
        webview
    )

    current_browser = (
        get_current_browser()
    )

    if current_browser != webview:
        return

    uri = (
        webview.get_uri()
        or
        "about:blank"
    )

    title = (
        webview.get_title()
        or
        "Warpnix Navigator"
    )

    if (
        uri == "about:blank"
        or
        uri.startswith("file://")
    ):

        title = "New Tab"
        display_uri = "about:blank"

    else:

        display_uri = uri

    window.set_title(
        f"Warpnix Navigator - {title} — {display_uri}"
    )

    if not url_entry.is_focus():
        url_entry.set_text(
            display_uri
        )

    btn_back.set_sensitive(
        webview.can_go_back()
    )

    btn_forward.set_sensitive(
        webview.can_go_forward()
    )


def create_new_tab(
    url=None
):

    settings = WebKit2.Settings()

    settings.set_enable_html5_local_storage(
        True
    )

    settings.set_enable_2d_canvas_acceleration(
        True
    )

    settings.set_enable_developer_extras(
        True
    )

    settings.set_allow_file_access_from_file_urls(
        True
    )

    settings.set_user_agent(
        "Mozilla/5.0 "
        "(X11; Linux x86_64) "
        "AppleWebKit/537.36 "
        "(KHTML, like Gecko) "
        "Chrome/120.0.0.0 "
        "Safari/537.36"
    )

    context = (
        WebKit2.WebContext.get_default()
    )

    context.set_cache_model(
        WebKit2.CacheModel.DOCUMENT_VIEWER
    )

    browser = (
        WebKit2.WebView.new_with_context(
            context
        )
    )

    browser.set_settings(
        settings
    )

    scrolled_window = (
        Gtk.ScrolledWindow()
    )

    scrolled_window.add(
        browser
    )

    tab_header = Gtk.Box(
        orientation=Gtk.Orientation.HORIZONTAL,
        spacing=4
    )

    tab_header.set_size_request(
        150,
        30
    )

    tab_label = Gtk.Label(
        label="New Tab"
    )

    tab_label.set_width_chars(
        12
    )

    tab_label.set_max_width_chars(
        22
    )

    tab_label.set_ellipsize(
        3
    )

    tab_label.set_xalign(
        0.0
    )

    tab_label.set_hexpand(
        True
    )

    btn_close = Gtk.Button.new_from_icon_name(
        "window-close",
        Gtk.IconSize.MENU
    )

    btn_close.set_relief(
        Gtk.ReliefStyle.NONE
    )

    btn_close.set_focus_on_click(
        False
    )

    btn_close.connect(
        "clicked",
        close_tab,
        scrolled_window
    )

    tab_header.pack_start(
        tab_label,
        True,
        True,
        4
    )

    tab_header.pack_start(
        btn_close,
        False,
        False,
        0
    )

    tab_header.show_all()

    tab_index = notebook.append_page(
        scrolled_window,
        tab_header
    )

    browser_to_tab[
        browser
    ] = scrolled_window

    notebook.show_all()

    browser.connect(
        "notify::title",
        update_browser_state
    )

    browser.connect(
        "notify::uri",
        update_browser_state
    )

    def deny_permission(
        webview,
        request
    ):

        request.deny()

        return True

    browser.connect(
        "permission-request",
        deny_permission
    )

    if url:

        browser.load_uri(
            url
        )

    else:

        browser.load_html(
            get_homepage_html(),
            f"file://{current_dir}/"
        )

    notebook.set_current_page(
        tab_index
    )

    return browser


def on_back_clicked(
    button
):

    browser = (
        get_current_browser()
    )

    if (
        browser
        and
        browser.can_go_back()
    ):

        browser.go_back()


def on_forward_clicked(
    button
):

    browser = (
        get_current_browser()
    )

    if (
        browser
        and
        browser.can_go_forward()
    ):

        browser.go_forward()


def on_reload_clicked(
    button
):

    browser = (
        get_current_browser()
    )

    if not browser:
        return

    uri = (
        browser.get_uri()
        or
        ""
    )

    if (
        uri == "about:blank"
        or
        not uri
        or
        uri.startswith("file://")
    ):

        browser.load_html(
            get_homepage_html(),
            f"file://{current_dir}/"
        )

    else:

        browser.reload()


def on_url_submitted(
    entry
):

    browser = (
        get_current_browser()
    )

    if not browser:
        return

    url = (
        entry.get_text()
        .strip()
    )

    if (
        url == "about:blank"
        or
        not url
    ):

        browser.load_html(
            get_homepage_html(),
            f"file://{current_dir}/"
        )

        return

    if not (
        url.startswith("http://")
        or
        url.startswith("https://")
        or
        url.startswith("file://")
    ):

        if (
            " " in url
            or
            "." not in url
        ):

            url = (
                "https://qwant.com/?q="
                + url.replace(
                    " ",
                    "+"
                )
            )

        else:

            url = (
                "https://"
                + url
            )

    browser.load_uri(
        url
    )


def on_tab_switched(
    notebook_widget,
    page,
    page_num
):

    if not page:
        return

    child = page.get_child()

    if isinstance(
        child,
        Gtk.Viewport
    ):
        browser = child.get_child()
    else:
        browser = child

    if browser:
        update_browser_state(
            browser
        )


def reload_homepage_if_needed():

    browser = (
        get_current_browser()
    )

    if not browser:
        return

    uri = (
        browser.get_uri()
        or
        ""
    )

    if (
        not uri
        or
        uri == "about:blank"
        or
        uri.startswith("file://")
    ):

        browser.load_html(
            get_homepage_html(),
            f"file://{current_dir}/"
        )


def set_dark_mode():

    gtk_settings = (
        Gtk.Settings.get_default()
    )

    gtk_settings.set_property(
        "gtk-application-prefer-dark-theme",
        True
    )

    reload_homepage_if_needed()


def set_light_mode():

    gtk_settings = (
        Gtk.Settings.get_default()
    )

    gtk_settings.set_property(
        "gtk-application-prefer-dark-theme",
        False
    )

    reload_homepage_if_needed()


settings_window = None


def show_settings(
    button
):

    global settings_window

    if (
        settings_window
        and
        settings_window.get_visible()
    ):

        settings_window.present()

        return

    settings_window = Gtk.Window(
        title="Warpnix Settings",
        transient_for=window,
        modal=False
    )

    settings_window.set_default_size(
        360,
        350
    )

    settings_window.set_resizable(
        False
    )

    settings_layout = Gtk.Box(
        orientation=Gtk.Orientation.VERTICAL,
        spacing=12
    )

    settings_layout.set_property(
        "margin",
        20
    )

    title = Gtk.Label()

    title.set_markup(
        "<big><b>Warpnix Settings</b></big>"
    )

    settings_layout.pack_start(
        title,
        False,
        False,
        0
    )

    appearance_label = Gtk.Label(
        label="Appearance"
    )

    appearance_label.set_xalign(
        0
    )

    settings_layout.pack_start(
        appearance_label,
        False,
        False,
        10
    )

    dark_button = Gtk.Button(
        label="🌙  Dark Mode"
    )

    dark_button.connect(
        "clicked",
        lambda b:
            set_dark_mode()
    )

    settings_layout.pack_start(
        dark_button,
        False,
        False,
        0
    )

    light_button = Gtk.Button(
        label="☀  Light Mode"
    )

    light_button.connect(
        "clicked",
        lambda b:
            set_light_mode()
    )

    settings_layout.pack_start(
        light_button,
        False,
        False,
        0
    )

    history_button = Gtk.Button(
        label="🕘  History"
    )

    history_button.set_tooltip_text(
        "View browsing history"
    )

    history_button.connect(
        "clicked",
        show_history
    )

    settings_layout.pack_start(
        history_button,
        False,
        False,
        0
    )

    separator = Gtk.Separator(
        orientation=Gtk.Orientation.HORIZONTAL
    )

    settings_layout.pack_start(
        separator,
        False,
        False,
        10
    )

    wip_label = Gtk.Label(
        label="More settings coming soon..."
    )

    wip_label.set_xalign(
        0
    )

    settings_layout.pack_start(
        wip_label,
        False,
        False,
        0
    )

    close_app_button = Gtk.Button(
        label="❌  Close Warpnix Navigator"
    )

    close_app_button.connect(
        "clicked",
        lambda b:
            Gtk.main_quit()
    )

    settings_layout.pack_end(
        close_app_button,
        False,
        False,
        0
    )

    settings_window.add(
        settings_layout
    )

    settings_window.show_all()


btn_back.connect(
    "clicked",
    on_back_clicked
)

btn_forward.connect(
    "clicked",
    on_forward_clicked
)

btn_reload.connect(
    "clicked",
    on_reload_clicked
)

btn_new_tab.connect(
    "clicked",
    lambda b:
        create_new_tab()
)

btn_settings.connect(
    "clicked",
    show_settings
)

url_entry.connect(
    "activate",
    on_url_submitted
)

notebook.connect(
    "switch-page",
    on_tab_switched
)


def handle_shortcuts(
    widget,
    event
):

    alt_pressed = (
        event.state
        &
        Gdk.ModifierType.MOD1_MASK
    )

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

            browser = (
                get_current_browser()
            )

            if browser:

                scrolled = (
                    browser_to_tab.get(
                        browser
                    )
                )

                if scrolled:

                    close_tab(
                        None,
                        scrolled
                    )

            return True

    return False


window.connect(
    "key-press-event",
    handle_shortcuts
)

create_new_tab()

window.add(
    main_layout
)

window.show_all()

Gtk.main()

EOF
