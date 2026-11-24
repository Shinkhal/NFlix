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

DATA_HOME=${XDG_DATA_HOME:-"$PREFIX/share"}
case "$DATA_HOME" in
    /*) ;;
    *)
        echo "XDG_DATA_HOME must be an absolute path: $DATA_HOME" >&2
        exit 1
        ;;
esac
mkdir -p "$DATA_HOME"
DATA_HOME=$(CDPATH= cd -- "$DATA_HOME" && pwd -P)
if [ "$DATA_HOME" = "/" ]; then
    echo "Refusing to install application data into the filesystem root." >&2
    exit 1
fi

APP_DIR="$PREFIX/lib/nflix-desktop"
BIN_DIR="$PREFIX/bin"
DESKTOP_DIR="$DATA_HOME/applications"
ICON_DIR_48="$DATA_HOME/icons/hicolor/48x48/apps"
ICON_DIR_512="$DATA_HOME/icons/hicolor/512x512/apps"
METAINFO_DIR="$DATA_HOME/metainfo"
LICENSE_DIR="$DATA_HOME/licenses/nflix-desktop"
DESKTOP_FILE="io.github.nflixdesktop.desktop"
APP_ID="io.github.nflixdesktop"
ICON_NAME="nflix-desktop"

install -d "$APP_DIR" "$BIN_DIR" "$DESKTOP_DIR" "$ICON_DIR_48" "$ICON_DIR_512" "$METAINFO_DIR" "$LICENSE_DIR"

# Validate menu and icon files before the potentially long dependency install.
for required_file in \
    "$SCRIPT_DIR/bin/nflix-desktop" \
    "$SCRIPT_DIR/$DESKTOP_FILE" \
    "$SCRIPT_DIR/io.github.nflixdesktop.metainfo.xml" \
    "$SCRIPT_DIR/LICENSE" \
    "$SCRIPT_DIR/THIRD_PARTY_NOTICES.md" \
    "$SCRIPT_DIR/assets/icon-48.png" \
    "$SCRIPT_DIR/assets/icon-512.png"
do
    if [ ! -f "$required_file" ]; then
        echo "Installer is incomplete; missing: $required_file" >&2
        exit 1
    fi
done

if [ -f "$SCRIPT_DIR/pyproject.toml" ] && [ -f "$SCRIPT_DIR/nflix_desktop.py" ]; then
    # Preserve the selected runtime on subsequent reinstalls.
    RUNTIME=${NFLIX_RUNTIME:-}
    if [ -z "$RUNTIME" ] && [ -f "$APP_DIR/runtime" ]; then
        RUNTIME=$(cat "$APP_DIR/runtime")
    fi
    RUNTIME=${RUNTIME:-wheel}
    case "$RUNTIME" in
        system)
            # Distribution bindings and Qt must be installed together.
            SYSTEM_PYTHON=/usr/bin/python3
            if ! "$SYSTEM_PYTHON" -I -c '
import PySide6
from PySide6.QtCore import qVersion
from PySide6.QtWebEngineCore import QWebEnginePage
from PySide6.QtWebEngineWidgets import QWebEngineView
assert PySide6.__version__.split(".")[:2] == qVersion().split(".")[:2]
' ; then
                echo "Install matching system PySide6 and Qt WebEngine packages first." >&2
                exit 1
            fi
            install -m 644 "$SCRIPT_DIR/nflix_desktop.py" "$APP_DIR/nflix_desktop.py"
            install -m 644 "$SCRIPT_DIR/app_resources.py" "$APP_DIR/app_resources.py"
            install -d "$APP_DIR/scripts"
            install -m 644 "$SCRIPT_DIR/scripts/check-playback.py" "$APP_DIR/scripts/check-playback.py"
            ;;
        wheel)
            if ! command -v python3 >/dev/null 2>&1; then
                echo "Python 3 is required to install Nflix Desktop from source." >&2
                exit 1
            fi
            if [ ! -x "$APP_DIR/venv/bin/python" ]; then
                python3 -m venv "$APP_DIR/venv"
            fi
            # Always reinstall the application: a successful import does not mean
            # the installed copy contains the changes in this checkout.
            PIP_LOG=$(mktemp "${TMPDIR:-/tmp}/nflix-desktop-pip.XXXXXX")
            if ! PIP_PROGRESS_BAR=off PIP_DISABLE_PIP_VERSION_CHECK=1 \
                "$APP_DIR/venv/bin/python" -m pip install --no-input --quiet "$SCRIPT_DIR" \
                >"$PIP_LOG" 2>&1; then
                echo "Could not install Nflix Desktop dependencies. Details:" >&2
                tail -n 20 "$PIP_LOG" >&2 || cat "$PIP_LOG" >&2
                rm -f "$PIP_LOG"
                exit 1
            fi
            rm -f "$PIP_LOG"
            ;;
        *)
            echo "NFLIX_RUNTIME must be system or wheel." >&2
            exit 1
            ;;
    esac
    printf '%s\n' "$RUNTIME" > "$APP_DIR/runtime"
    install -m 755 "$SCRIPT_DIR/bin/nflix-desktop" "$BIN_DIR/nflix-desktop"
    install -m 644 "$SCRIPT_DIR/$DESKTOP_FILE" "$DESKTOP_DIR/$DESKTOP_FILE"
    install -m 644 "$SCRIPT_DIR/io.github.nflixdesktop.metainfo.xml" "$METAINFO_DIR/$APP_ID.metainfo.xml"
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
    printf '%s\n' standalone > "$APP_DIR/runtime"
    install -m 755 "$SCRIPT_DIR/bin/nflix-desktop" "$BIN_DIR/nflix-desktop"
    install -m 644 "$SCRIPT_DIR/$DESKTOP_FILE" "$DESKTOP_DIR/$DESKTOP_FILE"
    install -m 644 "$SCRIPT_DIR/io.github.nflixdesktop.metainfo.xml" "$METAINFO_DIR/$APP_ID.metainfo.xml"
    install -m 644 "$SCRIPT_DIR/LICENSE" "$LICENSE_DIR/LICENSE"
    install -m 644 "$SCRIPT_DIR/THIRD_PARTY_NOTICES.md" "$LICENSE_DIR/THIRD_PARTY_NOTICES.md"
    install -m 644 "$SCRIPT_DIR/assets/icon-48.png" "$ICON_DIR_48/$ICON_NAME.png"
    install -m 644 "$SCRIPT_DIR/assets/icon-512.png" "$ICON_DIR_512/$ICON_NAME.png"
fi

# Remove the pre-release desktop ID used by an earlier test install.
rm -f "$DESKTOP_DIR/io.github.nflixdesktop.desktop.desktop"
rm -f "$METAINFO_DIR/io.github.nflixdesktop.desktop.metainfo.xml"
rm -f "$ICON_DIR_48/io.github.nflixdesktop.desktop.png" "$ICON_DIR_512/io.github.nflixdesktop.desktop.png"
rm -f "$ICON_DIR_48/io.github.nflixdesktop.png" "$ICON_DIR_512/io.github.nflixdesktop.png"

DESKTOP_EXEC=$(printf '%s' "$BIN_DIR/nflix-desktop" | sed 's/[&|]/\\&/g')
sed "s|^Exec=.*|Exec=$DESKTOP_EXEC|; s|^TryExec=.*|TryExec=$DESKTOP_EXEC|" \
    "$DESKTOP_DIR/$DESKTOP_FILE" > "$DESKTOP_DIR/$DESKTOP_FILE.tmp"
mv "$DESKTOP_DIR/$DESKTOP_FILE.tmp" "$DESKTOP_DIR/$DESKTOP_FILE"
chmod 644 "$DESKTOP_DIR/$DESKTOP_FILE"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q "$DESKTOP_DIR" >/dev/null 2>&1 || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache --force --ignore-theme-index "$DATA_HOME/icons/hicolor" >/dev/null 2>&1 || true
fi
if command -v xdg-desktop-menu >/dev/null 2>&1; then
    xdg-desktop-menu forceupdate --mode user >/dev/null 2>&1 || true
fi

if [ ! -x "$BIN_DIR/nflix-desktop" ] || [ ! -f "$DESKTOP_DIR/$DESKTOP_FILE" ] \
    || [ ! -f "$ICON_DIR_48/$ICON_NAME.png" ] || [ ! -f "$ICON_DIR_512/$ICON_NAME.png" ]; then
    echo "Installation did not create the launcher, menu entry, and icons correctly." >&2
    exit 1
fi

echo "Installed Nflix Desktop to $PREFIX"
echo "Launch it from the applications menu or with: $BIN_DIR/nflix-desktop"
