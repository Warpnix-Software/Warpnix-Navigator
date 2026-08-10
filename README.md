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

## Changelog

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
