#!/usr/bin/env bash
# Warpnix Navigator 2026.11.0

python3 - <<'EOF'

import os
import html
import sys
import shutil
import subprocess
import base64
import json
import time
import glob
import re
import sqlite3
import tempfile
import hashlib
import platform
import gi

from urllib.parse import quote_plus, urlparse

gi.require_version('Gtk', '3.0')
gi.require_version('WebKit2', '4.1')

from gi.repository import Gtk, WebKit2, Gdk, GLib

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

PLATFORM_NAME = platform.system() or "Unknown"
if PLATFORM_NAME == "DragonFly":
    PLATFORM_NAME = "DragonFly BSD"

def get_user_agent_platform():
    machine = platform.machine() or "x86_64"

    if sys.platform.startswith("freebsd"):
        return f"X11; FreeBSD {machine}"
    if sys.platform.startswith("openbsd"):
        return f"X11; OpenBSD {machine}"
    if sys.platform.startswith("netbsd"):
        return f"X11; NetBSD {machine}"
    if sys.platform.startswith("dragonfly"):
        return f"X11; DragonFly {machine}"
    if sys.platform.startswith("linux"):
        return f"X11; Linux {machine}"
    if sys.platform == "darwin":
        return f"Macintosh; Intel Mac OS X {machine}"

    return f"X11; {PLATFORM_NAME} {machine}"

# Warpnix Navigator 2026.11.0 configuration
config_dir = os.path.join(
    os.path.expanduser("~"),
    ".config",
    "warpnix-navigator"
)
config_file = os.path.join(config_dir, "settings.json")
history_file = os.path.join(config_dir, "history.json")
bookmarks_file = os.path.join(config_dir, "bookmarks.json")

def ensure_config_dir():
    try:
        os.makedirs(config_dir, exist_ok=True)
    except Exception:
        pass

ensure_config_dir()

def load_json_file(path, default):
    try:
        with open(path, "r", encoding="utf-8") as file:
            data = json.load(file)
        return data
    except Exception:
        return default

def save_json_file(path, data):
    try:
        ensure_config_dir()
        with open(path, "w", encoding="utf-8") as file:
            json.dump(data, file, indent=4)
        return True
    except Exception:
        return False

app_preferences = load_json_file(
    config_file,
    {
        "search_engine": "Qwant",
        "homepage": "warpnix",
        "theme_mode": "dark",
        "adblock_enabled": True,
        "adblock_cosmetic": True,
        "block_popups": True
    }
)

search_engine_groups = {
    "Popular": [
        ("Google", "https://www.google.com/search?q="),
        ("Bing", "https://www.bing.com/search?q="),
        ("Yahoo", "https://search.yahoo.com/search?p="),
        ("DuckDuckGo", "https://duckduckgo.com/?q="),
        ("Brave Search", "https://search.brave.com/search?q="),
        ("Qwant", "https://www.qwant.com/?q="),
        ("Ecosia", "https://www.ecosia.org/search?q="),
        ("Startpage", "https://www.startpage.com/sp/search?query="),
        ("Mojeek", "https://www.mojeek.com/search?q="),
        ("Swisscows", "https://swisscows.com/en/web?query=")
    ],
    "Privacy & independent": [
        ("MetaGer", "https://metager.org/?eingabe="),
        ("SearXNG (searx.be)", "https://searx.be/search?q="),
        ("Kagi", "https://kagi.com/search?q="),
        ("Presearch", "https://presearch.com/search?q="),
        ("Yep", "https://yep.com/web?q="),
        ("Mullvad Leta", "https://leta.mullvad.net/search?q="),
        ("Wiby", "https://wiby.me/?q="),
        ("Marginalia", "https://marginalia-search.com/search?query="),
        ("Curlie", "https://curlie.org/search?q=")
    ],
    "Metasearch": [
        ("Dogpile", "https://www.dogpile.com/serp?q="),
        ("WebCrawler", "https://www.webcrawler.com/search/web?q="),
        ("Info.com", "https://www.info.com/serp?q="),
        ("MetaCrawler", "https://www.metacrawler.com/serp?q="),
        ("ZapMeta", "https://www.zapmeta.com/search?q=")
    ],
    "AI search": [
        ("Perplexity", "https://www.perplexity.ai/search?q="),
        ("You.com", "https://you.com/search?q="),
        ("Phind", "https://www.phind.com/search?q="),
        ("Andi", "https://andisearch.com/?q=")
    ],
    "Specialty": [
        ("Google Scholar", "https://scholar.google.com/scholar?q="),
        ("Wikipedia", "https://en.wikipedia.org/w/index.php?search="),
        ("GitHub", "https://github.com/search?q="),
        ("Stack Overflow", "https://stackoverflow.com/search?q="),
        ("Reddit", "https://www.reddit.com/search/?q="),
        ("YouTube", "https://www.youtube.com/results?search_query="),
        ("IMDb", "https://www.imdb.com/find/?q="),
        ("Internet Archive Scholar", "https://scholar.archive.org/search?q="),
        ("Semantic Scholar", "https://www.semanticscholar.org/search?q="),
        ("PubMed", "https://pubmed.ncbi.nlm.nih.gov/?term="),
        ("Openverse", "https://openverse.org/search/?q="),
        ("arXiv", "https://arxiv.org/search/?query="),
        ("Library of Congress", "https://www.loc.gov/search/?q="),
        ("Wolfram Alpha", "https://www.wolframalpha.com/input?i="),
        ("Hacker News", "https://hn.algolia.com/?q="),
        ("Internet Archive", "https://archive.org/search?query=")
    ]
}

search_engines = {
    engine_name: engine_url
    for group_engines in search_engine_groups.values()
    for engine_name, engine_url in group_engines
}

def save_preferences():
    save_json_file(config_file, app_preferences)

# ---------------------------------------------------------------------------
# Ad blocking
# ---------------------------------------------------------------------------

ADBLOCK_CUSTOM_LIST_FILE = os.path.join(
    config_dir,
    "adblock-custom.txt"
)

ADBLOCK_FILTER_CACHE_DIR = os.path.join(
    config_dir,
    "adblock-filters"
)

# Deliberately conservative host list: advertising networks and analytics
# providers only. First-party login, payment, and CDN hosts are left alone.
ADBLOCK_AD_DOMAINS = [
    "33across.com",
    "3lift.com",
    "adform.net",
    "adnxs.com",
    "adroll.com",
    "adsafeprotected.com",
    "adsrvr.org",
    "adservice.google.com",
    "amazon-adsystem.com",
    "bidswitch.net",
    "casalemedia.com",
    "contextweb.com",
    "criteo.com",
    "criteo.net",
    "doubleclick.net",
    "emxdgt.com",
    "exelator.com",
    "googleadservices.com",
    "googlesyndication.com",
    "gumgum.com",
    "indexww.com",
    "inmobi.com",
    "lijit.com",
    "lkqd.net",
    "loopme.me",
    "mathtag.com",
    "media.net",
    "mgid.com",
    "moatads.com",
    "mookie1.com",
    "openx.net",
    "outbrain.com",
    "pubmatic.com",
    "revcontent.com",
    "rubiconproject.com",
    "semasio.net",
    "serving-sys.com",
    "sharethrough.com",
    "simpli.fi",
    "smartadserver.com",
    "sonobi.com",
    "sovrn.com",
    "spotx.tv",
    "spotxchange.com",
    "stackadapt.com",
    "taboola.com",
    "teads.tv",
    "tidaltv.com",
    "tremorhub.com",
    "tribalfusion.com",
    "triplelift.com",
    "turn.com",
    "yieldlab.net",
    "yieldmo.com",
    "zedo.com"
]

ADBLOCK_TRACKER_DOMAINS = [
    "addthis.com",
    "adentifi.com",
    "agkn.com",
    "amplitude.com",
    "bluekai.com",
    "chartbeat.com",
    "chartbeat.net",
    "crazyegg.com",
    "demdex.net",
    "everesttech.net",
    "fullstory.com",
    "google-analytics.com",
    "googletagmanager.com",
    "googletagservices.com",
    "heapanalytics.com",
    "hotjar.com",
    "inspectlet.com",
    "krxd.net",
    "mixpanel.com",
    "mouseflow.com",
    "omtrdc.net",
    "optimizely.com",
    "parsely.com",
    "permutive.com",
    "quantserve.com",
    "rlcdn.com",
    "scorecardresearch.com",
    "segment.com",
    "segment.io",
    "sharethis.com",
    "smartlook.com",
    "tapad.com",
    "vwo.com",
    "zeotap.com"
]

ADBLOCK_COSMETIC_SELECTORS = [
    "ins.adsbygoogle",
    ".adsbygoogle",
    "[id^='google_ads_']",
    "[id^='div-gpt-ad']",
    "[id^='ad-slot']",
    "[id^='ad_slot']",
    "[class^='ad-slot']",
    "[class*=' ad-slot']",
    "[data-ad-slot]",
    "[data-ad-unit]",
    "[data-google-query-id]",
    ".ad-banner",
    ".ad-container",
    ".ad-wrapper",
    ".ad-placeholder",
    ".advertisement",
    ".advertising",
    ".sponsored-content",
    ".sponsored-post",
    ".sponsor-box",
    ".native-ad",
    ".promoted-content",
    "#taboola",
    "#outbrain",
    ".taboola",
    ".outbrain",
    "div[id^='taboola-']",
    "div[id^='outbrain-']",
    "iframe[src*='doubleclick.net']",
    "iframe[src*='googlesyndication.com']",
    "iframe[src*='amazon-adsystem.com']",
    "iframe[src*='adsrvr.org']"
]

compiled_adblock_filter = None
adblock_style_sheet = None
adblock_last_error = ""

def adblock_is_enabled():
    return bool(
        app_preferences.get(
            "adblock_enabled",
            True
        )
    )

def parse_blocklist_line(line):
    line = line.strip()

    if not line or line.startswith(("#", "!")):
        return None

    # Accept hosts-file style entries such as "0.0.0.0 ads.example.com".
    if line.startswith(("0.0.0.0", "127.0.0.1", "::1")):
        parts = line.split()

        if len(parts) >= 2:
            line = parts[1]

    if "://" in line:
        try:
            line = urlparse(line).hostname or ""
        except Exception:
            return None

    line = line.split("/")[0].strip().lower().lstrip("*.")

    if not line or line in ("localhost", "localhost.localdomain"):
        return None

    if not re.match(
        r"^[a-z0-9][a-z0-9.-]*\.[a-z0-9-]{2,}$",
        line
    ):
        return None

    return line

def read_custom_blocklist():
    try:
        with open(
            ADBLOCK_CUSTOM_LIST_FILE,
            "r",
            encoding="utf-8"
        ) as blocklist_file:
            raw_lines = blocklist_file.readlines()
    except FileNotFoundError:
        return []
    except Exception:
        return []

    domains = []

    for raw_line in raw_lines:
        domain = parse_blocklist_line(raw_line)

        if domain and domain not in domains:
            domains.append(domain)

    return domains

def get_blocked_domains():
    domains = []
    seen = set()

    for domain in (
        ADBLOCK_AD_DOMAINS
        + ADBLOCK_TRACKER_DOMAINS
        + read_custom_blocklist()
    ):
        domain = domain.strip().lower().lstrip("*.")

        if domain and domain not in seen:
            seen.add(domain)
            domains.append(domain)

    return domains

