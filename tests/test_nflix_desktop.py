"""Tests for the core URL-trust gate in nflix_desktop."""

from __future__ import annotations

import pytest
from PySide6.QtCore import QUrl

# Import the function under test
from nflix_desktop import is_trusted_netflix_url


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
