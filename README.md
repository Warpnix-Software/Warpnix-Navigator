## Warpnix Navigator
The very first step in the war against Chrome and Edge.

## Overview
Warpnix Navigator is the web browser in the Warpnix family of open-source software, which also includes WarpnixOS (github.com/Warpnix-Software/WarpnixOS). 

## Installing:
Warpnix Navigator is currently Linux-exclusive. Before installing, make sure you have all dependencies installed:

# Debian / Ubuntu / Linux Mint

sudo apt install python3 python3-gi python3-gi-cairo gir1.2-gtk-3.0 gir1.2-webkit2-4.1 zenity

# Fedora / RHEL

sudo dnf install python3 python3-gobject gtk3 webkit2gtk4.1 zenity

# Arch Linux

sudo pacman -S python python-gobject gtk3 webkit2gtk zenity

Then clone the repository:

git clone github.com/Warpnix-Software/Warpnix-Navigator.git
cd Warpnix-Navigator

Then make the app executable:

sudo chmod +x wn_beta.sh

Then run the application:

./wn_beta.sh

## Current Status: Alpha/WIP
Use Warpnix Navigator while it's being developed! We are currently in very early Alpha stages, so stay tuned for new features!

## Changelog
0.1.0
The premiere release of Warpnix Navigator. No back, forward, or reload buttons yet, but those will be added soon. For now, you can use Alt+R, Alt+Left Arrow, and Alt+Right Arrow. 
