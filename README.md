# Warpnix Navigator

The very first step in the war against Chrome and Edge.

## Overview

Warpnix Navigator is the web browser in the Warpnix family of open-source software, which also includes [WarpnixOS](https://github.com/Warpnix-Software/WarpnixOS).

## Installing

Warpnix Navigator is currently Linux-exclusive. Before installing, make sure you have all dependencies installed:

### Debian / Ubuntu / Linux Mint
```bash
sudo apt install python3 python3-gi python3-gi-cairo gir1.2-gtk-3.0 gir1.2-webkit2-4.1 zenity
```

### Fedora / RHEL
```bash
sudo dnf install python3 python3-gobject gtk3 webkit2gtk4.1 zenity
```

### Arch Linux
```bash
sudo pacman -S python python-gobject gtk3 webkit2gtk zenity
```

### Setup & Execution

Clone the repository, make the script executable, and run the engine:

```bash
git clone https://github.com/Warpnix-Software/Warpnix-Navigator.git
cd Warpnix-Navigator
chmod +x wn_beta.sh
./wn_beta.sh
```

## Current Status: Alpha/WIP

Use Warpnix Navigator while it's being developed! We are currently in very early Alpha stages, so stay tuned for new features.

## Roadmap

Warpnix Navigator is currently Linux-exclusive, with plans to expand support to additional operating systems as development progresses.

0.2.x — BSD Support

Expand Warpnix Navigator to BSD-based operating systems.

Improve portability across Unix-like platforms.

0.3.x — macOS Support

Bring Warpnix Navigator to macOS.

Adapt platform integration and interface behavior where necessary.

0.4.x and Beyond — Additional Platforms

Future platform targets include:

Windows
 
ReactOS

Haiku
 
 
These are long-term development goals and may change as the project evolves.

## Changelog
### 0.1.4
* **Fixed graphical glitches:** Fixed the flickering and artifacts when clicking buttons on the homepage.
* **Added tabs:** Added a new tab engine so you can open multiple websites at once.
* **Tab close buttons:** Added a working close button (X) on every tab.
* **Smart tab names:** Tab names automatically show the website title and stay neatly sized.
* **New shortcuts:** Added `Alt` + `T` to open a new tab and `Alt` + `W` to close the active tab.
* **Fixed startup crash:** Fixed a path bug that caused the browser to crash when launched on some Linux systems.

### 0.1.3
Added a simple WIP homepage and WIP installer (both will be improved later in development, probably around 0.2.x.
The installer runs in terminal at the moment, however it will be made graphical later on.

### 0.1.2
Patched system security by binding an explicit permission listener that automatically denies and blocks webpage access requests to the system camera, microphone, and geolocation.


### 0.1.1
* Added physical Back, Forward, and Reload buttons directly into the top pane navigation layout.
* Implemented dynamic interface sensitivity states to grey out history buttons when no routing states exist.


### 0.1.0
The premiere release of Warpnix Navigator. No back, forward, or reload buttons yet, but those will be added soon. For now, you can use keyboard shortcuts:

* `Alt` + `R` : Reload page
* `Alt` + `Left Arrow` : Go back
* `Alt` + `Right Arrow` : Go forward

## Thank you for using Warpnix Navigator.
