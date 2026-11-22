#!/bin/sh
set -eu

PREFIX=${1:-"$HOME/.local"}
mkdir -p "$PREFIX"
PREFIX=$(CDPATH= cd -- "$PREFIX" && pwd -P)
if [ "$PREFIX" = "/" ]; then
    echo "Refusing to uninstall from the filesystem root." >&2
    exit 1
fi

rm -rf "$PREFIX/lib/nflix-desktop"
rm -f "$PREFIX/bin/nflix-desktop"
rm -f "$PREFIX/share/applications/io.github.nflixdesktop.desktop"
rm -f "$PREFIX/share/applications/io.github.nflixdesktop.desktop.desktop"
rm -f "$PREFIX/share/metainfo/io.github.nflixdesktop.metainfo.xml"
rm -f "$PREFIX/share/metainfo/io.github.nflixdesktop.desktop.metainfo.xml"
rm -f "$PREFIX/share/icons/hicolor/48x48/apps/io.github.nflixdesktop.png"
rm -f "$PREFIX/share/icons/hicolor/512x512/apps/io.github.nflixdesktop.png"
rm -f "$PREFIX/share/icons/hicolor/48x48/apps/io.github.nflixdesktop.desktop.png"
rm -f "$PREFIX/share/icons/hicolor/512x512/apps/io.github.nflixdesktop.desktop.png"
rm -f "$PREFIX/share/licenses/nflix-desktop/LICENSE"
rm -f "$PREFIX/share/licenses/nflix-desktop/THIRD_PARTY_NOTICES.md"
rmdir "$PREFIX/share/licenses/nflix-desktop" 2>/dev/null || true

if command -v update-desktop-database >/dev/null 2>&1 && [ -d "$PREFIX/share/applications" ]; then
    update-desktop-database "$PREFIX/share/applications" || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1 && [ -d "$PREFIX/share/icons/hicolor" ]; then
    gtk-update-icon-cache --force --ignore-theme-index "$PREFIX/share/icons/hicolor" >/dev/null 2>&1 || true
fi

echo "Removed Nflix Desktop from $PREFIX. User data in share/nflix-desktop was preserved."
