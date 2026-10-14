 # Warpnix Navigator
> The very first step in the war against Chrome and Edge.

Warpnix Navigator is a hyper-lightweight, minimalist deGoogled web browser built for the Warpnix family of open-source software (including [WarpnixOS](https://github.com/Warpnix-Software/WarpnixOS)). Built using **Python**, **Bash**, **GTK3**, and **WebKit**, it strips away mainstream browser bloat (I'm lookin' at you, Chrome!) for a fast, system-native experience.

---

## Preview
![Preview, Warpnix Navigator running on Zorin OS 18 with Cinnamon Desktop](PREVIEW.png)   

---

## Security by Default
* **Hardened Privacy:** Automatically denies and blocks all background webpage access requests to your system camera, microphone, and geolocation out of the box.
* **Lightweight Architecture:** Uses the native WebKit2GTK rendering engine to keep RAM consumption incredibly low, using just under 200 megabytes of memory on idle.

## Installing

Warpnix Navigator is currently Linux-exclusive. Install the required system dependencies for your distribution:

### Debian / Ubuntu / Linux Mint
```bash
sudo apt install python3 python3-gi python3-gi-cairo gir1.2-gtk-3.0 gir1.2-webkit2-4.1 zenity
```

### Fedora / RHEL / Fedora Atomic
```bash
sudo dnf install python3 python3-gobject gtk3-devel webkit2gtk4.1-devel zenity
```
OR
```bash
rpm-ostree install python3 python3-gobject gtk3-devel webkit2gtk4.1-devel zenity
```
### Arch Linux
```bash
sudo pacman -S python-gobject python-cairo gtk3 webkit2gtk-4.1 zenity
```

### Setup & Execution
Clone the repository, make the script executable, and run the browser:

```bash
git clone https://github.com/Warpnix-Software/Warpnix-Navigator.git
cd Warpnix-Navigator
chmod +x wn_beta.sh
./wn_beta.sh
```

---

## Keyboard Shortcuts
* `Ctrl` + `L`: Focus and select the address bar
* `Ctrl` + `T`: Open a new tab
* `Ctrl` + `W`: Close the active tab
* `Ctrl` + `R`: Reload the page
* `Ctrl` + `Shift` + `T`: Reopen the most recently closed tab
* `Alt` + `T`: Open a new tab
* `Alt` + `W`: Close the active tab
* `Alt` + `R`: Reload the page
* `Alt` + `Left Arrow`: Go back
* `Alt` + `Right Arrow`: Go forward

---

## Roadmap

### 2026.10 — In development

Implemented:
- GUI uninstaller with confirmation; browser settings and history are preserved.
- Haiku-style page-load error screen with a retry link.
- Built-in Oceanic Blue and Forest Night themes.
- About dialog using Zenity when available, with a GTK fallback.
- Installer version label updated to 2026.10; missing logos no longer break desktop-entry creation.

Still planned:
- General bug fixes and reliability improvements.
- Performance improvements for older hardware.
- Video-streaming performance improvements.
- Further settings-menu polish.

### Longer-term goals

- **0.2.x:** Explore support for macOS and improve portability.
- **0.3.x:** Explore BSD support.
- **0.4.x and beyond:** Investigate Windows, ReactOS, and Haiku support.

## Contributing
Warpnix Navigator is licensed under the GPL-3.0 License. Bug reports and feature requests are completely welcome—feel free to open an issue or submit a pull request!

## Find me on YouTube @WarpdevOfficial

### Thanks for using Warpnix Navigator!
