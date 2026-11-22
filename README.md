# Nflix Desktop

Nflix Desktop is an unofficial Linux desktop wrapper that opens Netflix in a dedicated PySide6 window. The app uses a custom N icon and lets Linux desktop decorations and Qt controls use the active system theme.

> **Unofficial project:** Nflix Desktop is not affiliated with, endorsed by, or sponsored by Netflix, Inc. Netflix and its marks belong to Netflix, Inc. A Netflix account and internet access are required.

## Run from source

Requirements: Linux, Python 3.10 or newer, and a graphical desktop session.

```sh
python3 -m venv .venv
.venv/bin/python -m pip install .
./run.sh
```

## Install and uninstall

From this checkout, install a per-user copy with:

```sh
./install.sh
```

This creates a private Python environment under `~/.local/lib/nflix-desktop` and installs the desktop entry and icons under `~/.local`. It may download PySide6 if it is not already cached. Remove the application files with `./uninstall.sh`; this keeps Netflix cookies and settings in `~/.local/share/nflix-desktop`.

The app uses Qt WebEngine, which is based on Chromium. The standard PySide6 package does not include a Widevine CDM, and H.264 availability depends on the Qt build. Sign-in may work while DRM playback fails. This app does not bypass DRM or provide Netflix content.

## Desktop behavior

- Netflix cookies and site data persist in the application data directory.
- Window geometry is restored on the next launch.
- Main-frame HTTP(S) links outside `netflix.com` open in the system browser.
- `Ctrl+Shift+P` toggles a compact always-on-top window.
- The window title bar and Qt controls use the Linux desktop's native decorations and platform theme.
- Offline downloads and MPRIS integration are not provided.

## Memory use

Qt WebEngine runs Chromium renderer and utility processes. Nflix Desktop removes Electron's Node.js layer, but the Netflix page and video decoding remain the main memory costs. Actual RAM use depends on the host, playback, and Qt build; no reduction is claimed without a measured comparison.

## Build and publish a Linux release

The project uses Qt for Python's `pyside6-deploy` tool to create a standalone Linux bundle. Build with Python 3.12 or 3.13, matching Python development headers, a C compiler, and `patchelf` available, on the target architecture (Nuitka 4.1.1 does not yet support the host's Python 3.15 build reliably):

```sh
python3.13 -m venv .venv-build
.venv-build/bin/python -m pip install .
BUILD_VENV=.venv-build scripts/build-release.sh
```

The release archive and SHA-256 checksum are written to `dist/`. Extract the archive and run `./install.sh` to install it under `~/.local`; `./uninstall.sh` removes it. Pushing a `v0.2.1` tag builds and publishes the Linux x86_64 archive through GitHub Actions. Other Linux distributions and architectures still need validation.

Before redistributing binaries, review [third-party notices](THIRD_PARTY_NOTICES.md) and Qt's licensing terms. The standalone build includes Qt WebEngine and Chromium components and can be large.

Store submissions still need screenshots from the final release. The AppStream homepage, issue tracker, and source links use the configured GitHub origin. Do not advertise Netflix playback until DRM playback has been tested on the target release build.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), and [SECURITY.md](SECURITY.md).

## License

The project code is licensed under the MIT License. PySide6 and Qt WebEngine have separate LGPL/GPL/commercial licensing terms; review the notices and Qt licensing requirements for any redistributed build.
