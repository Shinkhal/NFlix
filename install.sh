#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PREFIX=${1:-"$HOME/.local"}
mkdir -p "$PREFIX"
PREFIX=$(CDPATH= cd -- "$PREFIX" && pwd -P)
if [ "$PREFIX" = "/" ]; then
    echo "Refusing to install into the filesystem root." >&2
    exit 1
fi

APP_DIR="$PREFIX/lib/nflix-desktop"
BIN_DIR="$PREFIX/bin"
DESKTOP_DIR="$PREFIX/share/applications"
ICON_DIR_48="$PREFIX/share/icons/hicolor/48x48/apps"
ICON_DIR_512="$PREFIX/share/icons/hicolor/512x512/apps"
METAINFO_DIR="$PREFIX/share/metainfo"
LICENSE_DIR="$PREFIX/share/licenses/nflix-desktop"
DESKTOP_FILE="io.github.nflixdesktop.desktop"
ICON_NAME="io.github.nflixdesktop"

install -d "$APP_DIR" "$BIN_DIR" "$DESKTOP_DIR" "$ICON_DIR_48" "$ICON_DIR_512" "$METAINFO_DIR" "$LICENSE_DIR"

if [ -f "$SCRIPT_DIR/pyproject.toml" ] && [ -f "$SCRIPT_DIR/nflix_desktop.py" ]; then
    # Source checkout install: keep the Python runtime separate from user data.
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Python 3 is required to install Nflix Desktop from source." >&2
        exit 1
    fi
    if [ ! -x "$APP_DIR/venv/bin/python" ]; then
        python3 -m venv "$APP_DIR/venv"
    fi
    "$APP_DIR/venv/bin/python" -m pip install "$SCRIPT_DIR"
    install -m 755 "$SCRIPT_DIR/bin/nflix-desktop" "$BIN_DIR/nflix-desktop"
    install -m 644 "$SCRIPT_DIR/$DESKTOP_FILE" "$DESKTOP_DIR/$DESKTOP_FILE"
    install -m 644 "$SCRIPT_DIR/io.github.nflixdesktop.metainfo.xml" "$METAINFO_DIR/$ICON_NAME.metainfo.xml"
    install -m 644 "$SCRIPT_DIR/LICENSE" "$LICENSE_DIR/LICENSE"
    install -m 644 "$SCRIPT_DIR/THIRD_PARTY_NOTICES.md" "$LICENSE_DIR/THIRD_PARTY_NOTICES.md"
    install -m 644 "$SCRIPT_DIR/assets/icon-48.png" "$ICON_DIR_48/$ICON_NAME.png"
    install -m 644 "$SCRIPT_DIR/assets/icon-512.png" "$ICON_DIR_512/$ICON_NAME.png"
else
    # Release archive install: copy the already-built standalone runtime.
    if [ ! -x "$SCRIPT_DIR/lib/nflix-desktop/nflix_desktop.bin" ]; then
        echo "Run this from the source checkout or an extracted Nflix Desktop release bundle." >&2
        exit 1
    fi
    cp -a "$SCRIPT_DIR/lib/nflix-desktop/." "$APP_DIR/"
    install -m 755 "$SCRIPT_DIR/bin/nflix-desktop" "$BIN_DIR/nflix-desktop"
    install -m 644 "$SCRIPT_DIR/$DESKTOP_FILE" "$DESKTOP_DIR/$DESKTOP_FILE"
    install -m 644 "$SCRIPT_DIR/io.github.nflixdesktop.metainfo.xml" "$METAINFO_DIR/$ICON_NAME.metainfo.xml"
    install -m 644 "$SCRIPT_DIR/LICENSE" "$LICENSE_DIR/LICENSE"
    install -m 644 "$SCRIPT_DIR/THIRD_PARTY_NOTICES.md" "$LICENSE_DIR/THIRD_PARTY_NOTICES.md"
    install -m 644 "$SCRIPT_DIR/assets/icon-48.png" "$ICON_DIR_48/$ICON_NAME.png"
    install -m 644 "$SCRIPT_DIR/assets/icon-512.png" "$ICON_DIR_512/$ICON_NAME.png"
fi

# Remove the pre-release desktop ID used by an earlier test install.
rm -f "$DESKTOP_DIR/io.github.nflixdesktop.desktop.desktop"
rm -f "$METAINFO_DIR/io.github.nflixdesktop.desktop.metainfo.xml"
rm -f "$ICON_DIR_48/io.github.nflixdesktop.desktop.png" "$ICON_DIR_512/io.github.nflixdesktop.desktop.png"

sed "s|^Exec=.*|Exec=\"$BIN_DIR/nflix-desktop\"|; s|^TryExec=.*|TryExec=\"$BIN_DIR/nflix-desktop\"|" \
    "$DESKTOP_DIR/$DESKTOP_FILE" > "$DESKTOP_DIR/$DESKTOP_FILE.tmp"
mv "$DESKTOP_DIR/$DESKTOP_FILE.tmp" "$DESKTOP_DIR/$DESKTOP_FILE"
chmod 644 "$DESKTOP_DIR/$DESKTOP_FILE"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache --force --ignore-theme-index "$PREFIX/share/icons/hicolor" >/dev/null 2>&1 || true
fi

echo "Installed Nflix Desktop to $PREFIX"
echo "Launch it from the applications menu or with: $BIN_DIR/nflix-desktop"
