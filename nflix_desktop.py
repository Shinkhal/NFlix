"""A small PySide6 shell for Netflix."""

from __future__ import annotations

import os
import sys

from PySide6.QtCore import QSettings, QStandardPaths, QUrl, Qt
from PySide6.QtGui import QDesktopServices, QIcon, QKeySequence, QShortcut
from PySide6.QtWidgets import QApplication, QMainWindow
from PySide6.QtWebEngineCore import QWebEnginePage, QWebEngineProfile, QWebEngineSettings
from PySide6.QtWebEngineWidgets import QWebEngineView
import app_resources


APP_ID = "io.github.nflixdesktop"
APP_NAME = "Nflix Desktop"
HOME_URL = QUrl("https://www.netflix.com/")
APP_ICON = ":/icons/icon-512.png"


def is_trusted_netflix_url(url: QUrl) -> bool:
    return (url.scheme().lower() == "https"
            and (url.host().lower() == "netflix.com"
                 or url.host().lower().endswith(".netflix.com")))


class NetflixPage(QWebEnginePage):
    def acceptNavigationRequest(self, url: QUrl, nav_type, is_main_frame: bool) -> bool:
        if is_trusted_netflix_url(url):
            return True
        if is_main_frame and url.scheme() in ("http", "https"):
            QDesktopServices.openUrl(url)
        return False

    def createWindow(self, _window_type):
        # Netflix opens account and playback flows in new tabs. Reuse this window;
        # acceptNavigationRequest still applies the same domain policy.
        return self


class NetflixWindow(QMainWindow):
    def __init__(self, profile: QWebEngineProfile):
        super().__init__()
        self.setWindowTitle(APP_NAME)
        self.setWindowIcon(QIcon(APP_ICON))
        self.setMinimumSize(800, 600)
        self.view = QWebEngineView(self)
        self.page = NetflixPage(profile, self.view)
        self.view.setPage(self.page)
        self.setCentralWidget(self.view)

        settings = self.view.settings()
        settings.setAttribute(QWebEngineSettings.WebAttribute.FullScreenSupportEnabled, True)
        settings.setAttribute(QWebEngineSettings.WebAttribute.PlaybackRequiresUserGesture, False)
        self.page.fullScreenRequested.connect(self._handle_full_screen)

        self.settings = QSettings(APP_ID, "nflix-desktop")
        geometry = self.settings.value("window/geometry")
        if geometry and self.restoreGeometry(geometry):
            pass
        else:
            self.resize(1280, 800)

        self.mini_shortcut = QShortcut(QKeySequence("Ctrl+Shift+P"), self)
        self.mini_shortcut.activated.connect(self.toggle_mini_window)
        self.mini_window = False
        self.view.setUrl(HOME_URL)

    def _handle_full_screen(self, request) -> None:
        request.accept()
        self.showFullScreen() if request.toggleOn() else self.showNormal()

    def toggle_mini_window(self) -> None:
        self.mini_window = not self.mini_window
        self.setWindowFlag(Qt.WindowType.WindowStaysOnTopHint, self.mini_window)
        self.resize(640, 360) if self.mini_window else self.resize(1280, 800)
        self.show()

    def closeEvent(self, event) -> None:
        self.settings.setValue("window/geometry", self.saveGeometry())
        super().closeEvent(event)


def main() -> int:
    # Use Qt's GTK platform theme and Adwaita Wayland decorations so the
    # application shell matches GNOME's theme and decoration layout.
    if sys.platform.startswith("linux"):
        os.environ.setdefault("QT_QPA_PLATFORMTHEME", "gtk3")
        if os.environ.get("XDG_SESSION_TYPE") == "wayland":
            os.environ.setdefault("QT_WAYLAND_DECORATION", "adwaita")

    app = QApplication(sys.argv)
    app.setApplicationName("nflix-desktop")
    app.setApplicationDisplayName(APP_NAME)
    app.setOrganizationName("nflix-desktop")
    app.setDesktopFileName(APP_ID)
    app.setWindowIcon(QIcon(APP_ICON))

    profile = QWebEngineProfile("nflix-desktop", app)
    profile.setPersistentStoragePath(QStandardPaths.writableLocation(
        QStandardPaths.StandardLocation.AppDataLocation) + "/webengine")
    profile.setCachePath(QStandardPaths.writableLocation(
        QStandardPaths.StandardLocation.CacheLocation) + "/webengine")
    profile.setPersistentCookiesPolicy(
        QWebEngineProfile.PersistentCookiesPolicy.AllowPersistentCookies)
    profile.setHttpCacheType(QWebEngineProfile.HttpCacheType.DiskHttpCache)
    profile.setHttpCacheMaximumSize(256 * 1024 * 1024)
    profile.setPersistentPermissionsPolicy(
        QWebEngineProfile.PersistentPermissionsPolicy.StoreInMemory)

    window = NetflixWindow(profile)
    window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
