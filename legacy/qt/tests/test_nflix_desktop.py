"""Tests for the core URL-trust gate in nflix_desktop."""

from __future__ import annotations

import pytest
from PySide6.QtCore import QUrl

# Import the function under test
from nflix_desktop import is_trusted_netflix_url


def test_widevine_configuration_uses_bundled_path(monkeypatch, tmp_path):
    cdm = tmp_path / "WidevineCdm" / "_platform_specific" / "linux_x64"
    cdm.mkdir(parents=True)
    binary = cdm / "libwidevinecdm.so"
    binary.write_bytes(b"\x7fELF\x02\x01" + bytes(12) + (62).to_bytes(2, "little"))
    monkeypatch.setattr("nflix_desktop.platform.machine", lambda: "x86_64")
    monkeypatch.setenv("NFLIX_APP_ROOT", str(tmp_path))
    monkeypatch.delenv("QTWEBENGINE_CHROMIUM_FLAGS", raising=False)
    import nflix_desktop
    nflix_desktop.configure_widevine()
    assert str(binary) in __import__("os").environ["QTWEBENGINE_CHROMIUM_FLAGS"]


# ── Trusted URLs ─────────────────────────────────────────────────────

class TestTrustedUrls:
    """URLs that MUST be accepted by the trust check."""

    @pytest.mark.parametrize(
        "url_str",
        [
            "https://netflix.com",
            "https://netflix.com/",
            "https://www.netflix.com",
            "https://www.netflix.com/",
            "https://www.netflix.com/browse",
            "https://www.netflix.com/browse?page=1",
            "https://api.netflix.com/path",
            "https://cdn-0.nflximg.netflix.com/asset.js",
            "https://NETFLIX.COM",           # uppercase scheme host
            "https://WWW.NETFLIX.COM/browse",
        ],
    )
    def test_trusted(self, url_str: str) -> None:
        assert is_trusted_netflix_url(QUrl(url_str)) is True


# ── Untrusted URLs ───────────────────────────────────────────────────

class TestUntrustedUrls:
    """URLs that MUST be rejected by the trust check."""

    @pytest.mark.parametrize(
        "url_str",
        [
            # Wrong scheme
            "http://netflix.com",
            "http://www.netflix.com",
            "ftp://netflix.com",
            # Lookalike / subdomain-spoofing domains
            "https://evil-netflix.com",
            "https://netflix.com.evil.com",
            "https://notnetflix.com",
            "https://fakenotnetflix.com",
            # Completely unrelated
            "https://google.com",
            "https://example.com",
            # Tricky suffix attacks
            "https://xnetflix.com",
            "https://netflix.org",
        ],
    )
    def test_untrusted(self, url_str: str) -> None:
        assert is_trusted_netflix_url(QUrl(url_str)) is False


# ── Edge cases ───────────────────────────────────────────────────────

class TestEdgeCases:
    """Degenerate and unusual inputs."""

    def test_empty_url(self) -> None:
        assert is_trusted_netflix_url(QUrl()) is False

    def test_empty_string_url(self) -> None:
        assert is_trusted_netflix_url(QUrl("")) is False

    def test_path_only(self) -> None:
        assert is_trusted_netflix_url(QUrl("/browse")) is False

    def test_no_host(self) -> None:
        assert is_trusted_netflix_url(QUrl("https:///path")) is False

    def test_data_scheme(self) -> None:
        assert is_trusted_netflix_url(QUrl("data:text/html,<h1>Hi</h1>")) is False

    def test_javascript_scheme(self) -> None:
        assert is_trusted_netflix_url(QUrl("javascript:void(0)")) is False

    def test_file_scheme(self) -> None:
        assert is_trusted_netflix_url(QUrl("file:///etc/passwd")) is False

    def test_about_blank(self) -> None:
        assert is_trusted_netflix_url(QUrl("about:blank")) is False


@pytest.fixture
def cdm_environment(monkeypatch, tmp_path):
    import nflix_desktop as app
    monkeypatch.setattr(app.platform, "machine", lambda: "x86_64")
    monkeypatch.setattr(app.Path, "home", lambda: tmp_path)
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path / ".config"))
    monkeypatch.delenv("QTWEBENGINE_CHROMIUM_FLAGS", raising=False)
    monkeypatch.delenv("NFLIX_APP_ROOT", raising=False)
    monkeypatch.setattr(app.sys, "argv", ["nflix-desktop"])
    return app


def make_cdm(path, machine=62):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"\x7fELF\x02\x01" + bytes(12) + machine.to_bytes(2, "little"))
    return path


@pytest.mark.parametrize("relative", [
    ".config/google-chrome/WidevineCdm/4.10.1/_platform_specific/linux_x64/libwidevinecdm.so",
    ".config/chromium/WidevineCdm/4.10.1/_platform_specific/linux_x64/libwidevinecdm.so",
    ".mozilla/firefox/profile.default/gmp-widevinecdm/4.10.1/libwidevinecdm.so",
])
def test_browser_discovery(cdm_environment, tmp_path, relative):
    binary = make_cdm(tmp_path / relative)
    assert binary in list(cdm_environment.widevine_candidates())


def test_selects_compatible_cdm_and_preserves_flags(cdm_environment, monkeypatch, tmp_path):
    app = cdm_environment
    wrong = make_cdm(tmp_path / "arm64.so", 183)
    good = make_cdm(tmp_path / "path with spaces" / "libwidevinecdm.so")
    monkeypatch.setattr(app, "widevine_candidates", lambda: iter([wrong, good]))
    monkeypatch.setenv("QTWEBENGINE_CHROMIUM_FLAGS", "--disable-gpu")
    app.configure_widevine()
    flags = app.os.environ["QTWEBENGINE_CHROMIUM_FLAGS"]
    assert flags == f'--disable-gpu --widevine-path="{good}"'
    app.configure_widevine()
    assert app.os.environ["QTWEBENGINE_CHROMIUM_FLAGS"] == flags


@pytest.mark.parametrize("flags", ['--widevine-path="/custom/cdm.so"', "--widevine-path /custom/cdm.so"])
def test_explicit_override_wins(cdm_environment, monkeypatch, flags):
    monkeypatch.setenv("QTWEBENGINE_CHROMIUM_FLAGS", flags)
    cdm_environment.configure_widevine()
    assert cdm_environment.os.environ["QTWEBENGINE_CHROMIUM_FLAGS"] == flags


def test_no_cdm_leaves_flags_unchanged(cdm_environment, monkeypatch):
    monkeypatch.setattr(cdm_environment, "widevine_candidates", lambda: iter([]))
    cdm_environment.configure_widevine()
    assert "QTWEBENGINE_CHROMIUM_FLAGS" not in cdm_environment.os.environ


def test_newest_browser_component_first(cdm_environment, tmp_path):
    root = tmp_path / ".config/chromium/WidevineCdm"
    older = make_cdm(root / "4.9.9/_platform_specific/linux_x64/libwidevinecdm.so")
    newer = make_cdm(root / "4.10.1/_platform_specific/linux_x64/libwidevinecdm.so")
    candidates = list(cdm_environment.widevine_candidates())
    assert candidates.index(newer) < candidates.index(older)
