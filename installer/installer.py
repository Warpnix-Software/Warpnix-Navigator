#!/usr/bin/env python3

import os
import shutil
import subprocess
import sys
import threading

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk, GLib, GdkPixbuf


APP_NAME = "Warpnix Navigator"
VERSION = "0.1.x"

# installer.sh passes the actual Warpnix-Navigator directory here
SOURCE_DIR = (
    os.path.abspath(sys.argv[1])
    if len(sys.argv) > 1
    else os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
)

DEFAULT_TARGET_DIR = os.path.expanduser(
    "~/.local/share/warpnix-navigator"
)

BIN_DIR = os.path.expanduser("~/.local/bin")
APPS_DIR = os.path.expanduser("~/.local/share/applications")
ICONS_DIR = os.path.expanduser(
    "~/.local/share/icons/hicolor/512x512/apps"
)

INSTALL_BIN = os.path.join(
    BIN_DIR,
    "warpnix-navigator"
)

DESKTOP_FILE = os.path.join(
    APPS_DIR,
    "warpnix-navigator.desktop"
)

ICON_FILE = os.path.join(
    ICONS_DIR,
    "warpnix-navigator.png"
)


class Installer(Gtk.Window):

    def __init__(self):
        super().__init__(
            title=f"{APP_NAME} Setup"
        )

        self.set_default_size(720, 470)
        self.set_resizable(False)
        self.set_position(
            Gtk.WindowPosition.CENTER
        )

        self.current_page = 0

        self.location_entry = None
        self.launcher_check = None
        self.icon_check = None
        self.launch_check = None

        self.apply_windows7_style()
        self.build_ui()

        # Build the first page.
        self.show_page(0)

        # Make absolutely sure every widget is visible.
        self.show_all()

    # =========================================================
    # Windows 7-ish styling
    # =========================================================

    def apply_windows7_style(self):

        css = b"""
        window {
            background-color: #f0f0f0;
        }

        .sidebar {
            background-color: #dbeaf7;
        }

        .title {
            font-size: 20px;
            color: #222222;
        }

        .subtitle {
            font-size: 13px;
            color: #555555;
        }

        .body {
            font-size: 13px;
            color: #333333;
        }

        .small {
            font-size: 11px;
            color: #666666;
        }

        button {
            min-width: 90px;
            min-height: 28px;
        }

        entry {
            min-height: 28px;
        }

        progressbar {
            min-height: 20px;
        }
        """

        provider = Gtk.CssProvider()

        try:
            provider.load_from_data(css)
        except Exception:
            pass

        screen = Gdk.Screen.get_default()

        if screen:
            Gtk.StyleContext.add_provider_for_screen(
                screen,
                provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

    # =========================================================
    # Main UI
    # =========================================================

    def build_ui(self):

        outer = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL
        )

        self.add(outer)

        # -----------------------------------------------------
        # Main content
        # -----------------------------------------------------

        content = Gtk.Box(
            orientation=Gtk.Orientation.HORIZONTAL
        )

        outer.pack_start(
            content,
            True,
            True,
            0
        )

        # -----------------------------------------------------
        # Sidebar
        # -----------------------------------------------------

        sidebar = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL,
            spacing=10
        )

        sidebar.set_size_request(
            190,
            -1
        )

        sidebar.get_style_context().add_class(
            "sidebar"
        )

        content.pack_start(
            sidebar,
            False,
            False,
            0
        )

        # Logo
        logo_path = os.path.join(
            SOURCE_DIR,
            "logo.png"
        )

        if os.path.exists(logo_path):

            try:
                pixbuf = (
                    GdkPixbuf.Pixbuf.new_from_file_at_scale(
                        logo_path,
                        110,
                        110,
                        True
                    )
                )

                logo = Gtk.Image.new_from_pixbuf(
                    pixbuf
                )

                sidebar.pack_start(
                    logo,
                    False,
                    False,
                    35
                )

            except Exception:
                pass

        # Brand
        brand = Gtk.Label()

        brand.set_markup(
            "<span foreground='#009fe3'><b>"
            "Warpnix Navigator"
            "</b></span>"
        )

        brand.set_xalign(0.5)

        sidebar.pack_start(
            brand,
            False,
            False,
            0
        )

        # Version
        version = Gtk.Label(
            label=f"Version {VERSION}"
        )

        version.get_style_context().add_class(
            "small"
        )

        version.set_xalign(0.5)

        sidebar.pack_start(
            version,
            False,
            False,
            0
        )

        # Spacer
        spacer = Gtk.Box()

        sidebar.pack_start(
            spacer,
            True,
            True,
            0
        )

        # Copyright
        powered = Gtk.Label(
            label="Warpnix Software"
        )

        powered.get_style_context().add_class(
            "small"
        )

        powered.set_xalign(0.5)

        sidebar.pack_start(
            powered,
            False,
            False,
            15
        )

        # -----------------------------------------------------
        # Right side
        # -----------------------------------------------------

        right = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL
        )

        content.pack_start(
            right,
            True,
            True,
            0
        )

        # Page container
        self.page_container = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL,
            spacing=10
        )

        self.page_container.set_border_width(
            28
        )

        right.pack_start(
            self.page_container,
            True,
            True,
            0
        )

        # -----------------------------------------------------
        # Separator
        # -----------------------------------------------------

        separator = Gtk.Separator(
            orientation=Gtk.Orientation.HORIZONTAL
        )

        right.pack_start(
            separator,
            False,
            False,
            0
        )

        # -----------------------------------------------------
        # Bottom buttons
        # -----------------------------------------------------

        buttons = Gtk.Box(
            orientation=Gtk.Orientation.HORIZONTAL,
            spacing=8
        )

        buttons.set_border_width(10)

        right.pack_start(
            buttons,
            False,
            False,
            0
        )

        # Cancel
        self.cancel_button = Gtk.Button(
            label="Cancel"
        )

        self.cancel_button.connect(
            "clicked",
            self.on_cancel
        )

        buttons.pack_end(
            self.cancel_button,
            False,
            False,
            0
        )

        # Next
        self.next_button = Gtk.Button(
            label="Next >"
        )

        self.next_button.connect(
            "clicked",
            self.on_next
        )

        buttons.pack_end(
            self.next_button,
            False,
            False,
            0
        )

        # Back
        self.back_button = Gtk.Button(
            label="< Back"
        )

        self.back_button.connect(
            "clicked",
            self.on_back
        )

        buttons.pack_end(
            self.back_button,
            False,
            False,
            0
        )

    # =========================================================
    # Page helpers
    # =========================================================

    def clear_page(self):

        children = (
            self.page_container.get_children()
        )

        for child in children:
            self.page_container.remove(
                child
            )

    def heading(
        self,
        title,
        subtitle
    ):

        title_label = Gtk.Label()

        title_label.set_markup(
            f"<span size='x-large'><b>"
            f"{title}"
            f"</b></span>"
        )

        title_label.set_xalign(0)

        self.page_container.pack_start(
            title_label,
            False,
            False,
            0
        )

        subtitle_label = Gtk.Label(
            label=subtitle
        )

        subtitle_label.get_style_context().add_class(
            "subtitle"
        )

        subtitle_label.set_xalign(0)

        self.page_container.pack_start(
            subtitle_label,
            False,
            False,
            4
        )

        separator = Gtk.Separator(
            orientation=Gtk.Orientation.HORIZONTAL
        )

        self.page_container.pack_start(
            separator,
            False,
            False,
            8
        )

    def body_label(self, text):

        label = Gtk.Label(
            label=text
        )

        label.set_xalign(0)
        label.set_line_wrap(True)

        label.get_style_context().add_class(
            "body"
        )

        self.page_container.pack_start(
            label,
            False,
            False,
            5
        )

        return label

    # =========================================================
    # Page management
    # =========================================================

    def show_page(self, page):

        self.current_page = page

        self.clear_page()

        # Re-enable normal controls first.
        self.cancel_button.set_sensitive(True)
        self.back_button.set_sensitive(True)
        self.next_button.set_sensitive(True)

        # Build requested page.
        if page == 0:
            self.page_welcome()

        elif page == 1:
            self.page_location()

        elif page == 2:
            self.page_components()

        elif page == 3:
            self.page_ready()

        elif page == 4:
            self.page_installing()

        elif page == 5:
            self.page_finished()

        # Navigation state.
        self.back_button.set_sensitive(
            page > 0 and page != 4 and page != 5
        )

        if page == 3:
            self.next_button.set_label(
                "Install"
            )

        elif page == 5:
            self.next_button.set_label(
                "Finish"
            )

        elif page == 4:
            self.next_button.set_label(
                "Installing..."
            )

        else:
            self.next_button.set_label(
                "Next >"
            )

        # THIS IS THE IMPORTANT PART.
        # Newly-created widgets are explicitly shown.
        self.page_container.show_all()

    # =========================================================
    # Page 0
    # =========================================================

    def page_welcome(self):

        self.heading(
            "Welcome to the Warpnix Navigator Setup Wizard",
            "This wizard will install Warpnix Navigator on your computer."
        )

        self.body_label(
            "Warpnix Navigator is a lightweight, "
            "privacy-focused web browser from Warpnix Software."
        )

        self.body_label(
            "Click Next to continue, or Cancel to exit Setup."
        )

    # =========================================================
    # Page 1
    # =========================================================

    def page_location(self):

        self.heading(
            "Choose Installation Location",
            "Select where Warpnix Navigator should store its files."
        )

        self.body_label(
            "Warpnix Navigator will be installed for "
            "the current user."
        )

        self.location_entry = Gtk.Entry()

        self.location_entry.set_text(
            DEFAULT_TARGET_DIR
        )

        self.page_container.pack_start(
            self.location_entry,
            False,
            False,
            8
        )

        note = Gtk.Label(
            label="No administrator privileges are required."
        )

        note.get_style_context().add_class(
            "small"
        )

        note.set_xalign(0)

        self.page_container.pack_start(
            note,
            False,
            False,
            0
        )

    # =========================================================
    # Page 2
    # =========================================================

    def page_components(self):

        self.heading(
            "Select Components",
            "Choose which components you want to install."
        )

        self.browser_check = Gtk.CheckButton(
            label="Warpnix Navigator"
        )

        self.browser_check.set_active(True)
        self.browser_check.set_sensitive(False)

        self.page_container.pack_start(
            self.browser_check,
            False,
            False,
            5
        )

        self.launcher_check = Gtk.CheckButton(
            label="Application launcher"
        )

        self.launcher_check.set_active(True)

        self.page_container.pack_start(
            self.launcher_check,
            False,
            False,
            5
        )

        self.icon_check = Gtk.CheckButton(
            label="Application icon"
        )

        self.icon_check.set_active(True)

        self.page_container.pack_start(
            self.icon_check,
            False,
            False,
            5
        )

    # =========================================================
    # Page 3
    # =========================================================

    def page_ready(self):

        self.heading(
            "Ready to Install",
            "Setup is now ready to install Warpnix Navigator."
        )

        target = DEFAULT_TARGET_DIR

        if self.location_entry is not None:
            target = self.location_entry.get_text()

        self.body_label(
            f"Destination:\n{target}"
        )

        self.body_label(
            "The installer will copy the browser files, "
            "create the command-line launcher, and register "
            "Warpnix Navigator with your desktop environment."
        )

        self.body_label(
            "Click Install to begin."
        )

    # =========================================================
    # Page 4
    # =========================================================

    def page_installing(self):

        self.heading(
            "Installing Warpnix Navigator",
            "Please wait while Setup installs the application."
        )

        self.status_label = Gtk.Label(
            label="Preparing installation..."
        )

        self.status_label.set_xalign(0)

        self.page_container.pack_start(
            self.status_label,
            False,
            False,
            15
        )

        self.progress = Gtk.ProgressBar()

        self.progress.set_fraction(0.0)

        self.page_container.pack_start(
            self.progress,
            False,
            False,
            5
        )

        # Disable navigation while installing.
        self.next_button.set_sensitive(False)
        self.back_button.set_sensitive(False)
        self.cancel_button.set_sensitive(False)

        # Save component choices BEFORE entering
        # the worker thread. GTK should not be accessed
        # from the worker thread.
        install_options = {
            "target": (
                self.location_entry.get_text()
                if self.location_entry
                else DEFAULT_TARGET_DIR
            ),
            "launcher": (
                self.launcher_check.get_active()
                if self.launcher_check
                else True
            ),
            "icon": (
                self.icon_check.get_active()
                if self.icon_check
                else True
            )
        }

        threading.Thread(
            target=self.install,
            args=(install_options,),
            daemon=True
        ).start()

    # =========================================================
    # Page 5
    # =========================================================

    def page_finished(self):

        self.heading(
            "Installation Complete",
            "Warpnix Navigator has been successfully installed."
        )

        self.body_label(
            "Warpnix Navigator is now ready to use."
        )

        self.launch_check = Gtk.CheckButton(
            label="Launch Warpnix Navigator"
        )

        self.launch_check.set_active(True)

        self.page_container.pack_start(
            self.launch_check,
            False,
            False,
            15
        )

        self.next_button.set_label(
            "Finish"
        )

        self.back_button.set_sensitive(
            False
        )

    # =========================================================
    # Installation
    # =========================================================

    def set_status(
        self,
        text,
        fraction
    ):

        GLib.idle_add(
            self.status_label.set_text,
            text
        )

        GLib.idle_add(
            self.progress.set_fraction,
            fraction
        )

    def install(
        self,
        options
    ):

        try:

            install_target = os.path.expanduser(
                options["target"]
            )

            launcher_enabled = options[
                "launcher"
            ]

            icon_enabled = options[
                "icon"
            ]

            # -------------------------------------------------
            # Create directories
            # -------------------------------------------------

            self.set_status(
                "Creating installation directories...",
                0.05
            )

            os.makedirs(
                install_target,
                exist_ok=True
            )

            os.makedirs(
                BIN_DIR,
                exist_ok=True
            )

            os.makedirs(
                APPS_DIR,
                exist_ok=True
            )

            os.makedirs(
                ICONS_DIR,
                exist_ok=True
            )

            # -------------------------------------------------
            # Check source files
            # -------------------------------------------------

            logo_source = os.path.join(
                SOURCE_DIR,
                "logo.png"
            )

            browser_source = os.path.join(
                SOURCE_DIR,
                "wn_beta.sh"
            )

            if not os.path.isfile(
                browser_source
            ):
                raise FileNotFoundError(
                    f"Could not find:\n{browser_source}"
                )

            if not os.path.isfile(
                logo_source
            ):
                raise FileNotFoundError(
                    f"Could not find:\n{logo_source}"
                )

            # -------------------------------------------------
            # Browser files
            # -------------------------------------------------

            self.set_status(
                "Copying Warpnix Navigator files...",
                0.15
            )

            shutil.copy2(
                logo_source,
                os.path.join(
                    install_target,
                    "logo.png"
                )
            )

            shutil.copy2(
                browser_source,
                os.path.join(
                    install_target,
                    "wn_beta.sh"
                )
            )

            os.chmod(
                os.path.join(
                    install_target,
                    "wn_beta.sh"
                ),
                0o755
            )

            # -------------------------------------------------
            # Command-line launcher
            # -------------------------------------------------

            self.set_status(
                "Creating application launcher...",
                0.40
            )

            wrapper = (
                "#!/bin/bash\n"
                f'exec "{install_target}/wn_beta.sh" "$@"\n'
            )

            with open(
                INSTALL_BIN,
                "w"
            ) as f:
                f.write(wrapper)

            os.chmod(
                INSTALL_BIN,
                0o755
            )

            # -------------------------------------------------
            # Application icon
            # -------------------------------------------------

            if icon_enabled:

                self.set_status(
                    "Installing application icon...",
                    0.60
                )

                shutil.copy2(
                    logo_source,
                    ICON_FILE
                )

            # -------------------------------------------------
            # Desktop launcher
            # -------------------------------------------------

            if launcher_enabled:

                self.set_status(
                    "Creating application menu entry...",
                    0.75
                )

                desktop = (
                    "[Desktop Entry]\n"
                    "Version=1.0\n"
                    "Type=Application\n"
                    "Name=Warpnix Navigator\n"
                    "Comment=Lightweight, privacy-focused web browser\n"
                    f"Exec={INSTALL_BIN}\n"
                    "Icon=warpnix-navigator\n"
                    "Terminal=false\n"
                    "Categories=Network;WebBrowser;\n"
                    "Keywords=browser;web;internet;warpnix;qwant;\n"
                )

                with open(
                    DESKTOP_FILE,
                    "w"
                ) as f:
                    f.write(desktop)

                os.chmod(
                    DESKTOP_FILE,
                    0o755
                )

            # -------------------------------------------------
            # Desktop database
            # -------------------------------------------------

            self.set_status(
                "Updating desktop application database...",
                0.88
            )

            try:

                subprocess.run(
                    [
                        "update-desktop-database",
                        APPS_DIR
                    ],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    check=False
                )

            except FileNotFoundError:
                pass

            # -------------------------------------------------
            # Icon cache
            # -------------------------------------------------

            self.set_status(
                "Refreshing application icons...",
                0.94
            )

            try:

                subprocess.run(
                    [
                        "gtk-update-icon-cache",
                        "-f",
                        "-t",
                        os.path.expanduser(
                            "~/.local/share/icons/hicolor"
                        )
                    ],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    check=False
                )

            except FileNotFoundError:
                pass

            # -------------------------------------------------
            # Finished
            # -------------------------------------------------

            self.set_status(
                "Installation complete.",
                1.0
            )

            GLib.idle_add(
                self.install_finished
            )

        except Exception as e:

            GLib.idle_add(
                self.install_failed,
                str(e)
            )

    # =========================================================
    # Installation result
    # =========================================================

    def install_finished(self):

        self.show_page(5)

    def install_failed(
        self,
        error
    ):

        dialog = Gtk.MessageDialog(
            transient_for=self,
            flags=Gtk.DialogFlags.MODAL,
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK,
            text="Installation Failed"
        )

        dialog.format_secondary_text(
            error
        )

        dialog.run()
        dialog.destroy()

        self.current_page = 3

        self.show_page(3)

    # =========================================================
    # Navigation
    # =========================================================

    def on_next(
        self,
        button
    ):

        if self.current_page == 0:

            self.show_page(1)

        elif self.current_page == 1:

            self.show_page(2)

        elif self.current_page == 2:

            self.show_page(3)

        elif self.current_page == 3:

            self.show_page(4)

        elif self.current_page == 5:

            should_launch = (
                self.launch_check
                and self.launch_check.get_active()
            )

            if should_launch:

                try:

                    subprocess.Popen(
                        [INSTALL_BIN],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL
                    )

                except Exception:
                    pass

            Gtk.main_quit()

    def on_back(
        self,
        button
    ):

        if self.current_page > 0:

            self.show_page(
                self.current_page - 1
            )

    def on_cancel(
        self,
        button
    ):

        Gtk.main_quit()


# =============================================================
# Main
# =============================================================

def main():

    installer = Installer()

    installer.connect(
        "destroy",
        Gtk.main_quit
    )

    installer.show_all()

    Gtk.main()


if __name__ == "__main__":
    main()
