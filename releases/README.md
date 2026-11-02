# Releases

Downloadable archives for each Warpnix Navigator release live here.

## Layout

```
releases/
  <version>/
    Linux/Warpnix-Navigator-<version>-Linux.zip
    BSD/Warpnix-Navigator-<version>-BSD.zip
```

Each archive contains the browser, installer, uninstaller, README, changelog, license, preview image, and installer files inside a single versioned folder. Extract the archive and run `./installer/installer.sh` or `./wn_beta.sh`.

## Current release

### 2026.11.0

- [Linux archive](2026.11.0/Linux/Warpnix-Navigator-2026.11.0-Linux.zip)
- [BSD archive](2026.11.0/BSD/Warpnix-Navigator-2026.11.0-BSD.zip)

## Building new archives

From the repository root:

```bash
./build-release.sh
```

The script reads the version from `wn_beta.sh` and writes fresh Linux and BSD archives to `releases/<version>/`.
