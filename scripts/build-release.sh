#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_VENV=${BUILD_VENV:-"$PROJECT_ROOT/.venv"}
PYTHON="$BUILD_VENV/bin/python"

if [ ! -x "$PYTHON" ]; then
    echo "Create .venv and install the project before building." >&2
    exit 1
fi

cd "$PROJECT_ROOT"
PATH="$BUILD_VENV/bin:$PATH"
export PATH
VERSION=$($PYTHON -c 'import tomllib; print(tomllib.load(open("pyproject.toml", "rb"))["project"]["version"])')
ARCH=$(uname -m)
DEPLOY_DIR="$PROJECT_ROOT/dist/nflix-desktop.dist"
PYTHON_INCLUDE=$($PYTHON -c 'import sysconfig; print(sysconfig.get_path("include"))')

if [ ! -f "$PYTHON_INCLUDE/Python.h" ]; then
    echo "Python development headers are required (missing $PYTHON_INCLUDE/Python.h). Install the matching python-devel/python-dev package and retry." >&2
    exit 1
fi

if ! command -v cc >/dev/null 2>&1; then
    echo "A C compiler is required to build the standalone application." >&2
    exit 1
fi

STAGE_ROOT=$(mktemp -d "$PROJECT_ROOT/dist/.nflix-release.XXXXXX")
STAGE="$STAGE_ROOT/nflix-desktop-$VERSION-linux-$ARCH"
trap 'rm -rf "$STAGE_ROOT"' EXIT HUP INT TERM

"$BUILD_VENV/bin/pyside6-deploy" --force --config-file "$PROJECT_ROOT/pysidedeploy.spec" --mode standalone

if [ ! -x "$DEPLOY_DIR/nflix_desktop.bin" ]; then
    echo "Expected deployed executable was not found in $DEPLOY_DIR." >&2
    exit 1
fi

install -d "$STAGE/bin" "$STAGE/lib/nflix-desktop" "$STAGE/assets"
cp -a "$DEPLOY_DIR/." "$STAGE/lib/nflix-desktop/"
install -m 755 "$PROJECT_ROOT/bin/nflix-desktop" "$STAGE/bin/nflix-desktop"
install -m 644 "$PROJECT_ROOT/assets/icon-512.png" "$STAGE/assets/icon-512.png"
install -m 644 "$PROJECT_ROOT/assets/icon-48.png" "$STAGE/assets/icon-48.png"
install -m 644 "$PROJECT_ROOT/io.github.nflixdesktop.desktop" "$STAGE/"
install -m 644 "$PROJECT_ROOT/io.github.nflixdesktop.metainfo.xml" "$STAGE/"
install -m 755 "$PROJECT_ROOT/install.sh" "$STAGE/install.sh"
install -m 755 "$PROJECT_ROOT/uninstall.sh" "$STAGE/uninstall.sh"
install -m 644 "$PROJECT_ROOT/LICENSE" "$STAGE/LICENSE"
install -m 644 "$PROJECT_ROOT/THIRD_PARTY_NOTICES.md" "$STAGE/THIRD_PARTY_NOTICES.md"
install -m 644 "$PROJECT_ROOT/README.md" "$STAGE/README.md"

tar -C "$STAGE_ROOT" -czf "$PROJECT_ROOT/dist/nflix-desktop-$VERSION-linux-$ARCH.tar.gz" "$(basename "$STAGE")"
sha256sum "$PROJECT_ROOT/dist/nflix-desktop-$VERSION-linux-$ARCH.tar.gz" > "$PROJECT_ROOT/dist/nflix-desktop-$VERSION-linux-$ARCH.tar.gz.sha256"
echo "Release bundle created in dist/"
