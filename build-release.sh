#!/usr/bin/env bash
# Build downloadable release archives for Linux and BSD.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(awk '/^# Warpnix Navigator /{print $NF; exit}' "$ROOT/wn_beta.sh")"

if [ -z "$VERSION" ]; then
    echo "Could not determine the Warpnix Navigator version." >&2
    exit 1
fi

if ! command -v zip >/dev/null 2>&1; then
    echo "The 'zip' command is required to build release archives." >&2
    exit 1
fi

STAGE_ROOT="$(mktemp -d)"
trap 'rm -rf "$STAGE_ROOT"' EXIT

FILES=(
    wn_beta.sh
    README.md
    CHANGELOG.md
    LICENSE
    uninstall.sh
    PREVIEW.png
)

if [ -f "$ROOT/logo.png" ]; then
    FILES+=(logo.png)
fi

for PLATFORM in Linux BSD; do
    BUNDLE_NAME="Warpnix-Navigator-$VERSION-$PLATFORM"
    BUNDLE_DIR="$STAGE_ROOT/$BUNDLE_NAME"
    OUTPUT_DIR="$ROOT/releases/$VERSION/$PLATFORM"
    OUTPUT_ZIP="$OUTPUT_DIR/$BUNDLE_NAME.zip"

    mkdir -p "$BUNDLE_DIR" "$OUTPUT_DIR"

    for FILE in "${FILES[@]}"; do
        cp "$ROOT/$FILE" "$BUNDLE_DIR/"
    done

    cp -R "$ROOT/installer" "$BUNDLE_DIR/installer"
    rm -rf "$BUNDLE_DIR/installer/__pycache__"
    find "$BUNDLE_DIR" -name "*.pyc" -delete

    chmod +x "$BUNDLE_DIR/wn_beta.sh" \
        "$BUNDLE_DIR/uninstall.sh" \
        "$BUNDLE_DIR/installer/installer.sh"

    rm -f "$OUTPUT_ZIP"
    (
        cd "$STAGE_ROOT"
        zip -qr "$OUTPUT_ZIP" "$BUNDLE_NAME"
    )

    echo "Built $OUTPUT_ZIP"
done