def build_adblock_rules(domains):
    rules = []
    resource_types = [
        "document",
        "image",
        "script",
        "style-sheet",
        "font",
        "media",
        "raw",
        "svg-document",
        "popup"
    ]

    # WebKit's "if-domain" trigger matches the top-level document, not the
    # resource host, so match the host in the URL itself. The pattern also
    # covers subdomains and explicit ports, and is anchored to the scheme so
    # that "doubleclick.net.example.org" is not caught by accident.
    for domain in domains[:5000]:
        # Domain characters are limited to letters, digits, dots, and
        # hyphens, so only the dots need regex escaping. Avoiding a full
        # re.escape keeps the output compatible with WebKit's stricter
        # regular-expression subset.
        escaped_domain = domain.replace(".", "\\.")

        rules.append({
            "trigger": {
                "url-filter": (
                    "^https?://([a-z0-9_-]+\\.)*"
                    + escaped_domain
                    + "[:/]"
                ),
                "resource-type": resource_types
            },
            "action": {
                "type": "block"
            }
        })

    return rules

def build_cosmetic_style_sheet():
    global adblock_style_sheet

    if not hasattr(WebKit2, "UserStyleSheet"):
        return

    css = ",\n".join(
        ADBLOCK_COSMETIC_SELECTORS
    ) + " { display: none !important; }"

    arguments = (
        css,
        WebKit2.UserContentInjectedFrames.ALL_FRAMES,
        WebKit2.UserStyleLevel.USER,
        None,
        None
    )

    try:
        constructor = WebKit2.UserStyleSheet.new
    except AttributeError:
        constructor = WebKit2.UserStyleSheet

    try:
        adblock_style_sheet = constructor(*arguments)
    except Exception:
        try:
            adblock_style_sheet = WebKit2.UserStyleSheet(
                *arguments
            )
        except Exception:
            adblock_style_sheet = None

def compile_adblock_filter():
    global compiled_adblock_filter
    global adblock_last_error

    compiled_adblock_filter = None
    adblock_last_error = ""

    if not adblock_is_enabled():
        return None

    if not hasattr(WebKit2, "UserContentFilterStore"):
        adblock_last_error = (
            "This WebKit build does not support declarative "
            "content filters."
        )
        return None

    domains = get_blocked_domains()

    if not domains:
        return None

    payload = json.dumps(
        build_adblock_rules(domains),
        separators=(",", ":")
    ).encode("utf-8")

    identifier = (
        "warpnix-"
        + hashlib.sha256(payload).hexdigest()[:16]
    )

    try:
        os.makedirs(
            ADBLOCK_FILTER_CACHE_DIR,
            exist_ok=True
        )

        store = WebKit2.UserContentFilterStore.new(
            ADBLOCK_FILTER_CACHE_DIR
        )
    except Exception as error:
        adblock_last_error = str(error)
        return None

    result = {}
    loop = GLib.MainLoop()

    def on_saved(source, save_result, user_data):
        try:
            result["filter"] = source.save_finish(
                save_result
            )
        except Exception as error:
            result["error"] = error

        loop.quit()

    def on_timeout():
        result["error"] = RuntimeError(
            "Timed out while compiling the ad filter."
        )
        loop.quit()
        return False

    timeout_id = GLib.timeout_add(8000, on_timeout)

    try:
        try:
            store.save(
                identifier,
                GLib.Bytes.new(payload),
                None,
                on_saved,
                None
            )
        except TypeError:
            # Older WebKit bindings accepted raw bytes.
            store.save(
                identifier,
                payload,
                None,
                on_saved,
                None
            )

        loop.run()
    except Exception as error:
        result["error"] = error

    try:
        GLib.source_remove(timeout_id)
    except Exception:
        pass

    if result.get("error"):
        adblock_last_error = str(result["error"])
        return None

    compiled_adblock_filter = result.get("filter")

    if compiled_adblock_filter is None:
        adblock_last_error = (
            "The ad filter could not be compiled."
        )

    return compiled_adblock_filter

def apply_adblock_to_webview(browser):
    try:
        manager = browser.get_user_content_manager()
    except Exception:
        return

    try:
        manager.remove_all_filters()
    except Exception:
        pass

    try:
        manager.remove_all_style_sheets()
    except Exception:
        pass

    if not adblock_is_enabled():
        return

    if compiled_adblock_filter is not None:
        try:
            manager.add_filter(
                compiled_adblock_filter
            )
        except Exception:
            pass

    if (
        app_preferences.get(
            "adblock_cosmetic",
            True
        )
        and
        adblock_style_sheet is not None
    ):
        try:
            manager.add_style_sheet(
                adblock_style_sheet
            )
        except Exception:
            pass

def apply_adblock_to_all_tabs():
    for browser in list(browser_to_tab.keys()):
        apply_adblock_to_webview(browser)

def initialize_adblock():
    build_cosmetic_style_sheet()
    compile_adblock_filter()

def reload_adblock():
    compile_adblock_filter()
    apply_adblock_to_all_tabs()

def read_custom_blocklist_text():
    try:
        with open(
            ADBLOCK_CUSTOM_LIST_FILE,
            "r",
            encoding="utf-8"
        ) as blocklist_file:
            return blocklist_file.read()
    except FileNotFoundError:
        return (
            "# Warpnix Navigator custom blocklist\n"
            "# One domain per line. Lines starting with # are ignored.\n"
            "# Hosts-file entries such as 0.0.0.0 ads.example.com work too.\n"
        )
    except Exception as error:
        return "# Could not read blocklist: %s\n" % error

def show_blocklist_editor(parent, on_saved=None):
    dialog = Gtk.Window(
        title="Custom Ad Blocklist",
        transient_for=parent or window,
        modal=False
    )

    dialog.set_default_size(520, 480)

    layout = Gtk.Box(
        orientation=Gtk.Orientation.VERTICAL,
        spacing=8
    )

    layout.set_property("margin", 12)

    title = Gtk.Label()
    title.set_markup(
        "<big><b>🛡 Custom Ad Blocklist</b></big>"
    )
    title.set_xalign(0)
    layout.pack_start(title, False, False, 0)

    description = Gtk.Label(
        label=(
            "Add extra ad or tracker domains. Imports merge with "
            "the built-in list and apply immediately."
        )
    )
    description.set_xalign(0)
    description.set_line_wrap(True)
    layout.pack_start(description, False, False, 0)

    scrolled = Gtk.ScrolledWindow()
    scrolled.set_policy(
        Gtk.PolicyType.AUTOMATIC,
        Gtk.PolicyType.AUTOMATIC
    )

    text_view = Gtk.TextView()
    text_view.set_monospace(True)
    text_view.set_wrap_mode(Gtk.WrapMode.NONE)
    text_view.get_buffer().set_text(
        read_custom_blocklist_text()
    )

    scrolled.add(text_view)
    layout.pack_start(scrolled, True, True, 0)

    status = Gtk.Label(label="")
    status.set_xalign(0)
    status.set_line_wrap(True)
    layout.pack_start(status, False, False, 0)

    button_row = Gtk.Box(
        orientation=Gtk.Orientation.HORIZONTAL,
        spacing=8
    )

    cancel_button = Gtk.Button(label="Cancel")

    cancel_button.connect(
        "clicked",
        lambda b: dialog.destroy()
    )

    save_button = Gtk.Button(label="💾 Save & Apply")

    def save_blocklist(button):
        buffer = text_view.get_buffer()

        text = buffer.get_text(
            buffer.get_start_iter(),
            buffer.get_end_iter(),
            True
        )

        try:
            os.makedirs(config_dir, exist_ok=True)

            with open(
                ADBLOCK_CUSTOM_LIST_FILE,
                "w",
                encoding="utf-8"
            ) as blocklist_file:
                blocklist_file.write(text)
        except Exception as error:
            status.set_text(
                "Could not save blocklist: " + str(error)
            )
            return

        reload_adblock()

        if callable(on_saved):
            on_saved()

        dialog.destroy()

    save_button.connect("clicked", save_blocklist)

    button_row.pack_end(save_button, False, False, 0)
    button_row.pack_end(cancel_button, False, False, 0)
    layout.pack_start(button_row, False, False, 0)

    dialog.add(layout)
    dialog.show_all()

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

current_theme = {
    "name": "Default Dark",
    "version": 1,
    "colors": {
        "background": "#121212",
        "foreground": "#ffffff",
        "form_background": "#1e1e1e",
        "border": "#333333",
        "secondary": "#888888"
    }
}

BUILT_IN_THEMES = {
    "Oceanic Blue": {
        "name": "Oceanic Blue",
        "version": 1,
        "colors": {
            "background": "#071A2B",
            "foreground": "#EAF6FF",
            "form_background": "#102A43",
            "border": "#245B78",
            "secondary": "#9CC3D5"
        }
    },
    "Forest Night": {
        "name": "Forest Night",
        "version": 1,
        "colors": {
            "background": "#101B16",
            "foreground": "#E9F5EC",
            "form_background": "#1B2C23",
            "border": "#3B6049",
            "secondary": "#A9C7B2"
        }
    }
}

def normalize_hex_color(color):
    if not color:
        return "#000000"

    color = color.strip()

    if color.startswith("#"):
        color = color[1:]

    if len(color) == 6:
        return "#" + color.upper()

    if len(color) == 8:
        return "#" + color[:6].upper()

    return "#000000"

def get_theme_color(name):
    return current_theme["colors"].get(
        name,
        "#000000"
    )

def set_theme_color(name, color):
    current_theme["colors"][name] = normalize_hex_color(color)

def apply_theme(theme_data):
    global current_theme

    if not isinstance(theme_data, dict):
        return False

    colors = theme_data.get("colors")

    if not isinstance(colors, dict):
        return False

    required_colors = [
        "background",
        "foreground",
        "form_background",
        "border",
        "secondary"
    ]

    for color_name in required_colors:
        if color_name not in colors:
            return False

    current_theme = {
        "name": theme_data.get(
            "name",
            "Unnamed Theme"
        ),
        "version": theme_data.get(
            "version",
            1
        ),
        "colors": {
            "background": normalize_hex_color(
                colors["background"]
            ),
            "foreground": normalize_hex_color(
                colors["foreground"]
            ),
            "form_background": normalize_hex_color(
                colors["form_background"]
            ),
            "border": normalize_hex_color(
                colors["border"]
            ),
            "secondary": normalize_hex_color(
                colors["secondary"]
            )
        }
    }

    return True

def apply_builtin_theme(theme_name, color_buttons, theme_name_label):
    theme_data = BUILT_IN_THEMES.get(theme_name)
    if not theme_data or not apply_theme(theme_data):
        return

    theme_name_label.set_text(current_theme["name"])

    for color_name, button in color_buttons.items():
        button.set_label(get_theme_color(color_name))

    reload_homepage_if_needed()


