#!/bin/sh
set -eu

PROJECT_ROOT=${PROJECT_ROOT:-"$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"}
STAGE=${1:?usage: build-packages.sh STAGE VERSION ARCH OUTPUT_DIR}
VERSION=${2:?usage: build-packages.sh STAGE VERSION ARCH OUTPUT_DIR}
ARCH=${3:?usage: build-packages.sh STAGE VERSION ARCH OUTPUT_DIR}
OUTPUT_DIR=${4:?usage: build-packages.sh STAGE VERSION ARCH OUTPUT_DIR}

case "$ARCH" in
    x86_64) DEB_ARCH=amd64; RPM_ARCH=x86_64 ;;
    aarch64|arm64) DEB_ARCH=arm64; RPM_ARCH=aarch64 ;;
    *) echo "Unsupported package architecture: $ARCH" >&2; exit 1 ;;
esac

mkdir -p "$OUTPUT_DIR"
PACKAGE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/nflix-packages.XXXXXX")
RPM_ROOT="$PACKAGE_ROOT/rpm"
RPM_BUILDROOT="$RPM_ROOT/BUILDROOT/nflix-desktop-$VERSION-1.$RPM_ARCH"
trap 'rm -rf "$PACKAGE_ROOT"' EXIT HUP INT TERM

install -d "$PACKAGE_ROOT/deb/usr/bin" \
    "$PACKAGE_ROOT/deb/usr/lib/nflix-desktop" \
    "$PACKAGE_ROOT/deb/usr/share/applications" \
    "$PACKAGE_ROOT/deb/usr/share/icons/hicolor/48x48/apps" \
    "$PACKAGE_ROOT/deb/usr/share/icons/hicolor/512x512/apps" \
    "$PACKAGE_ROOT/deb/usr/share/metainfo" \
    "$PACKAGE_ROOT/deb/usr/share/licenses/nflix-desktop"
cp -a "$STAGE/bin/nflix-desktop" "$PACKAGE_ROOT/deb/usr/bin/"
cp -a "$STAGE/lib/nflix-desktop/." "$PACKAGE_ROOT/deb/usr/lib/nflix-desktop/"
install -m 644 "$STAGE/io.github.nflixdesktop.desktop" "$PACKAGE_ROOT/deb/usr/share/applications/"
install -m 644 "$STAGE/io.github.nflixdesktop.metainfo.xml" "$PACKAGE_ROOT/deb/usr/share/metainfo/"
install -m 644 "$STAGE/assets/icon-48.png" "$PACKAGE_ROOT/deb/usr/share/icons/hicolor/48x48/apps/nflix-desktop.png"
install -m 644 "$STAGE/assets/icon-512.png" "$PACKAGE_ROOT/deb/usr/share/icons/hicolor/512x512/apps/nflix-desktop.png"
install -m 644 "$STAGE/LICENSE" "$PACKAGE_ROOT/deb/usr/share/licenses/nflix-desktop/"
install -m 644 "$STAGE/THIRD_PARTY_NOTICES.md" "$PACKAGE_ROOT/deb/usr/share/licenses/nflix-desktop/"

install -d "$PACKAGE_ROOT/deb/DEBIAN"
cat > "$PACKAGE_ROOT/deb/DEBIAN/control" <<EOF
Package: nflix-desktop
Version: $VERSION
Section: video
Priority: optional
Architecture: $DEB_ARCH
Maintainer: nflix-desktop contributors
Description: Unofficial Linux desktop wrapper for Netflix
 Nflix Desktop opens Netflix in a dedicated PySide6 and Qt WebEngine window.
EOF
dpkg-deb --build --root-owner-group "$PACKAGE_ROOT/deb" "$OUTPUT_DIR/nflix-desktop-$VERSION-linux-$ARCH.deb" >/dev/null

install -d "$RPM_ROOT/BUILD" "$RPM_BUILDROOT/usr/bin" "$RPM_ROOT/RPMS/$RPM_ARCH" "$RPM_ROOT/SOURCES" "$RPM_ROOT/SPECS" "$RPM_ROOT/SRPMS"
install -d "$RPM_BUILDROOT/usr/lib/nflix-desktop" \
    "$RPM_BUILDROOT/usr/share/applications" \
    "$RPM_BUILDROOT/usr/share/icons/hicolor/48x48/apps" \
    "$RPM_BUILDROOT/usr/share/icons/hicolor/512x512/apps" \
    "$RPM_BUILDROOT/usr/share/metainfo" \
    "$RPM_BUILDROOT/usr/share/licenses/nflix-desktop"
cp -a "$STAGE/bin/nflix-desktop" "$RPM_BUILDROOT/usr/bin/"
cp -a "$STAGE/lib/nflix-desktop/." "$RPM_BUILDROOT/usr/lib/nflix-desktop/"
install -m 644 "$STAGE/io.github.nflixdesktop.desktop" "$RPM_BUILDROOT/usr/share/applications/"
install -m 644 "$STAGE/io.github.nflixdesktop.metainfo.xml" "$RPM_BUILDROOT/usr/share/metainfo/"
install -m 644 "$STAGE/assets/icon-48.png" "$RPM_BUILDROOT/usr/share/icons/hicolor/48x48/apps/nflix-desktop.png"
install -m 644 "$STAGE/assets/icon-512.png" "$RPM_BUILDROOT/usr/share/icons/hicolor/512x512/apps/nflix-desktop.png"
install -m 644 "$STAGE/LICENSE" "$RPM_BUILDROOT/usr/share/licenses/nflix-desktop/"
install -m 644 "$STAGE/THIRD_PARTY_NOTICES.md" "$RPM_BUILDROOT/usr/share/licenses/nflix-desktop/"
cat > "$RPM_ROOT/SPECS/nflix-desktop.spec" <<EOF
Name: nflix-desktop
Version: $VERSION
Release: 1
Summary: Unofficial Linux desktop wrapper for Netflix
License: MIT
BuildArch: $RPM_ARCH

%description
Nflix Desktop opens Netflix in a dedicated PySide6 and Qt WebEngine window.

%files
/usr/bin/nflix-desktop
/usr/lib/nflix-desktop
/usr/share/applications/io.github.nflixdesktop.desktop
/usr/share/icons/hicolor/48x48/apps/nflix-desktop.png
/usr/share/icons/hicolor/512x512/apps/nflix-desktop.png
/usr/share/metainfo/io.github.nflixdesktop.metainfo.xml
/usr/share/licenses/nflix-desktop
EOF
rpmbuild --define "_topdir $RPM_ROOT" --define "_build_id_links none" --target "$RPM_ARCH" -bb "$RPM_ROOT/SPECS/nflix-desktop.spec" >/dev/null
cp "$RPM_ROOT/RPMS/$RPM_ARCH/nflix-desktop-$VERSION-1.$RPM_ARCH.rpm" "$OUTPUT_DIR/nflix-desktop-$VERSION-linux-$ARCH.rpm"

sha256sum \
    "$OUTPUT_DIR/nflix-desktop-$VERSION-linux-$ARCH.deb" \
    "$OUTPUT_DIR/nflix-desktop-$VERSION-linux-$ARCH.rpm" \
    > "$OUTPUT_DIR/nflix-desktop-$VERSION-linux-$ARCH-packages.sha256"
