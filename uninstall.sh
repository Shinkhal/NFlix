#!/bin/sh
set -eu

PREFIX=${1:-"$HOME/.local"}
mkdir -p "$PREFIX"
PREFIX=$(CDPATH= cd -- "$PREFIX" && pwd -P)
if [ "$PREFIX" = "/" ]; then
    echo "Refusing to uninstall from the filesystem root." >&2
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

rm -rf "$PREFIX/lib/nflix-desktop"
rm -f "$PREFIX/bin/nflix-desktop"
rm -f "$DATA_HOME/applications/io.github.nflixdesktop.desktop"
rm -f "$DATA_HOME/applications/io.github.nflixdesktop.desktop.desktop"
rm -f "$DATA_HOME/metainfo/io.github.nflixdesktop.metainfo.xml"
rm -f "$DATA_HOME/metainfo/io.github.nflixdesktop.desktop.metainfo.xml"
rm -f "$DATA_HOME/icons/hicolor/48x48/apps/io.github.nflixdesktop.png"
rm -f "$DATA_HOME/icons/hicolor/512x512/apps/io.github.nflixdesktop.png"
rm -f "$DATA_HOME/icons/hicolor/48x48/apps/nflix-desktop.png"
rm -f "$DATA_HOME/icons/hicolor/512x512/apps/nflix-desktop.png"
rm -f "$DATA_HOME/icons/hicolor/48x48/apps/io.github.nflixdesktop.desktop.png"
rm -f "$DATA_HOME/icons/hicolor/512x512/apps/io.github.nflixdesktop.desktop.png"
rm -f "$DATA_HOME/licenses/nflix-desktop/LICENSE"
rm -f "$DATA_HOME/licenses/nflix-desktop/THIRD_PARTY_NOTICES.md"
rmdir "$DATA_HOME/licenses/nflix-desktop" 2>/dev/null || true

if command -v update-desktop-database >/dev/null 2>&1 && [ -d "$DATA_HOME/applications" ]; then
    update-desktop-database -q "$DATA_HOME/applications" >/dev/null 2>&1 || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1 && [ -d "$DATA_HOME/icons/hicolor" ]; then
    gtk-update-icon-cache --force --ignore-theme-index "$DATA_HOME/icons/hicolor" >/dev/null 2>&1 || true
fi
if command -v xdg-desktop-menu >/dev/null 2>&1; then
    xdg-desktop-menu forceupdate --mode user >/dev/null 2>&1 || true
fi

echo "Removed Nflix Desktop from $PREFIX. User data in share/nflix-desktop was preserved."