def get_homepage_html():

    background = get_theme_color("background")
    foreground = get_theme_color("foreground")
    form_background = get_theme_color("form_background")
    border = get_theme_color("border")
    secondary = get_theme_color("secondary")

    logo_html = (
        f'<img src="{logo_data_uri}" alt="Warpnix Logo">'
        if logo_data_uri
        else '<h1>Warpnix Navigator</h1>'
    )

    search_url = search_engines.get(
        app_preferences.get("search_engine", "Qwant"),
        search_engines["Qwant"]
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

            font-family:
                -apple-system,
                BlinkMacSystemFont,
                sans-serif;

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

            box-shadow:
                0 4px 6px
                rgba(0,0,0,0.15);
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
                '{search_url}' +

                encodeURIComponent(
                    document.querySelector('input').value
                );
        ">

            <input
                type="text"
                placeholder="Search {app_preferences.get('search_engine', 'Qwant')}..."
                autofocus
                required
                autocomplete="off"
            >

            <button type="submit">
                &#x1F50D;
            </button>

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

btn_home = Gtk.Button.new_from_icon_name(
    "go-home",
    Gtk.IconSize.BUTTON
)
btn_home.set_tooltip_text("Home")

security_label = Gtk.Label(label="")
security_label.set_margin_start(4)
security_label.set_margin_end(4)

btn_new_tab = Gtk.Button.new_from_icon_name(
    "list-add",
    Gtk.IconSize.BUTTON
)

btn_settings = Gtk.Button(
    label="⚙ Settings"
)

btn_settings.set_tooltip_text(
    "Warpnix Navigator Settings"
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
    btn_home,
    False,
    False,
    0
)

top_panel.pack_start(
    security_label,
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

closed_tabs = []
history_entries = load_json_file(history_file, [])
if not isinstance(history_entries, list):
    history_entries = []

bookmarks = load_json_file(bookmarks_file, [])
if not isinstance(bookmarks, list):
    bookmarks = []

def persist_history():
    # Keep history compact and usable without letting it grow forever.
    save_json_file(history_file, history_entries[-500:])

def persist_bookmarks():
    save_json_file(bookmarks_file, bookmarks[-5000:])

def add_bookmark_entry(title, uri, folder=""):
    if not uri or not uri.startswith(("http://", "https://")):
        return False

    for existing in bookmarks:
        if existing.get("uri") == uri:
            return False

    bookmarks.append({
        "title": title or uri,
        "uri": uri,
        "folder": folder or "",
        "added": int(time.time())
    })

    return True

def remember_closed_tab(browser):
    if not browser:
        return

    uri = browser.get_uri() or ""
    if not uri or uri == "about:blank" or uri.startswith("file://"):
        return

    closed_tabs.append({
        "uri": uri,
        "title": browser.get_title() or "New Tab"
    })

    if len(closed_tabs) > 10:
        del closed_tabs[:-10]

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
        "uri": uri,
        "timestamp": int(time.time())
    })

    persist_history()

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
        title="Save Warpnix Navigator History",
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
        "warpnix-navigator-history.txt"
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

# ---------------------------------------------------------------------------
# Bookmarks and migration
# ---------------------------------------------------------------------------

def expand_globs(patterns):
    found = []

    for pattern in patterns:
        for match in glob.glob(os.path.expanduser(pattern)):
            if os.path.isfile(match) and match not in found:
                found.append(match)

    return found

def detect_migration_sources():
    sources = []

    firefox_families = [
        (
            "Mozilla Firefox",
            [
                "~/.mozilla/firefox/*/places.sqlite",
                "~/snap/firefox/common/.mozilla/firefox/*/places.sqlite",
                "~/.var/app/org.mozilla.firefox/.mozilla/firefox/*/places.sqlite"
            ]
        ),
        (
            "LibreWolf",
            [
                "~/.librewolf/*/places.sqlite",
                "~/.var/app/io.gitlab.librewolf-community/.librewolf/*/places.sqlite"
            ]
        ),
        (
            "Waterfox",
            [
                "~/.waterfox/*/places.sqlite"
            ]
        )
    ]

    for label, patterns in firefox_families:
        for db_path in expand_globs(patterns):
            profile_dir = os.path.dirname(db_path)
            profile_name = os.path.basename(profile_dir)
            suffix = (
                profile_name.split(".", 1)[-1]
                if "." in profile_name
                else profile_name
            )

            sources.append({
                "kind": "firefox",
                "name": f"{label} — {suffix}",
                "detail": profile_dir,
                "db": db_path,
                "profile": profile_dir
            })

    chromium_families = [
        (
            "Google Chrome",
            [
                "~/.config/google-chrome",
                "~/.var/app/com.google.Chrome/config/google-chrome"
            ]
        ),
        (
            "Chromium",
            [
                "~/.config/chromium",
                "~/.var/app/org.chromium.Chromium/config/chromium"
            ]
        ),
        (
            "Brave",
            [
                "~/.config/BraveSoftware/Brave-Browser",
                "~/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser"
            ]
        ),
        (
            "Microsoft Edge",
            [
                "~/.config/microsoft-edge",
                "~/.var/app/com.microsoft.Edge/config/microsoft-edge"
            ]
        ),
        (
            "Vivaldi",
            [
                "~/.config/vivaldi",
                "~/.var/app/com.vivaldi.Vivaldi/config/vivaldi"
            ]
        ),
        (
            "Opera",
            [
                "~/.config/opera",
                "~/.var/app/com.opera.Opera/config/opera"
            ]
        )
    ]

    ignored_profiles = {
        "Guest Profile",
        "System Profile",
        "Crashpad",
        "ShaderCache",
        "GrShaderCache",
        "GraphiteDawnCache",
        "BrowserMetrics",
        "Safe Browsing",
        "component_crx_cache",
        "extensions_crx_cache"
    }

    for label, base_dirs in chromium_families:
        for base_dir in base_dirs:
            base_dir = os.path.expanduser(base_dir)

            if not os.path.isdir(base_dir):
                continue

            # Some browsers (notably Opera) keep profile files directly in
            # the application data directory instead of a "Default" folder.
            base_bookmarks = os.path.join(
                base_dir,
                "Bookmarks"
            )

            base_history = os.path.join(
                base_dir,
                "History"
            )

            if (
                os.path.isfile(base_bookmarks)
                or
                os.path.isfile(base_history)
            ):
                sources.append({
                    "kind": "chromium",
                    "name": label,
                    "detail": base_dir,
                    "bookmarks": (
                        base_bookmarks
                        if os.path.isfile(base_bookmarks)
                        else None
                    ),
                    "history": (
                        base_history
                        if os.path.isfile(base_history)
                        else None
                    ),
                    "prefs": os.path.join(
                        base_dir,
                        "Preferences"
                    )
                })

            profile_names = []

            if os.path.isdir(os.path.join(base_dir, "Default")):
                profile_names.append("Default")

            try:
                entries = sorted(os.listdir(base_dir))
            except Exception:
                entries = []

            for entry in entries:
                full_path = os.path.join(base_dir, entry)

                if entry in ignored_profiles or entry == "Default":
                    continue

                if not os.path.isdir(full_path):
                    continue

                if (
                    os.path.exists(os.path.join(full_path, "Bookmarks"))
                    or
                    os.path.exists(os.path.join(full_path, "History"))
                ):
                    profile_names.append(entry)

            for profile_name in profile_names:
                profile_dir = os.path.join(
                    base_dir,
                    profile_name
                )

                bookmarks_path = os.path.join(
                    profile_dir,
                    "Bookmarks"
                )

                history_path = os.path.join(
                    profile_dir,
                    "History"
                )

                if not (
                    os.path.isfile(bookmarks_path)
                    or
                    os.path.isfile(history_path)
                ):
                    continue

                display_name = (
                    label
                    if profile_name == "Default"
                    else f"{label} ({profile_name})"
                )

                sources.append({
                    "kind": "chromium",
                    "name": display_name,
                    "detail": profile_dir,
                    "bookmarks": (
                        bookmarks_path
                        if os.path.isfile(bookmarks_path)
                        else None
                    ),
                    "history": (
                        history_path
                        if os.path.isfile(history_path)
                        else None
                    ),
                    "prefs": os.path.join(
                        profile_dir,
                        "Preferences"
                    )
                })

    return sources

def copy_sqlite_for_reading(path):
    tmpdir = tempfile.mkdtemp(
        prefix="warpnix-migrate-"
    )

    target = os.path.join(
        tmpdir,
        os.path.basename(path)
    )

    shutil.copy2(path, target)

    for suffix in ("-wal", "-shm"):
        sidecar = path + suffix

        if os.path.exists(sidecar):
            try:
                shutil.copy2(
                    sidecar,
                    target + suffix
                )
            except Exception:
                pass

    return tmpdir, target

def read_firefox_data(source):
    data = {
        "history": [],
        "bookmarks": [],
        "search_engine": None,
        "warnings": []
    }

    tmpdir = None

    try:
        tmpdir, db_copy = copy_sqlite_for_reading(
            source["db"]
        )

        connection = sqlite3.connect(db_copy)

        try:
            cursor = connection.cursor()

            cursor.execute(
                "SELECT url, title, last_visit_date "
                "FROM moz_places "
                "WHERE last_visit_date IS NOT NULL "
                "AND url LIKE 'http%' "
                "ORDER BY last_visit_date DESC "
                "LIMIT 2000"
            )

            for url, title, visited in cursor.fetchall():
                data["history"].append((
                    title or url,
                    url,
                    int((visited or 0) / 1000000)
                ))

            cursor.execute(
                "SELECT COALESCE(b.title, p.title, p.url), "
                "p.url, COALESCE(parent.title, '') "
                "FROM moz_bookmarks b "
                "JOIN moz_places p ON b.fk = p.id "
                "LEFT JOIN moz_bookmarks parent "
                "ON b.parent = parent.id "
                "WHERE b.type = 1 "
                "AND p.url LIKE 'http%'"
            )

            for title, url, folder in cursor.fetchall():
                data["bookmarks"].append((
                    title or url,
                    url,
                    folder or ""
                ))
        finally:
            connection.close()
    except Exception as error:
        data["warnings"].append(
            "Could not read Firefox data: " + str(error)
        )
    finally:
        if tmpdir:
            shutil.rmtree(tmpdir, ignore_errors=True)

    prefs_path = os.path.join(
        source.get("profile", ""),
        "prefs.js"
    )

    try:
        if not source.get("profile"):
            raise FileNotFoundError(
                "No Firefox profile directory"
            )

        with open(
            prefs_path,
            "r",
            encoding="utf-8",
            errors="replace"
        ) as prefs_file:
            prefs_text = prefs_file.read()

        match = re.search(
            r'user_pref\("browser\.search\.defaultenginename[^"]*",\s*"([^"]+)"\)',
            prefs_text
        )

        if match:
            data["search_engine"] = match.group(1)
    except Exception:
        pass

    return data

def read_chromium_bookmarks(path):
    items = []

    def walk(node, folder):
        if not isinstance(node, dict):
            return

        node_type = node.get("type")

        if node_type == "url" and node.get("url"):
            items.append((
                node.get("name") or node["url"],
                node["url"],
                folder
            ))
            return

        next_folder = folder

        if node_type == "folder":
            next_folder = node.get("name") or folder

        for child in node.get("children") or []:
            walk(child, next_folder)

    data = load_json_file(path, {})

    if not isinstance(data, dict):
        return items

    roots = data.get("roots") or {}

    for root_name, root in roots.items():
        if isinstance(root, dict):
            walk(
                root,
                root.get("name") or root_name
            )

    return items

