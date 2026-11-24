# Architecture

The TypeScript main process creates one sandboxed Electron BrowserWindow.
Netflix's own website supplies the player and authentication UI. No Node.js
integration, preload bridge, certificate bypass or DRM bypass is exposed to it.

Castlabs Electron is pinned in package.json and package-lock.json. Startup waits
for its Widevine component updater, restarts once per observed component version
on Linux, and checks H.264/AAC plus Widevine access before loading Netflix.
Component setup has a two-minute timeout; the capability check has a 20-second
timeout. Failure produces an actionable native error dialog and a sanitized
report instead of silently loading a login-only window.

The capability probe uses a local file in a separate nonpersistent session.
The Netflix session persists under Electron's userData directory. Only Netflix
origins receive mediaKeySystem permission; unrelated permission requests and
downloads are denied. HTTPS Netflix navigation stays in the window; external
HTTP(S) navigation requires confirmation. Popups cannot create unmanaged windows.

Electron Builder packages the installed Castlabs distribution via electronDist.
Builds must never substitute stock Electron. AppImage, tar.gz, DEB and RPM are
the initial formats. Flatpak needs a separately tested sandbox/CDM integration
before a manifest is provided. The old Qt/Snap/Flatpak recipes live in legacy/qt
and are not evidence of support for the rewritten application.

Capability success does not prove Netflix license acceptance, decoding, audio,
or resolution. A real protected-title test remains the release gate.

## Current validation

On 2026-11-24, the user confirmed Netflix video and audio playback in the
installed 0.3.0 Fedora 45 x86_64 application. The source and packaged runtime
passed capability checks; the AppImage passed the same check. The DEB/RPM
artifacts were built and their metadata inspected, not installed on target
distributions. Cross-distribution playback remains unverified.
