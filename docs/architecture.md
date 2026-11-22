# Architecture

`nflix_desktop.py` creates a PySide6 `QMainWindow` containing a Qt WebEngine view. The window uses the system's normal decorations and platform theme. Its N icon is embedded from `assets/resources.qrc` for source and standalone launches. A named WebEngine profile stores Netflix cookies, cache, and site data below Qt's per-user application data paths. Qt settings retain the last window geometry.

`NetflixPage.acceptNavigationRequest` permits HTTPS pages on `netflix.com` and its subdomains. Main-frame web navigations to other hosts are sent to the system browser; other protocols and embedded cross-site frames are denied. New page requests reuse the main page and pass through that policy.

Qt WebEngine is Chromium-based. This project does not bundle Widevine, and H.264 availability depends on the Qt build. The wrapper cannot guarantee Netflix DRM playback. The standard PySide6 package is considerably larger on disk than a thin GUI binding because it includes Qt WebEngine and its Chromium components; RAM usage must be measured on the target system.

The source launch path is `run.sh`. `pyproject.toml` is the Python package and version source; `pysidedeploy.spec` configures Qt's Nuitka-based standalone deploy tool. `scripts/build-release.sh` stages a per-user Linux install archive with its desktop entry, icon, AppStream metadata, and checksum. The GitHub Actions tag workflow publishes Linux x86_64 artifacts. Other architectures and distributions require separate builds and validation.