def read_chromium_data(source):
    data = {
        "history": [],
        "bookmarks": [],
        "search_engine": None,
        "warnings": []
    }

    history_path = source.get("history")

    if history_path:
        tmpdir = None

        try:
            tmpdir, db_copy = copy_sqlite_for_reading(
                history_path
            )

            connection = sqlite3.connect(db_copy)

            try:
                cursor = connection.cursor()

                cursor.execute(
                    "SELECT url, title, last_visit_time "
                    "FROM urls "
                    "WHERE last_visit_time > 0 "
                    "AND url LIKE 'http%' "
                    "ORDER BY last_visit_time DESC "
                    "LIMIT 2000"
                )

                for url, title, visited in cursor.fetchall():
                    timestamp = int(
                        (visited or 0) / 1000000
                        - 11644473600
                    )

                    if timestamp < 0:
                        timestamp = 0

                    data["history"].append((
                        title or url,
                        url,
                        timestamp
                    ))
            finally:
                connection.close()
        except Exception as error:
            data["warnings"].append(
                "Could not read Chromium history: " + str(error)
            )
        finally:
            if tmpdir:
                shutil.rmtree(tmpdir, ignore_errors=True)

    bookmarks_path = source.get("bookmarks")

    if bookmarks_path:
        try:
            data["bookmarks"] = read_chromium_bookmarks(
                bookmarks_path
            )
        except Exception as error:
            data["warnings"].append(
                "Could not read Chromium bookmarks: " + str(error)
            )

    prefs = load_json_file(
        source.get("prefs"),
        {}
    )

    if isinstance(prefs, dict):
        candidates = []

        provider_data = prefs.get(
            "default_search_provider_data"
        )

        if isinstance(provider_data, dict):
            template = provider_data.get(
                "template_url_data"
            )

            if isinstance(template, dict):
                candidates.append(
                    template.get("short_name") or ""
                )

        provider = prefs.get("default_search_provider")

        if isinstance(provider, dict):
            candidates.append(
                provider.get("short_name") or ""
            )

        for candidate in candidates:
            if candidate:
                data["search_engine"] = candidate
                break

    return data

def read_bookmarks_html(path):
    items = []
    warnings = []
    seen = set()

    try:
        with open(
            path,
            "r",
            encoding="utf-8",
            errors="replace"
        ) as bookmarks_file:
            text = bookmarks_file.read()
    except Exception as error:
        return items, [
            "Could not read the bookmarks file: " + str(error)
        ]

    patterns = [
        re.compile(
            r'<a\s+[^>]*href\s*=\s*"([^"]+)"[^>]*>(.*?)</a>',
            re.IGNORECASE | re.DOTALL
        ),
        re.compile(
            r"<a\s+[^>]*href\s*=\s*'([^']+)'[^>]*>(.*?)</a>",
            re.IGNORECASE | re.DOTALL
        )
    ]

    for pattern in patterns:
        for match in pattern.finditer(text):
            uri = html.unescape(
                match.group(1)
            ).strip()

            title = re.sub(
                r"<[^>]+>",
                "",
                match.group(2)
            )

            title = html.unescape(title).strip()

            if not uri.startswith(("http://", "https://")):
                continue

            if uri in seen:
                continue

            seen.add(uri)
            items.append((
                title or uri,
                uri,
                "Imported"
            ))

    return items, warnings

def map_search_engine(raw_name):
    if not raw_name:
        return None

    value = raw_name.lower()

    candidates = (
        ("Google Scholar", ("google scholar",)),
        ("Internet Archive Scholar", ("archive scholar",)),
        ("Semantic Scholar", ("semantic scholar",)),
        ("Stack Overflow", ("stack overflow", "stackoverflow")),
        ("Library of Congress", ("library of congress", "loc.gov")),
        ("Hacker News", ("hacker news", "hn.algolia")),
        ("Internet Archive", ("internet archive", "archive.org")),
        ("Mullvad Leta", ("mullvad", "leta")),
        ("Brave Search", ("brave search", "brave")),
        ("Curlie", ("curlie",)),
        ("Dogpile", ("dogpile",)),
        ("DuckDuckGo", ("duckduckgo", "ddg")),
        ("Ecosia", ("ecosia",)),
        ("GitHub", ("github",)),
        ("Google", ("google",)),
        ("IMDb", ("imdb",)),
        ("Info.com", ("info.com",)),
        ("Kagi", ("kagi",)),
        ("Marginalia", ("marginalia",)),
        ("MetaCrawler", ("metacrawler", "meta crawler")),
        ("MetaGer", ("metager",)),
        ("Mojeek", ("mojeek",)),
        ("Openverse", ("openverse",)),
        ("Perplexity", ("perplexity",)),
        ("Phind", ("phind",)),
        ("Presearch", ("presearch",)),
        ("PubMed", ("pubmed",)),
        ("Qwant", ("qwant",)),
        ("Reddit", ("reddit",)),
        ("SearXNG (searx.be)", ("searx",)),
        ("Startpage", ("startpage",)),
        ("Swisscows", ("swisscows",)),
        ("WebCrawler", ("webcrawler", "web crawler")),
        ("Wiby", ("wiby",)),
        ("Wikipedia", ("wikipedia",)),
        ("Wolfram Alpha", ("wolfram",)),
        ("Yahoo", ("yahoo",)),
        ("Yep", ("yep",)),
        ("YouTube", ("youtube",)),
        ("ZapMeta", ("zapmeta",)),
        ("Andi", ("andi",)),
        ("arXiv", ("arxiv",)),
        ("Bing", ("bing",))
    )

    for engine_name, needles in candidates:
        if any(needle in value for needle in needles):
            return engine_name

    return None

def merge_imported_history(items):
    existing = {
        entry.get("uri")
        for entry in history_entries
    }

    added = 0

    for title, uri, timestamp in items:
        if not uri or uri in existing:
            continue

        history_entries.append({
            "title": title or uri,
            "uri": uri,
            "timestamp": int(timestamp or time.time())
        })

        existing.add(uri)
        added += 1

    if added:
        history_entries.sort(
            key=lambda entry: entry.get("timestamp", 0)
        )
        persist_history()

    return added

def merge_imported_bookmarks(items):
    added = 0

    for title, uri, folder in items:
        if add_bookmark_entry(title, uri, folder):
            added += 1

    if added:
        persist_bookmarks()

    return added

def run_migration(
    source,
    want_history,
    want_bookmarks,
    want_search
):
    stats = {
        "history": 0,
        "bookmarks": 0,
        "search_engine": None,
        "warnings": []
    }

    if source["kind"] == "firefox":
        data = read_firefox_data(source)
    elif source["kind"] == "chromium":
        data = read_chromium_data(source)
    elif source["kind"] == "html":
        items, warnings = read_bookmarks_html(
            source.get("path") or ""
        )
        data = {
            "history": [],
            "bookmarks": items,
            "search_engine": None,
            "warnings": warnings
        }
    else:
        return stats

    stats["warnings"].extend(
        data.get("warnings", [])
    )

    if want_history:
        stats["history"] = merge_imported_history(
            data.get("history", [])
        )

    if want_bookmarks:
        stats["bookmarks"] = merge_imported_bookmarks(
            data.get("bookmarks", [])
        )

    if want_search:
        mapped = map_search_engine(
            data.get("search_engine")
        )

        if mapped:
            app_preferences["search_engine"] = mapped
            save_preferences()
            stats["search_engine"] = mapped
        elif data.get("search_engine"):
            stats["warnings"].append(
                "Search engine '%s' is not available in "
                "Warpnix Navigator." % data["search_engine"]
            )

    return stats

