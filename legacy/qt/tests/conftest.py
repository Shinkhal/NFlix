"""Shared fixtures for the nflix-desktop test suite."""

from __future__ import annotations

import os
import sys

import pytest
from PySide6.QtCore import QCoreApplication


@pytest.fixture(scope="session", autouse=True)
def qapp():
    """Ensure a QCoreApplication exists for the entire test session.

    QUrl works without a full QApplication, so a lightweight
    QCoreApplication avoids the need for a display server and keeps
    tests runnable in headless CI environments.
    """
    os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    app = QCoreApplication.instance()
    if app is None:
        app = QCoreApplication(sys.argv[:1])
    yield app