def export_bookmarks_to_html(parent):
    if not bookmarks:
        dialog = Gtk.MessageDialog(
            transient_for=parent,
            modal=True,
            message_type=Gtk.MessageType.INFO,
            buttons=Gtk.ButtonsType.OK,
            text="There are no bookmarks to export."
        )

        dialog.run()
        dialog.destroy()
        return

    dialog = Gtk.FileChooserDialog(
        title="Export Warpnix Bookmarks",
        parent=parent,
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

    dialog.set_current_name("warpnix-bookmarks.html")
    dialog.set_do_overwrite_confirmation(True)

    response = dialog.run()

    if response == Gtk.ResponseType.ACCEPT:
        filename = dialog.get_filename()

        if filename and not filename.lower().endswith(
            (".html", ".htm")
        ):
            filename += ".html"

        if filename:
            try:
                with open(
                    filename,
                    "w",
                    encoding="utf-8"
                ) as bookmark_file:
                    bookmark_file.write(
                        "<!DOCTYPE NETSCAPE-Bookmark-file-1>\n"
                        '<META HTTP-EQUIV="Content-Type" '
                        'CONTENT="text/html; charset=UTF-8">\n'
                        "<TITLE>Bookmarks</TITLE>\n"
                        "<H1>Bookmarks</H1>\n"
                        "<DL><p>\n"
                    )

                    for bookmark in bookmarks:
                        bookmark_file.write(
                            '    <DT><A HREF="%s">%s</A>\n' % (
                                html.escape(
                                    bookmark.get("uri", ""),
                                    quote=True
                                ),
                                html.escape(
                                    bookmark.get("title", "")
                                )
                            )
                        )

                    bookmark_file.write("</DL><p>\n")

                success = Gtk.MessageDialog(
                    transient_for=parent,
                    modal=True,
                    message_type=Gtk.MessageType.INFO,
                    buttons=Gtk.ButtonsType.OK,
                    text="Bookmarks exported successfully."
                )

                success.format_secondary_text(filename)
                success.run()
                success.destroy()
            except Exception as error:
                error_dialog = Gtk.MessageDialog(
                    transient_for=parent,
                    modal=True,
                    message_type=Gtk.MessageType.ERROR,
                    buttons=Gtk.ButtonsType.OK,
                    text="Could not export bookmarks."
                )

                error_dialog.format_secondary_text(
                    str(error)
                )

                error_dialog.run()
                error_dialog.destroy()

    dialog.destroy()

def show_bookmarks(button=None):
    bookmarks_window = Gtk.Window(
        title="Warpnix Bookmarks",
        transient_for=window,
        modal=False
    )

    bookmarks_window.set_default_size(650, 500)

    layout = Gtk.Box(
        orientation=Gtk.Orientation.VERTICAL,
        spacing=8
    )

    layout.set_property("margin", 12)

    header = Gtk.Box(
        orientation=Gtk.Orientation.HORIZONTAL,
        spacing=8
    )

    title = Gtk.Label()
    title.set_markup(
        "<big><b>🔖 Warpnix Bookmarks</b></big>"
    )
    title.set_xalign(0)
    header.pack_start(title, True, True, 0)

    export_button = Gtk.Button(label="💾 Export HTML")
    export_button.set_tooltip_text(
        "Export bookmarks as a Netscape bookmarks file"
    )
    export_button.connect(
        "clicked",
        lambda b: export_bookmarks_to_html(
            bookmarks_window
        )
    )
    header.pack_end(export_button, False, False, 0)

    layout.pack_start(header, False, False, 0)

    scrolled = Gtk.ScrolledWindow()
    scrolled.set_policy(
        Gtk.PolicyType.AUTOMATIC,
        Gtk.PolicyType.AUTOMATIC
    )

    bookmark_list = Gtk.ListBox()
    bookmark_list.set_selection_mode(
        Gtk.SelectionMode.SINGLE
    )

    scrolled.add(bookmark_list)
    layout.pack_start(scrolled, True, True, 0)

    bottom_panel = Gtk.Box(
        orientation=Gtk.Orientation.HORIZONTAL,
        spacing=8
    )

    count_label = Gtk.Label()
    count_label.set_xalign(0)

    add_button = Gtk.Button(
        label="＋ Bookmark Current Page"
    )

    def open_bookmark(uri):
        browser = get_current_browser()

        if browser:
            browser.load_uri(uri)
            bookmarks_window.destroy()
        else:
            create_new_tab(uri)
            bookmarks_window.destroy()

    def rebuild_bookmark_list():
        for child in bookmark_list.get_children():
            bookmark_list.remove(child)

        for bookmark in bookmarks:
            row = Gtk.ListBoxRow()

            row_box = Gtk.Box(
                orientation=Gtk.Orientation.VERTICAL,
                spacing=3
            )

            row_box.set_property("margin", 8)

            bookmark_title = Gtk.Label(
                label=bookmark.get("title", "")
                or bookmark.get("uri", "")
            )
            bookmark_title.set_xalign(0)
            bookmark_title.set_ellipsize(3)

            bookmark_uri = Gtk.Label(
                label=bookmark.get("uri", "")
            )
            bookmark_uri.set_xalign(0)
            bookmark_uri.set_ellipsize(3)

            row_box.pack_start(
                bookmark_title,
                False,
                False,
                0
            )

            row_box.pack_start(
                bookmark_uri,
                False,
                False,
                0
            )

            row.add(row_box)

            row.connect(
                "activate",
                lambda r, uri=bookmark.get("uri", ""):
                    open_bookmark(uri)
            )

            bookmark_list.add(row)

        count_label.set_text(
            f"{len(bookmarks)} bookmark"
            + ("" if len(bookmarks) == 1 else "s")
        )

        bookmark_list.show_all()

    def add_current_page(btn):
        browser = get_current_browser()

        if not browser:
            return

        uri = browser.get_uri() or ""
        page_title = browser.get_title() or uri

        if not uri.startswith(("http://", "https://")):
            return

        if add_bookmark_entry(page_title, uri):
            persist_bookmarks()
            rebuild_bookmark_list()

    add_button.connect(
        "clicked",
        add_current_page
    )

    bottom_panel.pack_start(
        count_label,
        True,
        True,
        0
    )

    bottom_panel.pack_end(
        add_button,
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

    bookmarks_window.add(layout)

    rebuild_bookmark_list()
    bookmarks_window.show_all()

def show_migration_wizard(button=None):
    sources = detect_migration_sources()

    assistant = Gtk.Assistant()
    assistant.set_title("Migration Wizard")
    assistant.set_default_size(620, 480)
    assistant.set_transient_for(window)
    assistant.set_modal(False)

    intro_page = Gtk.Box(
        orientation=Gtk.Orientation.VERTICAL,
        spacing=12
    )

    intro_page.set_border_width(24)

    intro_title = Gtk.Label()
    intro_title.set_markup(
        "<big><b>🧙 Move into Warpnix Navigator</b></big>"
    )
    intro_title.set_xalign(0)

    intro_text = Gtk.Label(
        label=(
            "This wizard imports browsing history and bookmarks "
            "from another browser, and can carry over your search "
            "engine preference.\n\n"
            "Nothing is deleted or changed in the other browser. "
            "Imported entries are merged with what you already have "
            "in Warpnix Navigator, and duplicates are skipped.\n\n"
            "Supported: Firefox, LibreWolf, Waterfox, Chrome, "
            "Chromium, Brave, Edge, Vivaldi, Opera, and exported "
            "bookmarks HTML files."
        )
    )
    intro_text.set_xalign(0)
    intro_text.set_line_wrap(True)
    intro_text.set_max_width_chars(70)

    intro_page.pack_start(
        intro_title,
        False,
        False,
        0
    )

    intro_page.pack_start(
        intro_text,
        False,
        False,
        0
    )

    assistant.append_page(intro_page)
    assistant.set_page_type(
        intro_page,
        Gtk.AssistantPageType.INTRO
    )
    assistant.set_page_title(intro_page, "Welcome")
    assistant.set_page_complete(intro_page, True)

    content_page = Gtk.Box(
        orientation=Gtk.Orientation.VERTICAL,
        spacing=10
    )

    content_page.set_border_width(20)

    source_heading = Gtk.Label()
    source_heading.set_markup(
        "<b>Where are you migrating from?</b>"
    )
    source_heading.set_xalign(0)
    content_page.pack_start(
        source_heading,
        False,
        False,
        0
    )

    source_combo = Gtk.ComboBoxText()
    for source in sources:
        source_combo.append_text(source["name"])

    source_combo.append_text("Bookmarks HTML file…")
    source_combo.set_active(0)

    content_page.pack_start(
        source_combo,
        False,
        False,
        0
    )

    html_source = {
        "kind": "html",
        "name": "Bookmarks HTML file",
        "detail": "",
        "path": None
    }

    detail_label = Gtk.Label(label="")
    detail_label.set_xalign(0)
    detail_label.set_line_wrap(True)
    detail_label.set_selectable(True)
    detail_label.set_ellipsize(3)

    content_page.pack_start(
        detail_label,
        False,
        False,
        0
    )

    choose_file_button = Gtk.Button(
        label="📂 Choose Bookmarks HTML File…"
    )

    content_page.pack_start(
        choose_file_button,
        False,
        False,
        0
    )

    options_heading = Gtk.Label()
    options_heading.set_markup(
        "<b>What should be imported?</b>"
    )
    options_heading.set_xalign(0)

    content_page.pack_start(
        options_heading,
        False,
        False,
        10
    )

    history_check = Gtk.CheckButton(
        label="Browsing history"
    )
    history_check.set_active(True)
    content_page.pack_start(
        history_check,
        False,
        False,
        0
    )

    bookmarks_check = Gtk.CheckButton(
        label="Bookmarks"
    )
    bookmarks_check.set_active(True)
    content_page.pack_start(
        bookmarks_check,
        False,
        False,
        0
    )

    search_check = Gtk.CheckButton(
        label="Search engine preference"
    )
    search_check.set_active(True)
    content_page.pack_start(
        search_check,
        False,
        False,
        0
    )

    assistant.append_page(content_page)
    assistant.set_page_type(
        content_page,
        Gtk.AssistantPageType.CONTENT
    )
    assistant.set_page_title(content_page, "Source")
    assistant.set_page_complete(content_page, False)

    confirm_page = Gtk.Box(
        orientation=Gtk.Orientation.VERTICAL,
        spacing=12
    )

    confirm_page.set_border_width(20)

    confirm_heading = Gtk.Label()
    confirm_heading.set_markup(
        "<b>Ready to import</b>"
    )
    confirm_heading.set_xalign(0)

    confirm_summary = Gtk.Label(label="")
    confirm_summary.set_xalign(0)
    confirm_summary.set_line_wrap(True)
    confirm_summary.set_max_width_chars(70)

    confirm_note = Gtk.Label(
        label=(
            "Your existing Warpnix Navigator history and bookmarks "
            "are kept. Click Apply to merge the imported data."
        )
    )
    confirm_note.set_xalign(0)
    confirm_note.set_line_wrap(True)
    confirm_note.set_max_width_chars(70)

    confirm_page.pack_start(
        confirm_heading,
        False,
        False,
        0
    )
    confirm_page.pack_start(
        confirm_summary,
        False,
        False,
        0
    )
    confirm_page.pack_start(
        confirm_note,
        False,
        False,
        0
    )

    assistant.append_page(confirm_page)
    assistant.set_page_type(
        confirm_page,
        Gtk.AssistantPageType.CONFIRM
    )
    assistant.set_page_title(confirm_page, "Review")
    assistant.set_page_complete(confirm_page, True)

    results_page = Gtk.Box(
        orientation=Gtk.Orientation.VERTICAL,
        spacing=10
    )

    results_page.set_border_width(20)

    results_heading = Gtk.Label()
    results_heading.set_markup(
        "<b>Migration complete</b>"
    )
    results_heading.set_xalign(0)

    results_page.pack_start(
        results_heading,
        False,
        False,
        0
    )

    results_scroller = Gtk.ScrolledWindow()
    results_scroller.set_policy(
        Gtk.PolicyType.AUTOMATIC,
        Gtk.PolicyType.AUTOMATIC
    )

    results_view = Gtk.TextView()
    results_view.set_editable(False)
    results_view.set_cursor_visible(False)
    results_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
    results_view.get_buffer().set_text("")

    results_scroller.add(results_view)
    results_page.pack_start(
        results_scroller,
        True,
        True,
        0
    )

    open_bookmarks_button = Gtk.Button(
        label="🔖 Open Bookmarks"
    )

    def open_bookmarks_from_results(btn):
        show_bookmarks()
        assistant.destroy()

    open_bookmarks_button.connect(
        "clicked",
        open_bookmarks_from_results
    )

    results_page.pack_start(
        open_bookmarks_button,
        False,
        False,
        0
    )

    assistant.append_page(results_page)
    assistant.set_page_type(
        results_page,
        Gtk.AssistantPageType.SUMMARY
    )
    assistant.set_page_title(results_page, "Done")
    assistant.set_page_complete(results_page, True)

    migration_state = {
        "applied": False
    }

    def current_source():
        index = source_combo.get_active()

        if index < 0:
            return None

        if index == len(sources):
            return html_source

        return sources[index]

    def refresh_source(*args):
        index = source_combo.get_active()
        is_html = index == len(sources)

        choose_file_button.set_sensitive(is_html)
        history_check.set_sensitive(not is_html)
        search_check.set_sensitive(not is_html)

        if is_html:
            detail_label.set_text(
                html_source["path"]
                or "Select a bookmarks HTML file exported "
                   "from another browser."
            )
        elif 0 <= index < len(sources):
            detail_label.set_text(
                sources[index]["detail"]
            )
        else:
            detail_label.set_text("")

        assistant.set_page_complete(
            content_page,
            index >= 0
            and (
                not is_html
                or bool(html_source["path"])
            )
        )

    def choose_html_file(btn):
        dialog = Gtk.FileChooserDialog(
            title="Choose Bookmarks HTML File",
            parent=assistant,
            action=Gtk.FileChooserAction.OPEN
        )

        dialog.add_button(
            "Cancel",
            Gtk.ResponseType.CANCEL
        )

        dialog.add_button(
            "Open",
            Gtk.ResponseType.ACCEPT
        )

        html_filter = Gtk.FileFilter()
        html_filter.set_name("HTML files")
        html_filter.add_pattern("*.html")
        html_filter.add_pattern("*.htm")
        dialog.add_filter(html_filter)

        response = dialog.run()

        if response == Gtk.ResponseType.ACCEPT:
            html_source["path"] = dialog.get_filename()
            html_source["detail"] = html_source["path"] or ""

        dialog.destroy()
        refresh_source()

    source_combo.connect(
        "changed",
        refresh_source
    )

    choose_file_button.connect(
        "clicked",
        choose_html_file
    )

    def on_prepare(assistant_widget, page):
        if page is not confirm_page:
            return

        source = current_source()

        if not source:
            confirm_summary.set_text(
                "Choose a source first."
            )
            return

        selected = []

        if history_check.get_active():
            selected.append("browsing history")

        if bookmarks_check.get_active():
            selected.append("bookmarks")

        if search_check.get_active():
            selected.append("search engine preference")

        summary_lines = [
            f"From: {source['name']}",
            f"Location: {source.get('detail') or source.get('path') or 'n/a'}",
            "Importing: " + (
                ", ".join(selected) if selected else "nothing selected"
            )
        ]

        confirm_summary.set_text(
            "\n".join(summary_lines)
        )

    def on_apply(assistant_widget):
        if migration_state["applied"]:
            return

        source = current_source()

        if not source:
            return

        if (
            source["kind"] == "html"
            and not source.get("path")
        ):
            return

        stats = run_migration(
            source,
            history_check.get_active()
            and source["kind"] != "html",
            bookmarks_check.get_active(),
            search_check.get_active()
            and source["kind"] != "html"
        )

        migration_state["applied"] = True

        lines = [
            f"Source: {source['name']}",
            "",
            f"History entries added: {stats['history']}",
            f"Bookmarks added: {stats['bookmarks']}",
            "Search engine: "
            + (
                stats["search_engine"]
                if stats["search_engine"]
                else "unchanged"
            )
        ]

        if stats["warnings"]:
            lines.extend(
                ["", "Notes:"]
                + [
                    "- " + warning
                    for warning in stats["warnings"]
                ]
            )

        lines.extend([
            "",
            "Your previous history and bookmarks were preserved.",
            "Bookmarks can be viewed from Settings → Bookmarks."
        ])

        results_view.get_buffer().set_text(
            "\n".join(lines)
        )

        assistant.set_page_complete(
            results_page,
            True
        )

    assistant.connect("prepare", on_prepare)
    assistant.connect("apply", on_apply)
    assistant.connect(
        "cancel",
        lambda a: a.destroy()
    )
    assistant.connect(
        "close",
        lambda a: a.destroy()
    )

    refresh_source()
    assistant.show_all()

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
            remember_closed_tab(browser)

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

    if uri.startswith("https://"):
        security_label.set_text("🔒")
        security_label.set_tooltip_text("Secure HTTPS connection")
    elif uri.startswith("http://"):
        security_label.set_text("⚠")
        security_label.set_tooltip_text("This page is using HTTP")
    else:
        security_label.set_text("")
        security_label.set_tooltip_text("")

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

def on_webview_load_failed(webview, load_event, failing_uri, error):
    if not failing_uri:
        return False

    error_text = str(error)
    if "cancel" in error_text.lower():
        return False

    safe_uri = html.escape(str(failing_uri), quote=True)
    safe_error = html.escape(error_text[:300])

    error_page = f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Warpnix Navigator — Page unavailable</title>
<style>
:root {{
  color-scheme: dark;
  font-family: sans-serif;
}}
body {{
  margin: 0;
  min-height: 100vh;
  display: grid;
  place-items: center;
  background: #121212;
  color: #eeeeee;
}}
main {{
  max-width: 520px;
  padding: 32px;
  text-align: center;
}}
h1 {{ color: #9cc3d5; }}
.poem {{
  margin: 28px 0;
  line-height: 1.9;
  font-family: Georgia, serif;
  font-size: 1.15rem;
}}
a {{ color: #8bc9f0; }}
details {{
  margin-top: 24px;
  text-align: left;
  overflow-wrap: anywhere;
  color: #aaaaaa;
  font-size: 0.85rem;
}}
</style>
</head>
<body>
<main>
<h1>Page adrift</h1>
<div class="poem">
The signal grows faint<br>
The quiet web holds its breath<br>
Dawn may find the way
</div>
<p>Warpnix Navigator couldn't load this page.</p>
<p><a href="{safe_uri}">Try again</a></p>
<details>
<summary>Technical details</summary>
<p>{safe_uri}</p>
<p>{safe_error}</p>
</details>
</main>
</body>
</html>"""

    webview.load_html(error_page, f"file://{current_dir}/")
    return True


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
        "(" + get_user_agent_platform() + ") "
        "AppleWebKit/537.36 "
        "Chrome/120.0.0.0 "
        "Safari/537.36"
    )

    context = (
        WebKit2.WebContext.get_default()
    )

    # Use WebKit's browser-oriented cache model for normal browsing.
    context.set_cache_model(
        WebKit2.CacheModel.WEB_BROWSER
    )

    browser = (
        WebKit2.WebView.new_with_context(
            context
        )
    )

    browser.set_settings(
        settings
    )

    # Attach the compiled ad/tracker filter and cosmetic rules before the
    # first page load so no requests slip through.
    apply_adblock_to_webview(
        browser
    )

    def on_create_window(webview, navigation_action):
        try:
            request = navigation_action.get_request()
            uri = request.get_uri() if request else ""
            is_user_gesture = (
                navigation_action.is_user_gesture()
            )
        except Exception:
            return None

        if not uri or not uri.startswith(
            ("http://", "https://")
        ):
            return None

        if (
            is_user_gesture
            or
            not app_preferences.get(
                "block_popups",
                True
            )
        ):
            create_new_tab(uri)

        return None

    browser.connect(
        "create",
        on_create_window
    )

    browser.connect(
        "load-failed",
        on_webview_load_failed
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

    def on_tab_header_button_press(header, event):
        if event.button == 2:
            close_tab(None, scrolled_window)
            return True
        return False

    tab_header.add_events(
        Gdk.EventMask.BUTTON_PRESS_MASK
    )
    tab_header.connect(
        "button-press-event",
        on_tab_header_button_press
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

def go_home(button=None):
    browser = get_current_browser()
    if not browser:
        return

    browser.load_html(
        get_homepage_html(),
        f"file://{current_dir}/"
    )

def reopen_closed_tab(button=None):
    if not closed_tabs:
        return

    entry = closed_tabs.pop()
    create_new_tab(entry.get("uri"))

def update_security_for_current_tab():
    browser = get_current_browser()
    if browser:
        update_browser_state(browser)

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

            search_url = search_engines.get(
                app_preferences.get("search_engine", "Qwant"),
                search_engines["Qwant"]
            )
            url = (
                search_url
                + quote_plus(url)
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
    app_preferences["theme_mode"] = "dark"
    save_preferences()

    reload_homepage_if_needed()

def set_light_mode():

    gtk_settings = (
        Gtk.Settings.get_default()
    )

    gtk_settings.set_property(
        "gtk-application-prefer-dark-theme",
        False
    )
    app_preferences["theme_mode"] = "light"
    save_preferences()

    reload_homepage_if_needed()

def choose_color(
    parent_window,
    color_name,
    display_button
):

    current_color = get_theme_color(
        color_name
    )

    rgba = Gdk.RGBA()

    rgba.parse(
        current_color
    )

    dialog = Gtk.ColorChooserDialog(
        title=f"Choose {color_name.replace('_', ' ').title()} Color",
        parent=parent_window
    )

    dialog.set_rgba(
        rgba
    )

    response = dialog.run()

    if response == Gtk.ResponseType.OK:

        selected_rgba = dialog.get_rgba()

        red = round(
            selected_rgba.red * 255
        )

        green = round(
            selected_rgba.green * 255
        )

        blue = round(
            selected_rgba.blue * 255
        )

        new_color = (
            f"#{red:02X}"
            f"{green:02X}"
            f"{blue:02X}"
        )

        set_theme_color(
            color_name,
            new_color
        )

        display_button.set_label(
            new_color
        )

        reload_homepage_if_needed()

    dialog.destroy()

def save_theme(
    parent_window
):

    dialog = Gtk.FileChooserDialog(
        title="Save WarpNix Theme",
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
        current_theme["name"]
        .replace(" ", "-")
        .lower()
        + ".wntheme"
    )

    dialog.set_do_overwrite_confirmation(
        True
    )

    response = dialog.run()

    if response == Gtk.ResponseType.ACCEPT:

        filename = dialog.get_filename()

        if filename:

            if not filename.lower().endswith(
                ".wntheme"
            ):
                filename += ".wntheme"

            try:

                with open(
                    filename,
                    "w",
                    encoding="utf-8"
                ) as theme_file:

                    json.dump(
                        current_theme,
                        theme_file,
                        indent=4
                    )

                success_dialog = Gtk.MessageDialog(
                    transient_for=parent_window,
                    modal=True,
                    message_type=Gtk.MessageType.INFO,
                    buttons=Gtk.ButtonsType.OK,
                    text="Theme saved successfully!"
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
                    text="Could not save theme."
                )

                error_dialog.format_secondary_text(
                    str(error)
                )

                error_dialog.run()
                error_dialog.destroy()

    dialog.destroy()

def load_theme(
    parent_window,
    color_buttons,
    theme_name_label
):

    dialog = Gtk.FileChooserDialog(
        title="Load WarpNix Theme",
        parent=parent_window,
        action=Gtk.FileChooserAction.OPEN
    )

    dialog.add_button(
        "Cancel",
        Gtk.ResponseType.CANCEL
    )

    dialog.add_button(
        "Open",
        Gtk.ResponseType.ACCEPT
    )

    response = dialog.run()

    if response == Gtk.ResponseType.ACCEPT:

        filename = dialog.get_filename()

        if filename:

            try:

                with open(
                    filename,
                    "r",
                    encoding="utf-8"
                ) as theme_file:

                    theme_data = json.load(
                        theme_file
                    )

                if not apply_theme(
                    theme_data
                ):

                    raise ValueError(
                        "This is not a valid WarpNix theme file."
                    )

                for color_name, button in color_buttons.items():

                    button.set_label(
                        get_theme_color(
                            color_name
                        )
                    )

                theme_name_label.set_text(
                    current_theme["name"]
                )

                reload_homepage_if_needed()

                success_dialog = Gtk.MessageDialog(
                    transient_for=parent_window,
                    modal=True,
                    message_type=Gtk.MessageType.INFO,
                    buttons=Gtk.ButtonsType.OK,
                    text="Theme loaded successfully!"
                )

                success_dialog.format_secondary_text(
                    current_theme["name"]
                )

                success_dialog.run()
                success_dialog.destroy()

            except Exception as error:

                error_dialog = Gtk.MessageDialog(
                    transient_for=parent_window,
                    modal=True,
                    message_type=Gtk.MessageType.ERROR,
                    buttons=Gtk.ButtonsType.OK,
                    text="Could not load theme."
                )

                error_dialog.format_secondary_text(
                    str(error)
                )

                error_dialog.run()
                error_dialog.destroy()

    dialog.destroy()

def change_theme_name(
    entry,
    theme_name_label
):

    name = entry.get_text().strip()

    if name:

        current_theme["name"] = name

        theme_name_label.set_text(
            name
        )

settings_window = None

def show_about(button=None):
    about_text = (
        "Warpnix Navigator 2026.11.0\n"
        "A lightweight, privacy-focused browser\n\n"
        "Built with Python, Bash, GTK3, and WebKit2GTK.\n"
        "Platform: " + PLATFORM_NAME + "\n"
        "Camera, microphone, and location requests are denied by default.\n\n"
        "Part of the Warpnix open-source software family."
    )

    zenity = shutil.which("zenity")
    if zenity:
        try:
            subprocess.run(
                [
                    zenity,
                    "--info",
                    "--title=About Warpnix Navigator",
                    "--width=420",
                    "--text=" + about_text
                ],
                check=False
            )
            return
        except OSError:
            pass

    fallback = Gtk.MessageDialog(
        transient_for=window,
        modal=True,
        message_type=Gtk.MessageType.INFO,
        buttons=Gtk.ButtonsType.OK,
        text="Warpnix Navigator 2026.11.0"
    )
    fallback.format_secondary_text(
        "A lightweight, privacy-focused browser\n"
        "Built with Python, Bash, GTK3, and WebKit2GTK.\n"
        "Platform: " + PLATFORM_NAME + "\n"
        "Part of the Warpnix open-source software family."
    )
    fallback.run()
    fallback.destroy()



def show_media_performance(button=None):
    """Display read-only media and graphics diagnostics."""

    lines = [
        "Warpnix Navigator 2026.11.0 — Media & Performance",
        "=" * 52,
        "",
        "WEBKITGTK",
    ]

    try:
        lines.append(
            "Version: {}.{}.{}".format(
                WebKit2.get_major_version(),
                WebKit2.get_minor_version(),
                WebKit2.get_micro_version()
            )
        )
    except Exception as error:
        lines.append("Version unavailable: " + str(error))

    try:
        media_settings = WebKit2.Settings()
        for prop_name in (
            "enable-mediasource",
            "enable-webaudio",
            "enable-media-stream",
            "enable-encrypted-media",
            "hardware-acceleration-policy",
        ):
            prop = media_settings.find_property(prop_name)
            if prop is None:
                lines.append("{}: not exposed".format(prop_name))
                continue
            try:
                value = media_settings.get_property(prop_name)
                lines.append("{}: {}".format(prop_name, value))
            except Exception as error:
                lines.append("{}: unavailable ({})".format(
                    prop_name, error
                ))
    except Exception as error:
        lines.append("Settings inspection failed: " + str(error))

    lines.extend(["", "GRAPHICS RENDERER"])
    try:
        result = subprocess.run(
            ["glxinfo", "-B"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        relevant = [
            line.strip()
            for line in (result.stdout + "\n" + result.stderr).splitlines()
            if any(term in line.lower() for term in (
                "direct rendering",
                "opengl vendor",
                "opengl renderer",
                "opengl version",
            ))
        ]
        lines.extend(relevant or [
            "Renderer information unavailable (glxinfo may be missing)."
        ])
    except (OSError, subprocess.SubprocessError) as error:
        lines.append("Could not run glxinfo: " + str(error))

    lines.extend(["", "OPTIONAL TOOLS"])
    for command in ("vainfo", "gst-inspect-1.0", "glxinfo"):
        lines.append("{}: {}".format(
            command, shutil.which(command) or "not installed"
        ))

    gst_inspect = shutil.which("gst-inspect-1.0")
    if gst_inspect:
        lines.extend(["", "GSTREAMER VIDEO PLUGINS"])
        for plugin in ("playbin3", "decodebin", "avdec_h264",
                       "vah264dec", "va"):
            try:
                result = subprocess.run(
                    [gst_inspect, plugin],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=3,
                    check=False,
                )
                lines.append("{}: {}".format(
                    plugin,
                    "available" if result.returncode == 0
                    else "not detected"
                ))
            except (OSError, subprocess.SubprocessError):
                lines.append("{}: check failed".format(plugin))

    lines.extend([
        "",
        "Notes:",
        "- This report does not change browser settings.",
        "- Software rendering and hardware video decoding are different.",
        "- Available plugins do not guarantee hardware decoding works.",
    ])
    report = "\n".join(lines)

    dialog = Gtk.Dialog(
        title="Media & Performance",
        transient_for=window,
        modal=False,
    )
    dialog.set_default_size(680, 520)
    dialog.add_button("Close", Gtk.ResponseType.CLOSE)
    copy_button = dialog.add_button(
        "Copy Diagnostics", Gtk.ResponseType.NONE
    )

    content = dialog.get_content_area()
    content.set_spacing(8)
    content.set_border_width(12)

    description = Gtk.Label(
        label="Read-only diagnostics for troubleshooting playback and rendering."
    )
    description.set_xalign(0)
    content.pack_start(description, False, False, 0)

    scroller = Gtk.ScrolledWindow()
    scroller.set_policy(
        Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC
    )
    text_view = Gtk.TextView()
    text_view.set_editable(False)
    text_view.set_cursor_visible(False)
    text_view.set_monospace(True)
    text_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
    text_view.get_buffer().set_text(report)
    scroller.add(text_view)
    content.pack_start(scroller, True, True, 0)

    def copy_report(_button):
        clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
        clipboard.set_text(report, -1)
        clipboard.store()
        copy_button.set_label("Copied!")

    copy_button.connect("clicked", copy_report)
    dialog.show_all()
    dialog.run()
    dialog.destroy()


def show_search_engine_chooser(parent, on_selected):
    chooser = Gtk.Window(
        title="Choose Search Engine",
        transient_for=parent,
        modal=True
    )
    chooser.set_default_size(560, 640)
    chooser.set_position(Gtk.WindowPosition.CENTER_ON_PARENT)
    chooser.set_border_width(12)

    outer = Gtk.Box(
        orientation=Gtk.Orientation.VERTICAL,
        spacing=8
    )
    chooser.add(outer)

    title = Gtk.Label()
    title.set_markup("<big><b>🔍 Choose Search Engine</b></big>")
    title.set_xalign(0)
    outer.pack_start(title, False, False, 0)

    hint = Gtk.Label(
        label=(
            "Used for address-bar searches and the homepage. "
            "Double-click an engine, or select one and press Enter."
        )
    )
    hint.set_xalign(0)
    hint.set_line_wrap(True)
    outer.pack_start(hint, False, False, 0)

    filter_entry = Gtk.SearchEntry()
    filter_entry.set_placeholder_text("Filter search engines...")
    outer.pack_start(filter_entry, False, False, 0)

    scrolled = Gtk.ScrolledWindow()
    scrolled.set_policy(
        Gtk.PolicyType.NEVER,
        Gtk.PolicyType.AUTOMATIC
    )
    outer.pack_start(scrolled, True, True, 0)

    listbox = Gtk.ListBox()
    listbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
    scrolled.add(listbox)

    current_engine = app_preferences.get("search_engine", "Qwant")
    engine_rows = []
    header_rows = {}
    current_row = None

    for group_name in search_engine_groups:
        header = Gtk.Label()
        header.set_markup(
            f"<b>{html.escape(group_name)}</b>"
        )
        header.set_xalign(0)
        header.set_margin_top(10)
        header.set_margin_bottom(4)
        header.get_style_context().add_class("dim-label")

        header_row = Gtk.ListBoxRow()
        header_row.set_selectable(False)
        header_row.set_activatable(False)
        header_row.add(header)
        listbox.add(header_row)
        header_rows[group_name] = header_row

        for engine_name, engine_url in search_engine_groups[group_name]:
            row = Gtk.ListBoxRow()
            row_box = Gtk.Box(
                orientation=Gtk.Orientation.HORIZONTAL,
                spacing=8
            )

            label = Gtk.Label(label=engine_name)
            label.set_xalign(0)
            row_box.pack_start(label, True, True, 0)

            check = Gtk.Image.new_from_icon_name(
                "object-select-symbolic",
                Gtk.IconSize.MENU
            )
            check.set_no_show_all(True)
            if engine_name == current_engine:
                check.show()
            row_box.pack_end(check, False, False, 0)

            row.add(row_box)
            row.engine_name = engine_name
            listbox.add(row)
            engine_rows.append(
                (row, group_name, engine_name)
            )

            if engine_name == current_engine:
                current_row = row

    if current_row is not None:
        listbox.select_row(current_row)
        current_row.grab_focus()

    def filter_engines(entry):
        needle = entry.get_text().strip().lower()
        visible_groups = set()

        for row, group_name, engine_name in engine_rows:
            haystack = f"{group_name} {engine_name}".lower()
            matching = not needle or needle in haystack
            row.set_visible(matching)
            if matching:
                visible_groups.add(group_name)

        for group_name, header_row in header_rows.items():
            header_row.set_visible(
                not needle or group_name in visible_groups
            )

    def apply_engine(row):
        engine_name = getattr(row, "engine_name", None)
        if engine_name not in search_engines:
            return

        on_selected(engine_name)
        chooser.destroy()

    def choose_first_match(_entry):
        for row, _group_name, _engine_name in engine_rows:
            if row.get_visible():
                listbox.select_row(row)
                apply_engine(row)
                return

    listbox.connect(
        "row-activated",
        lambda _listbox, row: apply_engine(row)
    )
    filter_entry.connect("changed", filter_engines)
    filter_entry.connect("activate", choose_first_match)

    button_box = Gtk.ButtonBox(
        orientation=Gtk.Orientation.HORIZONTAL
    )
    button_box.set_layout(Gtk.ButtonBoxStyle.END)
    button_box.set_spacing(6)
    outer.pack_start(button_box, False, False, 0)

    cancel_button = Gtk.Button(label="Cancel")
    cancel_button.connect(
        "clicked",
        lambda _button: chooser.destroy()
    )
    button_box.add(cancel_button)

    choose_button = Gtk.Button(label="Use Engine")
    choose_button.get_style_context().add_class(
        "suggested-action"
    )
    choose_button.set_sensitive(current_row is not None)
    choose_button.connect(
        "clicked",
        lambda _button: apply_engine(
            listbox.get_selected_row()
        )
    )
    button_box.add(choose_button)

    def on_key_press(_widget, event):
        if event.keyval == Gdk.KEY_Escape:
            chooser.destroy()
            return True
        return False

    chooser.connect("key-press-event", on_key_press)
    chooser.show_all()
    filter_entry.grab_focus()


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
        470,
        720
    )

    settings_window.set_resizable(
        True
    )

    settings_layout = Gtk.Box(
        orientation=Gtk.Orientation.VERTICAL,
        spacing=10
    )

    about_button = Gtk.Button(
        label="About Warpnix Navigator"
    )
    about_button.connect("clicked", show_about)
    settings_layout.pack_start(
        about_button,
        False,
        False,
        0
    )

    media_button = Gtk.Button(
        label="Media & Performance"
    )
    media_button.connect("clicked", show_media_performance)
    settings_layout.pack_start(
        media_button,
        False,
        False,
        0
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

    separator1 = Gtk.Separator(
        orientation=Gtk.Orientation.HORIZONTAL
    )

    settings_layout.pack_start(
        separator1,
        False,
        False,
        8
    )

    theme_label = Gtk.Label()

    theme_label.set_markup(
        "<b>🎨 Custom Theme</b>"
    )

    theme_label.set_xalign(
        0
    )

    settings_layout.pack_start(
        theme_label,
        False,
        False,
        0
    )

    theme_name_label = Gtk.Label(
        label=current_theme["name"]
    )

    theme_name_label.set_xalign(
        0
    )

    settings_layout.pack_start(
        theme_name_label,
        False,
        False,
        0
    )

    theme_name_entry = Gtk.Entry()

    theme_name_entry.set_placeholder_text(
        "Theme name..."
    )

    theme_name_entry.set_text(
        current_theme["name"]
    )

    settings_layout.pack_start(
        theme_name_entry,
        False,
        False,
        0
    )

    theme_name_button = Gtk.Button(
        label="✏ Set Theme Name"
    )

    theme_name_button.connect(
        "clicked",
        lambda b:
            change_theme_name(
                theme_name_entry,
                theme_name_label
            )
    )

    settings_layout.pack_start(
        theme_name_button,
        False,
        False,
        0
    )

    color_buttons = {}

    color_definitions = [
        (
            "background",
            "Background"
        ),
        (
            "foreground",
            "Foreground"
        ),
        (
            "form_background",
            "Form Background"
        ),
        (
            "border",
            "Border"
        ),
        (
            "secondary",
            "Secondary Text"
        )
    ]

    for color_name, display_name in color_definitions:

        row = Gtk.Box(
            orientation=Gtk.Orientation.HORIZONTAL,
            spacing=8
        )

        label = Gtk.Label(
            label=display_name
        )

        label.set_xalign(
            0
        )

        label.set_hexpand(
            True
        )

        color_button = Gtk.Button(
            label=get_theme_color(
                color_name
            )
        )

        color_button.set_size_request(
            110,
            35
        )

        color_button.connect(
            "clicked",
            lambda b,
            name=color_name:
                choose_color(
                    settings_window,
                    name,
                    b
                )
        )

        row.pack_start(
            label,
            True,
            True,
            0
        )

        row.pack_end(
            color_button,
            False,
            False,
            0
        )

        settings_layout.pack_start(
            row,
            False,
            False,
            0
        )

        color_buttons[
            color_name
        ] = color_button

    quick_theme_row = Gtk.Box(
        orientation=Gtk.Orientation.HORIZONTAL,
        spacing=8
    )

    quick_theme_combo = Gtk.ComboBoxText()
    quick_theme_combo.append_text("Oceanic Blue")
    quick_theme_combo.append_text("Forest Night")
    quick_theme_combo.set_active(-1)
    quick_theme_combo.set_tooltip_text(
        "Choose a built-in color theme"
    )
    quick_theme_combo.set_hexpand(True)

    quick_theme_button = Gtk.Button(
        label="Apply Built-in Theme"
    )
    quick_theme_button.connect(
        "clicked",
        lambda button: apply_builtin_theme(
            quick_theme_combo.get_active_text(),
            color_buttons,
            theme_name_label
        )
    )

    quick_theme_row.pack_start(
        quick_theme_combo, True, True, 0
    )
    quick_theme_row.pack_end(
        quick_theme_button, False, False, 0
    )
    settings_layout.pack_start(
        quick_theme_row, False, False, 0
    )

    theme_buttons = Gtk.Box(
        orientation=Gtk.Orientation.HORIZONTAL,
        spacing=8
    )

    save_theme_button = Gtk.Button(
        label="💾 Save .wntheme"
    )

    save_theme_button.set_hexpand(
        True
    )

    save_theme_button.connect(
        "clicked",
        lambda b:
            save_theme(
                settings_window
            )
    )

    load_theme_button = Gtk.Button(
        label="📂 Load .wntheme"
    )

    load_theme_button.set_hexpand(
        True
    )

    load_theme_button.connect(
        "clicked",
        lambda b:
            load_theme(
                settings_window,
                color_buttons,
                theme_name_label
            )
    )

    theme_buttons.pack_start(
        save_theme_button,
        True,
        True,
        0
    )

    theme_buttons.pack_start(
        load_theme_button,
        True,
        True,
        0
    )

    settings_layout.pack_start(
        theme_buttons,
        False,
        False,
        4
    )

    separator_search = Gtk.Separator(
        orientation=Gtk.Orientation.HORIZONTAL
    )

    settings_layout.pack_start(
        separator_search,
        False,
        False,
        8
    )

    search_label = Gtk.Label(label="🔍 Search Engine")
    search_label.set_xalign(0)
    settings_layout.pack_start(search_label, False, False, 0)

    search_engine_row = Gtk.Box(
        orientation=Gtk.Orientation.HORIZONTAL,
        spacing=8
    )

    current_engine = app_preferences.get(
        "search_engine",
        "Qwant"
    )
    if current_engine not in search_engines:
        current_engine = "Qwant"

    current_engine_label = Gtk.Label(
        label=current_engine
    )
    current_engine_label.set_xalign(0)
    current_engine_label.get_style_context().add_class(
        "dim-label"
    )
    search_engine_row.pack_start(
        current_engine_label,
        True,
        True,
        0
    )

    search_engine_button = Gtk.Button(
        label="Choose..."
    )
    search_engine_row.pack_end(
        search_engine_button,
        False,
        False,
        0
    )
    settings_layout.pack_start(
        search_engine_row,
        False,
        False,
        0
    )

    def select_search_engine(engine_name):
        if engine_name not in search_engines:
            return

        app_preferences["search_engine"] = engine_name
        save_preferences()
        current_engine_label.set_text(engine_name)
        reload_homepage_if_needed()

    search_engine_button.connect(
        "clicked",
        lambda _button: show_search_engine_chooser(
            settings_window,
            select_search_engine
        )
    )

    separator_adblock = Gtk.Separator(
        orientation=Gtk.Orientation.HORIZONTAL
    )

    settings_layout.pack_start(
        separator_adblock,
        False,
        False,
        8
    )

    adblock_label = Gtk.Label()
    adblock_label.set_markup(
        "<b>🛡 Ad Blocking</b>"
    )
    adblock_label.set_xalign(0)
    settings_layout.pack_start(
        adblock_label,
        False,
        False,
        0
    )

    adblock_check = Gtk.CheckButton(
        label="Block ads and trackers"
    )

    adblock_check.set_active(
        adblock_is_enabled()
    )

    adblock_check.set_tooltip_text(
        "Block known advertising and tracking hosts using "
        "WebKit content filters"
    )

    settings_layout.pack_start(
        adblock_check,
        False,
        False,
        0
    )

    cosmetic_check = Gtk.CheckButton(
        label="Hide leftover ad placeholders"
    )

    cosmetic_check.set_active(
        bool(
            app_preferences.get(
                "adblock_cosmetic",
                True
            )
        )
    )

    cosmetic_check.set_tooltip_text(
        "Apply a cosmetic stylesheet that hides empty ad slots"
    )

    settings_layout.pack_start(
        cosmetic_check,
        False,
        False,
        0
    )

    popup_check = Gtk.CheckButton(
        label="Block pop-up windows"
    )

    popup_check.set_active(
        bool(
            app_preferences.get(
                "block_popups",
                True
            )
        )
    )

    popup_check.set_tooltip_text(
        "Open links requested by a gesture in a new tab and "
        "suppress unsolicited pop-ups"
    )

    settings_layout.pack_start(
        popup_check,
        False,
        False,
        0
    )

    adblock_status = Gtk.Label()
    adblock_status.set_xalign(0)
    adblock_status.set_line_wrap(True)

    settings_layout.pack_start(
        adblock_status,
        False,
        False,
        0
    )

    def refresh_adblock_status():
        if not adblock_is_enabled():
            text = "Ad blocking is off."
        elif adblock_last_error:
            text = "Filter unavailable: " + adblock_last_error
        elif not hasattr(
            WebKit2,
            "UserContentFilterStore"
        ):
            text = (
                "This WebKit build has no content-filter support; "
                "cosmetic filters only."
            )
        else:
            text = (
                f"{len(get_blocked_domains())} blocked hosts • "
                f"{len(ADBLOCK_COSMETIC_SELECTORS)} cosmetic selectors"
            )

        adblock_status.set_text(text)

    def on_adblock_toggled(check):
        app_preferences["adblock_enabled"] = (
            check.get_active()
        )
        save_preferences()
        reload_adblock()
        refresh_adblock_status()

    def on_cosmetic_toggled(check):
        app_preferences["adblock_cosmetic"] = (
            check.get_active()
        )
        save_preferences()
        apply_adblock_to_all_tabs()

    def on_popup_toggled(check):
        app_preferences["block_popups"] = (
            check.get_active()
        )
        save_preferences()

    adblock_check.connect(
        "toggled",
        on_adblock_toggled
    )

    cosmetic_check.connect(
        "toggled",
        on_cosmetic_toggled
    )

    popup_check.connect(
        "toggled",
        on_popup_toggled
    )

    edit_blocklist_button = Gtk.Button(
        label="✏  Edit Custom Blocklist…"
    )

    edit_blocklist_button.connect(
        "clicked",
        lambda b: show_blocklist_editor(
            settings_window,
            refresh_adblock_status
        )
    )

    settings_layout.pack_start(
        edit_blocklist_button,
        False,
        False,
        0
    )

    refresh_adblock_status()

    separator_migration = Gtk.Separator(
        orientation=Gtk.Orientation.HORIZONTAL
    )

    settings_layout.pack_start(
        separator_migration,
        False,
        False,
        8
    )

    migration_label = Gtk.Label()
    migration_label.set_markup(
        "<b>📦 Migration</b>"
    )
    migration_label.set_xalign(0)
    settings_layout.pack_start(
        migration_label,
        False,
        False,
        0
    )

    migration_button = Gtk.Button(
        label="🧙  Migration Wizard…"
    )

    migration_button.set_tooltip_text(
        "Import history, bookmarks, and search settings "
        "from another browser"
    )

    migration_button.connect(
        "clicked",
        show_migration_wizard
    )

    settings_layout.pack_start(
        migration_button,
        False,
        False,
        0
    )

    bookmarks_button = Gtk.Button(
        label="🔖  Bookmarks"
    )

    bookmarks_button.set_tooltip_text(
        "View, add, and export bookmarks"
    )

    bookmarks_button.connect(
        "clicked",
        show_bookmarks
    )

    settings_layout.pack_start(
        bookmarks_button,
        False,
        False,
        0
    )

    separator2 = Gtk.Separator(
        orientation=Gtk.Orientation.HORIZONTAL
    )

    settings_layout.pack_start(
        separator2,
        False,
        False,
        8
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

    separator3 = Gtk.Separator(
        orientation=Gtk.Orientation.HORIZONTAL
    )

    settings_layout.pack_start(
        separator3,
        False,
        False,
        8
    )

    wip_label = Gtk.Label(
        label=(
            "2026.11.0 settings: ad blocking, migration, search engine, "
            "themes, bookmarks, history, and appearance."
        )
    )

    wip_label.set_xalign(
        0
    )

    wip_label.set_line_wrap(
        True
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

    settings_scroller = Gtk.ScrolledWindow()

    settings_scroller.set_policy(
        Gtk.PolicyType.NEVER,
        Gtk.PolicyType.AUTOMATIC
    )

    settings_scroller.add(
        settings_layout
    )

    settings_window.add(
        settings_scroller
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

btn_home.connect(
    "clicked",
    go_home
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

    ctrl_pressed = bool(
        event.state & Gdk.ModifierType.CONTROL_MASK
    )

    alt_pressed = bool(
        event.state & Gdk.ModifierType.MOD1_MASK
    )

    if ctrl_pressed:

        if event.keyval == Gdk.KEY_Tab:
            page_count = notebook.get_n_pages()
            if page_count > 1:
                current_page = notebook.get_current_page()
                if event.state & Gdk.ModifierType.SHIFT_MASK:
                    next_page = (current_page - 1) % page_count
                else:
                    next_page = (current_page + 1) % page_count
                notebook.set_current_page(next_page)
            return True

        if event.keyval == Gdk.KEY_l:
            url_entry.grab_focus()
            url_entry.select_region(0, -1)
            return True

        elif event.keyval == Gdk.KEY_t and bool(
            event.state & Gdk.ModifierType.SHIFT_MASK
        ):
            reopen_closed_tab()
            return True

        elif event.keyval == Gdk.KEY_t:
            create_new_tab()
            return True

        elif event.keyval == Gdk.KEY_w:
            browser = get_current_browser()
            if browser:
                scrolled = browser_to_tab.get(browser)
                if scrolled:
                    close_tab(None, scrolled)
            return True

        elif event.keyval == Gdk.KEY_r:
            on_reload_clicked(None)
            return True


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
            browser = get_current_browser()
            if browser:
                scrolled = browser_to_tab.get(browser)
                if scrolled:
                    close_tab(None, scrolled)
            return True

    return False

window.connect(
    "key-press-event",
    handle_shortcuts
)

if app_preferences.get("theme_mode") == "light":
    set_light_mode()
else:
    set_dark_mode()

initialize_adblock()

create_new_tab()

window.add(
    main_layout
)

window.show_all()

Gtk.main()

EOF
